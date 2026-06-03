using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using MongoDB.Driver;
using PedeLogo.Catalogo.Api;
using Xunit;

namespace PedeLogo.Catalogo.IntegrationTests
{
    public class SmokeTests : IClassFixture<MongoFixture>, IClassFixture<CustomWebApplicationFactory>
    {
        private readonly HttpClient _client;

        public SmokeTests(MongoFixture mongo, CustomWebApplicationFactory factory)
        {
            if (mongo.Database != null)
                factory.MongoDatabase = mongo.Database;
            
            _client = factory.CreateClient();
            _client.DefaultRequestHeaders.Clear();
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