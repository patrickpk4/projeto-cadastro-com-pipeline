cat > tests/PedeLogo.Catalogo.UnitTests/ProdutoControllerTests.cs << 'EOF'
using System.Collections.Generic;
using System.Threading;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using MongoDB.Bson;
using MongoDB.Driver;
using PedeLogo.Catalogo.Api.Controllers;
using PedeLogo.Catalogo.Api.Model;
using Xunit;

namespace PedeLogo.Catalogo.UnitTests
{
    public class ProdutoControllerTests
    {
        private readonly Mock<ILogger<ProdutoController>> _loggerMock;
        private readonly Mock<IMongoDatabase> _dbMock;
        private readonly Mock<IMongoCollection<Produto>> _collectionMock;
        private readonly ProdutoController _controller;

        public ProdutoControllerTests()
        {
            _loggerMock = new Mock<ILogger<ProdutoController>>();
            _dbMock = new Mock<IMongoDatabase>();
            _collectionMock = new Mock<IMongoCollection<Produto>>();

            _dbMock
                .Setup(db => db.GetCollection<Produto>("Produto", null))
                .Returns(_collectionMock.Object);

            _controller = new ProdutoController(_loggerMock.Object, _dbMock.Object);
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void Get_QuandoExistemProdutos_DeveRetornarLista()
        {
            var produtos = new List<Produto>
            {
                new Produto { Id = ObjectId.GenerateNewId().ToString(), Nome = "Pizza", Preco = 39.90, Categoria = "Comida" },
                new Produto { Id = ObjectId.GenerateNewId().ToString(), Nome = "Refrigerante", Preco = 7.00, Categoria = "Bebida" }
            };

            var cursorMock = CriarCursorMock(produtos);
            _collectionMock
                .Setup(c => c.FindSync(
                    It.IsAny<FilterDefinition<Produto>>(),
                    It.IsAny<FindOptions<Produto, Produto>>(),
                    It.IsAny<CancellationToken>()))
                .Returns(cursorMock.Object);

            var resultado = _controller.Get();

            resultado.Should().HaveCount(2);
            resultado.Should().ContainSingle(p => p.Nome == "Pizza");
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void Get_QuandoNaoExistemProdutos_DeveRetornarListaVazia()
        {
            var cursorMock = CriarCursorMock(new List<Produto>());
            _collectionMock
                .Setup(c => c.FindSync(
                    It.IsAny<FilterDefinition<Produto>>(),
                    It.IsAny<FindOptions<Produto, Produto>>(),
                    It.IsAny<CancellationToken>()))
                .Returns(cursorMock.Object);

            var resultado = _controller.Get();

            resultado.Should().BeEmpty();
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void GetById_ComIdValido_DeveRetornarProduto()
        {
            var id = ObjectId.GenerateNewId().ToString();
            var produto = new Produto { Id = id, Nome = "Hamburguer", Preco = 25.00, Categoria = "Comida" };

            var cursorMock = CriarCursorMock(new List<Produto> { produto });
            _collectionMock
                .Setup(c => c.FindSync(
                    It.IsAny<FilterDefinition<Produto>>(),
                    It.IsAny<FindOptions<Produto, Produto>>(),
                    It.IsAny<CancellationToken>()))
                .Returns(cursorMock.Object);

            var resultado = _controller.Get(id);

            resultado.Should().NotBeNull();
            resultado.Nome.Should().Be("Hamburguer");
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void GetById_ComIdInvalido_DeveLancarException()
        {
            var idInvalido = "id-que-nao-e-objectid";

            var act = () => _controller.Get(idInvalido);

            act.Should().Throw<System.Exception>()
               .WithMessage("Erro ao converter.");
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void Post_ComProdutoValido_DeveRetornarOk()
        {
            var produto = new Produto { Nome = "Sushi", Preco = 55.00, Categoria = "Japonesa" };

            _collectionMock
                .Setup(c => c.InsertOne(produto, null, default))
                .Verifiable();

            var resultado = _controller.Post(produto);

            res