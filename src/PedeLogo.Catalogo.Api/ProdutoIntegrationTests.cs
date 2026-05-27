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
    /// <summary>
    /// Fixture que sobe um MongoDB em memória (Mongo2Go) compartilhado entre os testes.
    /// </summary>
    public class MongoFixture : IDisposable
    {
        public MongoDbRunner Runner { get; }
        public IMongoDatabase Database { get; }

        public MongoFixture()
        {
            Runner = MongoDbRunner.Start();
            var client = new MongoClient(Runner.ConnectionString);
            Database = client.GetDatabase("catalogo_test");
        }

        public void Dispose() => Runner.Dispose();
    }

    /// <summary>
    /// Testes de integração do ProdutoController.
    /// Usa WebApplicationFactory + Mongo2Go (MongoDB em memória).
    /// Nenhuma infra externa necessária.
    /// </summary>
    public class ProdutoIntegrationTests : IClassFixture<MongoFixture>
    {
        private readonly HttpClient _client;
        private readonly IMongoCollection<Produto> _collection;

        public ProdutoIntegrationTests(MongoFixture mongo)
        {
            _collection = mongo.Database.GetCollection<Produto>("Produto");

            var factory = new WebApplicationFactory<Startup>()
                .WithWebHostBuilder(builder =>
                {
                    builder.UseEnvironment("Testing");
                    builder.ConfigureServices(services =>
                    {
                        // Substitui o IMongoDatabase pelo banco em memória
                        services.AddSingleton<IMongoDatabase>(mongo.Database);
                    });
                });

            _client = factory.CreateClient();
        }

        private async Task LimparColecao() =>
            await _collection.DeleteManyAsync(new BsonDocument());

        private StringContent Json(object obj) =>
            new StringContent(
                JsonSerializer.Serialize(obj),
                Encoding.UTF8,
                "application/json");

        // ─── GET ALL ──────────────────────────────────────────────────────────

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

        // ─── GET BY ID ────────────────────────────────────────────────────────

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
        public async Task GetById_ComIdInvalido_DeveRetornar500()
        {
            var response = await _client.GetAsync("/produto/id-invalido-aqui");

            response.StatusCode.Should().Be(HttpStatusCode.InternalServerError);
        }

        // ─── POST ─────────────────────────────────────────────────────────────

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

        // ─── DELETE ───────────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Integration")]
        public async Task Delete_ComIdExistente_DeveRemoverDoBanco()
        {
            await LimparColecao();
            var id = ObjectId.GenerateNewId().ToString();
            await _collection.InsertOneAsync(new Produto { Id = id, Nome = "Produto Temporário", Preco = 1.00 });

            await _client.DeleteAsync($"/produto?id={id}");

            var count = await _collection.CountDocumentsAsync(new BsonDocument());
            count.Should().Be(0);
        }

        // ─── HEALTH / CONFIG ──────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Integration")]
        public async Task UnHealth_QuandoChamado_DeveRetornar200EBloquearRequests()
        {
            // Marca a aplicação como unhealthy
            var unhealth = await _client.PutAsync("/config/unhealth", null);
            unhealth.StatusCode.Should().Be(HttpStatusCode.OK);

            // Próximas requisições devem retornar 503
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
    }
}
