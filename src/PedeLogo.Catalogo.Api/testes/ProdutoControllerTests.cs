using System.Collections.Generic;
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
    /// <summary>
    /// Testes unitários do ProdutoController.
    /// O MongoDB é mockado — nenhum banco real é necessário.
    /// </summary>
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

        // ─── GET ALL ──────────────────────────────────────────────────────────

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
                .Setup(c => c.Find(It.IsAny<BsonDocument>(), null))
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
                .Setup(c => c.Find(It.IsAny<BsonDocument>(), null))
                .Returns(cursorMock.Object);

            var resultado = _controller.Get();

            resultado.Should().BeEmpty();
        }

        // ─── GET BY ID ────────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void GetById_ComIdValido_DeveRetornarProduto()
        {
            var id = ObjectId.GenerateNewId().ToString();
            var produto = new Produto { Id = id, Nome = "Hamburguer", Preco = 25.00, Categoria = "Comida" };

            var cursorMock = CriarCursorMock(new List<Produto> { produto });
            _collectionMock
                .Setup(c => c.Find(It.IsAny<System.Linq.Expressions.Expression<System.Func<Produto, bool>>>(), null))
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

        // ─── POST ─────────────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void Post_ComProdutoValido_DeveRetornarOk()
        {
            var produto = new Produto { Nome = "Sushi", Preco = 55.00, Categoria = "Japonesa" };

            _collectionMock
                .Setup(c => c.InsertOne(produto, null, default))
                .Verifiable();

            var resultado = _controller.Post(produto);

            resultado.Should().BeOfType<OkResult>();
            _collectionMock.Verify(c => c.InsertOne(produto, null, default), Times.Once);
        }

        // ─── PUT ──────────────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void Put_ComIdInvalido_DeveLancarException()
        {
            var idInvalido = "nao-e-objectid";
            var produto = new Produto { Nome = "Teste" };

            var act = () => _controller.Put(idInvalido, produto);

            act.Should().Throw<System.Exception>()
               .WithMessage("Id errado");
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void Put_ComIdValido_DeveChamarFindOneAndReplace()
        {
            var id = ObjectId.GenerateNewId().ToString();
            var produto = new Produto { Id = id, Nome = "Pizza Atualizada", Preco = 45.00 };

            _collectionMock
                .Setup(c => c.FindOneAndReplace(
                    It.IsAny<System.Linq.Expressions.Expression<System.Func<Produto, bool>>>(),
                    produto,
                    null,
                    default))
                .Returns(produto);

            var act = () => _controller.Put(id, produto);

            act.Should().NotThrow();
            _collectionMock.Verify(c => c.FindOneAndReplace(
                It.IsAny<System.Linq.Expressions.Expression<System.Func<Produto, bool>>>(),
                produto,
                null,
                default), Times.Once);
        }

        // ─── DELETE ───────────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void Delete_ComIdValido_DeveChamarFindOneAndDelete()
        {
            var id = ObjectId.GenerateNewId().ToString();

            _collectionMock
                .Setup(c => c.FindOneAndDelete(
                    It.IsAny<System.Linq.Expressions.Expression<System.Func<Produto, bool>>>(),
                    null,
                    default))
                .Returns((Produto)null);

            var act = () => _controller.Delete(id);

            act.Should().NotThrow();
        }

        // ─── Helpers ──────────────────────────────────────────────────────────

        private static Mock<IAsyncCursor<Produto>> CriarCursorMock(List<Produto> produtos)
        {
            var cursorMock = new Mock<IAsyncCursor<Produto>>();
            cursorMock.Setup(c => c.Current).Returns(produtos);
            cursorMock
                .SetupSequence(c => c.MoveNext(default))
                .Returns(true)
                .Returns(false);

            var findFluentMock = new Mock<IFindFluent<Produto, Produto>>();
            findFluentMock
                .Setup(f => f.ToList(default))
                .Returns(produtos);
            findFluentMock
                .Setup(f => f.FirstOrDefault(default))
                .Returns(produtos.Count > 0 ? produtos[0] : null);

            return cursorMock;
        }
    }
}
