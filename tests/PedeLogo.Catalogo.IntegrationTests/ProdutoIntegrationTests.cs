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
using Microsoft.Extensions.DependencyInjection.Extensions;
using Mongo2Go;
using MongoDB.Bson;
using MongoDB.Driver;
using PedeLogo.Catalogo.Api;
using PedeLogo.Catalogo.Api.Model;
using Xunit;

namespace PedeLogo.Catalogo.IntegrationTests
{
    /// <summary>
    /// Fixture que sobe um MongoDB em memória (Mongo2Go) compartilhado entre os testes.
    /// </summary>
    public class MongoFixture : IDisposable
    {
        public MongoDbRunner? Runner { get; private set; }
        public IMongoDatabase? Database { get; private set; }

        public MongoFixture()
        {
            var maxRetries = 3;
            Exception? lastException = null;

            for (int i = 0; i < maxRetries; i++)
            {
                try
                {
                    Runner = MongoDbRunner.Start();
                    var client = new MongoClient(Runner.ConnectionString);
                    Database = client.GetDatabase("catalogo_test");
                    
                    var pingTask = Database.RunCommandAsync<BsonDocument>(new BsonDocument("ping", 1));
                    pingTask.Wait(TimeSpan.FromSeconds(10));
                    
                    Console.WriteLine($"MongoDB conectado: {Runner.ConnectionString}");
                    lastException = null;
                    break;
                }
                catch (Exception ex) when (i < maxRetries - 1)
                {
                    lastException = ex;
                    Console.WriteLine($"Tentativa {i + 1} falhou: {ex.Message}");
                    Runner?.Dispose();
                    Task.Delay(2000).Wait();
                }
            }

            if (lastException != null)
                throw new InvalidOperationException("Falha ao iniciar MongoDB", lastException);
        }

        public void Dispose() => Runner?.Dispose();
    }

    /// <summary>
    /// Custom WebApplicationFactory
    /// </summary>
    public class CustomWebApplicationFactory : WebApplicationFactory<Startup>
    {
        public IMongoDatabase? MongoDatabase { get; set; }

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureServices(services =>
            {
                // Remover handlers problemáticos
                var cookieHandler = services.FirstOrDefault(d => d.ServiceType == typeof(Microsoft.AspNetCore.Mvc.Testing.Handlers.CookieContainerHandler));
                if (cookieHandler != null)
                {
                    services.Remove(cookieHandler);
                }

                // Substituir MongoDB se disponível
                if (MongoDatabase != null)
                {
                    // Remover todas as referências ao IMongoDatabase existentes
                    var descriptorsToRemove = new List<ServiceDescriptor>();
                    foreach (var descriptor in services)
                    {
                        if (descriptor.ServiceType == typeof(IMongoDatabase) ||
                            descriptor.ServiceType == typeof(IMongoClient))
                        {
                            descriptorsToRemove.Add(descriptor);
                        }
                    }
                    
                    foreach (var descriptor in descriptorsToRemove)
                    {
                        services.Remove(descriptor);
                    }
                    
                    // Adicionar nosso MongoDB de teste
                    services.AddSingleton<IMongoDatabase>(sp => MongoDatabase);
                }
            });
        }
    }

    /// <summary>
    /// Testes de integração
    /// </summary>
    public class ProdutoIntegrationTests : IClassFixture<MongoFixture>, IClassFixture<CustomWebApplicationFactory>, IDisposable
    {
        private readonly HttpClient _client;
        private readonly IMongoCollection<Produto> _collection;
        private bool _disposed;

        public ProdutoIntegrationTests(MongoFixture mongo, CustomWebApplicationFactory factory)
        {
            if (mongo.Database == null)
                throw new InvalidOperationException("MongoDB não inicializado");
                
            _collection = mongo.Database.GetCollection<Produto>("Produto");
            
            factory.MongoDatabase = mongo.Database;
            _client = factory.CreateClient();
            _client.DefaultRequestHeaders.Clear();
        }

        private async Task LimparColecao()
        {
            try
            {
                await _collection.DeleteManyAsync(new BsonDocument());
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro ao limpar coleção: {ex.Message}");
            }
        }

        private StringContent Json(object obj) =>
            new StringContent(
                JsonSerializer.Serialize(obj),
                Encoding.UTF8,
                "application/json");

        [Fact]
        [Trait("Category", "Integration")]
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
        [Trait("Category", "Integration")]
        public async Task GetAll_QuandoColecaoVazia_DeveRetornar200ComListaVazia()
        {
            await LimparColecao();

            var response = await _client.GetAsync("/produto");

            response.StatusCode.Should().Be(HttpStatusCode.OK);
            var json = await response.Content.ReadAsStringAsync();
            json.Should().Be("[]");
        }

        [Fact]
        [Trait("Category", "Integration")]
        public async Task GetById_ComIdExistente_DeveRetornar200()
        {
            await LimparColecao();
            var id = ObjectId.GenerateNewId().ToString();
            await _collection.InsertOneAsync(new Produto { Id = id, Nome = "Hamburguer", Preco = 28.00, Categoria = "Comida" });

            var response = await _client.GetAsync($"/produto/{id}");

            response.StatusCode.Should().Be(HttpStatusCode.OK);
        }

        [Fact]
        [Trait("Category", "Integration")]
        public async Task GetById_ComIdInvalido_DeveRetornar400()
        {
            var response = await _client.GetAsync("/produto/id-invalido-aqui");
            response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        }

        [Fact]
        [Trait("Category", "Integration")]
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
        [Trait("Category", "Integration")]
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
        [Trait("Category", "Integration")]
        public async Task UnHealth_QuandoChamado_DeveRetornar200EBloquearRequests()
        {
            var unhealth = await _client.PutAsync("/config/unhealth", null);
            unhealth.StatusCode.Should().Be(HttpStatusCode.OK);

            var response = await _client.GetAsync("/produto");
            response.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        }

        [Fact]
        [Trait("Category", "Integration")]
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