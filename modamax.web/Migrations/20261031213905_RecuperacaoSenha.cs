using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace modamax.web.Migrations
{
    /// <inheritdoc />
    public partial class RecuperacaoSenha : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RecuperacaoSenha",
                columns: table => new
                {
                    IdRecuperacao = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    IdUsuario = table.Column<int>(type: "int", nullable: false),
                    TokenHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CriadoEm = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiraEm = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UsadoEm = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecuperacaoSenha", x => x.IdRecuperacao);
                    table.ForeignKey(
                        name: "FK_RecuperacaoSenha_Usuario_IdUsuario",
                        column: x => x.IdUsuario,
                        principalTable: "Usuario",
                        principalColumn: "IdUsuario",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RecuperacaoSenha_IdUsuario",
                table: "RecuperacaoSenha",
                column: "IdUsuario");

            migrationBuilder.CreateIndex(
                name: "IX_RecuperacaoSenha_TokenHash",
                table: "RecuperacaoSenha",
                column: "TokenHash",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RecuperacaoSenha");
        }
    }
}
