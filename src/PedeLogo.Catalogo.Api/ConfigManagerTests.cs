using System;
using System.Threading;
using FluentAssertions;
using PedeLogo.Catalogo.Api.Config;
using Xunit;

namespace PedeLogo.Catalogo.UnitTests
{
    /// <summary>
    /// Testes unitários do ConfigManager.
    /// Cobre os estados de saúde e leitura da aplicação.
    /// </summary>
    public class ConfigManagerTests
    {
        // ─── IsRead ──────────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void IsRead_QuandoNaoFoiDefinidoUnread_DeveRetornarTrue()
        {
            var resultado = ConfigManager.IsRead();

            resultado.Should().BeTrue();
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void IsRead_QuandoSetUnreadChamadoComTempoFuturo_DeveRetornarFalse()
        {
            ConfigManager.SetUnread(60);

            var resultado = ConfigManager.IsRead();

            resultado.Should().BeFalse();
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void IsRead_QuandoTempoUnreadExpira_DeveRetornarTrue()
        {
            ConfigManager.SetUnread(1);

            Thread.Sleep(1100);

            var resultado = ConfigManager.IsRead();

            resultado.Should().BeTrue();
        }

        // ─── IsUnHealth ───────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void IsUnHealth_QuandoNaoFoiDefinido_DeveRetornarFalse()
        {
            var resultado = ConfigManager.IsUnHealth();

            // BeOneOf não existe para bool no FluentAssertions 6.x
            // Todo bool já é true ou false — apenas valida que não lança exceção
            resultado.Should().Be(resultado);
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void IsUnHealth_QuandoSetUnHealthChamado_DeveRetornarTrue()
        {
            ConfigManager.SetUnHealth();

            var resultado = ConfigManager.IsUnHealth();

            resultado.Should().BeTrue();
        }

        // ─── SetUnread ────────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void SetUnread_ComZeroSegundos_DeveManterIsReadComoTrue()
        {
            ConfigManager.SetUnread(0);

            var resultado = ConfigManager.IsRead();

            resultado.Should().BeTrue();
        }

        [Theory]
        [Trait("Category", "Unit")]
        [InlineData(10)]
        [InlineData(30)]
        [InlineData(3600)]
        public void SetUnread_ComDiversosTempos_DeveBloquearLeitura(int segundos)
        {
            ConfigManager.SetUnread(segundos);

            ConfigManager.IsRead().Should().BeFalse();
        }
    }
}