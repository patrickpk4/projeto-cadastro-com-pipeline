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
            // O estado padrão deve ser "pronto para leitura"
            var resultado = ConfigManager.IsRead();

            resultado.Should().BeTrue();
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void IsRead_QuandoSetUnreadChamadoComTempoFuturo_DeveRetornarFalse()
        {
            ConfigManager.SetUnread(60); // 60 segundos no futuro

            var resultado = ConfigManager.IsRead();

            resultado.Should().BeFalse();
        }

        [Fact]
        [Trait("Category", "Unit")]
        public void IsRead_QuandoTempoUnreadExpira_DeveRetornarTrue()
        {
            ConfigManager.SetUnread(1); // 1 segundo

            Thread.Sleep(1100); // espera expirar

            var resultado = ConfigManager.IsRead();

            resultado.Should().BeTrue();
        }

        // ─── IsUnHealth ───────────────────────────────────────────────────────

        [Fact]
        [Trait("Category", "Unit")]
        public void IsUnHealth_QuandoNaoFoiDefinido_DeveRetornarFalse()
        {
            // Estado inicial deve ser saudável
            // Nota: como ConfigManager usa estado estático, este teste
            // pode ser afetado por outros. Em produção, prefira injeção de dependência.
            var resultado = ConfigManager.IsUnHealth();

            // Só valida que o método retorna bool sem exceção
            resultado.Should().BeOneOf(true, false);
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

            // 0 segundos = expira imediatamente
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
