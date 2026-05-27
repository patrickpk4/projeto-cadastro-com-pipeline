using FluentAssertions;
using MongoDB.Bson;
using PedeLogo.Catalogo.Api.Model;
using Xunit;

namespace PedeLogo.Catalogo.UnitTests
{
    /// <summary>
    /// Testes do modelo Produto — validações de propriedades e serialização.
    /// </summary>
    public class ProdutoModelTests
    {
        [Fact]
        [Trait("Category", "Unit")]
        public void Produto_QuandoCriado_DeveTerPropriedadesNulas()
        {
            var produto = new Produto();

            produto.Id.Should().BeNull();
            produto.Nome.Should().BeNull();
            produto.Categoria.Should().BeNull();
            produto.Preco.Should().Be(0);
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void Produto_QuandoPreenchido_DeveManterValores()
        {
            var id = ObjectId.GenerateNewId().ToString();

            var produto = new Produto
            {
                Id = id,
                Nome = "Pizza Margherita",
                Preco = 42.90,
                Categoria = "Pizzas"
            };

            produto.Id.Should().Be(id);
            produto.Nome.Should().Be("Pizza Margherita");
            produto.Preco.Should().Be(42.90);
            produto.Categoria.Should().Be("Pizzas");
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void Produto_Id_DeveAceitarObjectIdValido()
        {
            var objectId = ObjectId.GenerateNewId().ToString();
            var produto = new Produto { Id = objectId };

            ObjectId.TryParse(produto.Id, out _).Should().BeTrue();
        }

        [Theory]
        [Trait("Category", "Unit")]
        [InlineData(0.01)]
        [InlineData(9.99)]
        [InlineData(999.99)]
        public void Produto_Preco_DeveAceitarValoresPositivos(double preco)
        {
            var produto = new Produto { Preco = preco };

            produto.Preco.Should().BePositive();
        }
    }
}
