using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace modamax.web.Migrations
{
    /// <inheritdoc />
    public partial class MetasEPagamentos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FormaPagamento",
                table: "Pedido",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Pix");

            migrationBuilder.AddColumn<DateTime>(
                name: "PagoEm",
                table: "Pedido",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Parcelas",
                table: "Pedido",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<string>(
                name: "StatusPagamento",
                table: "Pedido",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Pendente");

            // Pedidos que ja existiam: os finalizados sao considerados pagos na data do pedido.
            // EXEC adia a compilacao: no script SQL as colunas novas ainda nao existem quando o lote e compilado.
            migrationBuilder.Sql(
                "EXEC('UPDATE Pedido SET StatusPagamento = ''Pago'', PagoEm = DataPedido WHERE Status = ''Finalizado'';');");

            migrationBuilder.CreateTable(
                name: "Meta",
                columns: table => new
                {
                    IdMeta = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Ano = table.Column<int>(type: "int", nullable: false),
                    Mes = table.Column<int>(type: "int", nullable: false),
                    Faturamento = table.Column<decimal>(type: "decimal(12,2)", nullable: false),
                    Pedidos = table.Column<int>(type: "int", nullable: false),
                    Pecas = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Meta", x => x.IdMeta);
                });

            migrationBuilder.AddCheckConstraint(
                name: "CK_Pedido_Parcelas",
                table: "Pedido",
                sql: "[Parcelas] BETWEEN 1 AND 6");

            migrationBuilder.CreateIndex(
                name: "IX_Meta_Ano_Mes",
                table: "Meta",
                columns: new[] { "Ano", "Mes" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Meta");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Pedido_Parcelas",
                table: "Pedido");

            migrationBuilder.DropColumn(
                name: "FormaPagamento",
                table: "Pedido");

            migrationBuilder.DropColumn(
                name: "PagoEm",
                table: "Pedido");

            migrationBuilder.DropColumn(
                name: "Parcelas",
                table: "Pedido");

            migrationBuilder.DropColumn(
                name: "StatusPagamento",
                table: "Pedido");
        }
    }
}
