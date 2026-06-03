content = '''using System.Net;
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
                        var descriptor = services.SingleOrDefault(
                            d => d.ServiceType == typeof(IMongoDatabase));
                        if (descriptor != null)
                            services.Remove(descriptor);
                        services.AddSingleton<IMongoDatabase>(mongo.Database);
                    });
                });

            _client = factory.CreateClient(new WebApplicationFactoryClientOptions
            {
                AllowAutoRedirect = false,
                HandleCookies = false
            });
        }

        [Fact][Trait("Category", "Smoke")]
        public async Task Api_QuandoIniciada_DeveResponderNaRotaProduto()
        {
            var response = await _client.GetAsync("/produto");
            response.StatusCode.Should().NotBe(HttpStatusCode.ServiceUnavailable);
            response.StatusCode.Should().NotBe(HttpStatusCode.InternalServerError);
        }

        [Fact][Trait("Category", "Smoke")]
        public async Task Api_QuandoIniciada_DeveRetornarContentTypeJson()
        {
            var response = await _client.GetAsync("/produto");
            response.Content.Headers.ContentType?.MediaType.Should().Be("application/json");
        }

        [Fact][Trait("Category", "Smoke")]
        public async Task Config_RotaUnreadFor_DeveEstarAcessivel()
        {
            var response = await _client.PutAsync("/config/unreadfor/1", null);
            response.StatusCode.Should().Be(HttpStatusCode.OK);
        }

        [Fact][Trait("Category", "Smoke")]
        public async Task Api_RotaInexistente_DeveRetornar404()
        {
            var response = await _client.GetAsync("/rota-que-nao-existe");
            response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        }
    }
}
'''
with open('tests/PedeLogo.Catalogo.IntegrationTests/SmokeTests.cs', 'w') as f:
    f.write(content)
print("OK")