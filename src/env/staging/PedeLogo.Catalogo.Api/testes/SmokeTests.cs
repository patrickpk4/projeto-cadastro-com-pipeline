using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Mongo2Go;
using MongoDB.Driver;
using PedeLogo.Catalogo.Api;
using Xunit;

namespace PedeLogo.Catalogo.IntegrationTests
{
    /// <summary>
    /// Smoke tests: verificam se a API sobe corretamente e responde nos endpoints principais.
    /// Rodam após cada deploy para confirmar que a aplicação está viva.
    /// </summary>
    public class SmokeTests : IClassFixture<MongoFixture>
    {
        private readonly HttpClient _client;

        public SmokeTests(MongoFixture mongo)
        {
            var factory = new WebApplicationFactory<Startup>()
                .WithWebHostBuilder(builder =>
                {
                    builder.UseEnvironment("Testing");
                    builder.ConfigureServices(services =>
                    {
                        services.AddSingleton<IMongoDatabase>(mongo.Database);
                    });
                });

            _client = factory.CreateClient();
        }

        [Fact]
        [Trait("Category", "Smoke")]
        public async Task Api_QuandoIniciada_DeveResponderNaRotaProduto()
        {
            var response = await _client.GetAsync("/produto");

            response.StatusCode.Should().NotBe(HttpStatusCode.ServiceUnavailable);
            response.StatusCode.Should().NotBe(HttpStatusCode.InternalServerError);
        }

        [Fact]
        [Trait("Category", "Smoke")]
        public async Task Api_QuandoIniciada_DeveRetornarContentTypeJson()
        {
            var response = await _client.GetAsync("/produto");

            response.Content.Headers.ContentType?.MediaType.Should().Be("application/json");
        }

        [Fact]
        [Trait("Category", "Smoke")]
        public async Task Config_RotaUnreadFor_DeveEstarAcessivel()
        {
            var response = await _client.PutAsync("/config/unreadfor/1", null);

            response.StatusCode.Should().Be(HttpStatusCode.OK);
        }

        [Fact]
        [Trait("Category", "Smoke")]
        public async Task Api_RotaInexistente_DeveRetornar404()
        {
            var response = await _client.GetAsync("/rota-que-nao-existe");

            response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        }
    }
}
