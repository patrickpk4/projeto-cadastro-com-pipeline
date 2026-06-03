using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Mongo2Go;
using MongoDB.Bson;
using MongoDB.Driver;
using PedeLogo.Catalogo.Api;
using PedeLogo.Catalogo.Api.Model;
using Xunit;

namespace PedeLogo.Catalogo.IntegrationTests
{
    public class MongoFixture : IDisposable
    {
        public MongoDbRunner Runner { get; private set; }
        public IMongoDatabase Database { get; private set; }

        public MongoFixture()
        {
            // Configurar Mongo2Go para funcionar no GitHub Actions
            var runnerOptions = new MongoDbRunnerOptions
            {
                UseSingleNodeReplicaSet = true,
                MongoDbVersion = MongoDbVersion.V6_0,
                LogOutput = Console.Out
            };
            
            Runner = MongoDbRunner.Start(runnerOptions);
            var client = new MongoClient(Runner.ConnectionString);
            Database = client.GetDatabase("catalogo_test");
            
            // Aguardar o MongoDB ficar pronto
            var maxAttempts = 10;
            for (int i = 0; i < maxAttempts; i++)
            {
                try
                {
                    Database.RunCommandAsync<BsonDocument>(new BsonDocument("ping", 1))
                        .Wait(TimeSpan.FromSeconds(5));
                    break;
                }
                catch
                {
                    if (i == maxAttempts - 1) throw;
                    Task.Delay(1000).Wait();
                }
            }
        }

        public void Dispose()
        {
            Runner?.Dispose();
        }
    }

    public class CustomWebApplicationFactory : WebApplicationFactory<Startup>
    {
        public IMongoDatabase MongoDatabase { get; set; }

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureServices(services =>
            {
                // Remover serviços existentes de MongoDB
                for (int i = services.Count - 1; i >= 0; i--)
                {
                    if (services[i].ServiceType == typeof(IMongoDatabase) ||
                        services[i].ServiceType == typeof(IMongoClient))
                    {
                        services.RemoveAt(i);
                    }
                }

                // Adicionar nosso MongoDB de teste
                if (MongoDatabase != null)
                {
                    services.AddSingleton<IMongoDatabase>(MongoDatabase);
                }
            });
        }
    }

    public class ProdutoIntegrationTests : IClassFixture<MongoFixture>, IClassFixture<CustomWebApplicationFactory>, IDisposable
    {
        private readonly HttpClient _client;
        private readonly IMongoCollection<Produto> _collection;
        private bool _disposed;

        public ProdutoIntegrationTests(MongoFixture mongo, CustomWebApplicationFactory factory)
        {
            _collection = mongo.Database.GetCollection<Produto>("Produto");
            factory.MongoDatabase = mongo.Database;
            _client = factory.CreateClient();
            _client.DefaultRequestHeaders.Clear();
        }

        private async Task LimparColecao()
        {
            await _collection.DeleteManyAsync(new BsonDocument());
        }

        private StringContent Json(object obj)
        {
            return new StringContent(
                JsonSerializer.Serialize(obj),
                Encoding.UTF8,
                "application/json");
        }

        [Fact]
        public async Task GetAll_QuandoExistemProdutos_DeveRetornar200ComLista()
        {
            await LimparColecao();
            await _collection.InsertManyAsync(new[]
            {
                new Produto { Id = ObjectId.GenerateNewId().ToString(), Nome = "Pizza", Preco = 39.90, Categoria = "Comida" },
                new Produto { Id = ObjectId.GenerateNewId().ToString(), Nome = "Suco", Preco = 8.00, Categoria = "Bebida" }
            });

            var response = await _client.GetAsync("/produto");

            response.StatusCode.Should().Be(HttpStatusCode.OK);
            var json = await response.Content.ReadAsStringAsync();
            var produtos = JsonSerializer.Deserialize<List<Produto>>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            produtos.Should().HaveCountGreaterOrEqualTo(2);
        }

        [Fact]
        public async Task GetAll_QuandoColecaoVazia_DeveRetornar200ComListaVazia()
        {
            await LimparColecao();

            var response = await _client.GetAsync("/produto");

            response.StatusCode.Should().Be(HttpStatusCode.OK);
            var json = await response.Content.ReadAsStringAsync();
            json.Should().Be("[]");
        }

        [Fact]
        public async Task GetById_ComIdExistente_DeveRetornar200()
        {
            await LimparColecao();
            var id = ObjectId.GenerateNewId().ToString();
            await _collection.InsertOneAsync(new Produto { Id = id, Nome = "Hamburguer", Preco = 28.00, Categoria = "Comida" });

            var response = await _client.GetAsync($"/produto/{id}");

            response.StatusCode.Should().Be(HttpStatusCode.OK);
        }

        [Fact]
        public async Task GetById_ComIdInvalido_DeveRetornar400()
        {
            var response = await _client.GetAsync("/produto/id-invalido-aqui");
            response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        }

        [Fact]
        public async Task Post_ComProdutoValido_DeveRetornar200EInserirNoBanco()
        {
            await LimparColecao();
            var produto = new { Nome = "Frango Grelhado", Preco = 32.00, Categoria = "Pratos" };

            var response = await _client.PostAsync("/produto", Json(produto));

            response.StatusCode.Should().Be(HttpStatusCode.OK);
            var count = await _collection.CountDocumentsAsync(new BsonDocument());
            count.Should().Be(1);
        }

        [Fact]
        public async Task Delete_ComIdExistente_DeveRemoverDoBanco()
        {
            await LimparColecao();
            var id = ObjectId.GenerateNewId().ToString();
            await _collection.InsertOneAsync(new Produto { Id = id, Nome = "Produto Temporário", Preco = 1.00 });

            var response = await _client.DeleteAsync($"/produto?id={id}");

            response.StatusCode.Should().Be(HttpStatusCode.OK);
            var count = await _collection.CountDocumentsAsync(new BsonDocument());
            count.Should().Be(0);
        }

        [Fact]
        public async Task UnHealth_QuandoChamado_DeveRetornar200EBloquearRequests()
        {
            var unhealth = await _client.PutAsync("/config/unhealth", null);
            unhealth.StatusCode.Should().Be(HttpStatusCode.OK);

            var response = await _client.GetAsync("/produto");
            response.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        }

        [Fact]
        public async Task UnreadFor_QuandoChamado_DeveRetornar200()
        {
            var response = await _client.PutAsync("/config/unreadfor/5", null);
            response.StatusCode.Should().Be(HttpStatusCode.OK);
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                _client?.Dispose();
                _disposed = true;
            }
        }
    }
}