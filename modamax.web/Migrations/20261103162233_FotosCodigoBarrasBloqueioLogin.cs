using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace modamax.web.Migrations
{
    /// <inheritdoc />
    public partial class FotosCodigoBarrasBloqueioLogin : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "BloqueadoAte",
                table: "Usuario",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TentativasFalhas",
                table: "Usuario",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "CodigoBarras",
                table: "Produto",
                type: "nvarchar(14)",
                maxLength: 14,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FotoUrl",
                table: "Produto",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Produto_CodigoBarras",
                table: "Produto",
                column: "CodigoBarras",
                unique: true,
                filter: "[CodigoBarras] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Produto_CodigoBarras",
                table: "Produto");

            migrationBuilder.DropColumn(
                name: "BloqueadoAte",
                table: "Usuario");

            migrationBuilder.DropColumn(
                name: "TentativasFalhas",
                table: "Usuario");

            migrationBuilder.DropColumn(
                name: "CodigoBarras",
                table: "Produto");

            migrationBuilder.DropColumn(
                name: "FotoUrl",
                table: "Produto");
        }
    }
}
