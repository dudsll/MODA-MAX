using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace modamax.web.Migrations
{
    /// <summary>
    /// Procedures e triggers do banco ModaMax (SQL Server).
    /// Cada comando CREATE fica em um migrationBuilder.Sql proprio porque o
    /// SQL Server exige que CREATE PROCEDURE/TRIGGER seja o unico comando do lote.
    /// </summary>
    public partial class ProceduresETriggers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Relatorio de vendas agrupado por dia (usado em GET /api/relatorios/vendas).
            migrationBuilder.Sql("""
                CREATE OR ALTER PROCEDURE dbo.sp_RelatorioVendasPeriodo
                    @DataInicial DATE,
                    @DataFinal DATE
                AS
                BEGIN
                    SET NOCOUNT ON;

                    SELECT
                        CAST(p.DataPedido AS DATE)          AS Dia,
                        COUNT(*)                            AS Pedidos,
                        CAST(ISNULL(SUM(it.Qtd), 0) AS INT) AS Itens,
                        CAST(SUM(p.ValorTotal) AS DECIMAL(12, 2)) AS Total
                    FROM dbo.Pedido p
                    OUTER APPLY (
                        SELECT SUM(i.Quantidade) AS Qtd
                        FROM dbo.ItemPedido i
                        WHERE i.IdPedido = p.IdPedido
                    ) it
                    WHERE p.Status <> 'Cancelado'
                      AND CAST(p.DataPedido AS DATE) BETWEEN @DataInicial AND @DataFinal
                    GROUP BY CAST(p.DataPedido AS DATE)
                    ORDER BY Dia;
                END
                """, suppressTransaction: true);

            // Produtos com estoque igual ou abaixo do limite (GET /api/produtos/estoque-baixo).
            migrationBuilder.Sql("""
                CREATE OR ALTER PROCEDURE dbo.sp_ProdutosEstoqueBaixo
                    @Limite INT = 15
                AS
                BEGIN
                    SET NOCOUNT ON;

                    SELECT p.IdProduto, p.Nome, c.Nome AS Categoria, p.Estoque
                    FROM dbo.Produto p
                    INNER JOIN dbo.Categoria c ON c.IdCategoria = p.IdCategoria
                    WHERE p.Estoque <= @Limite
                    ORDER BY p.Estoque, p.Nome;
                END
                """, suppressTransaction: true);

            // Entrada de mercadoria: soma ao estoque e registra a movimentacao na mesma transacao
            // (POST /api/produtos/{id}/entrada-estoque).
            migrationBuilder.Sql("""
                CREATE OR ALTER PROCEDURE dbo.sp_RegistrarEntradaEstoque
                    @IdProduto INT,
                    @Quantidade INT,
                    @Observacao NVARCHAR(200) = NULL
                AS
                BEGIN
                    SET NOCOUNT ON;
                    SET XACT_ABORT ON;

                    IF @Quantidade <= 0
                        THROW 50001, 'A quantidade de entrada deve ser maior que zero.', 1;

                    IF NOT EXISTS (SELECT 1 FROM dbo.Produto WHERE IdProduto = @IdProduto)
                        THROW 50002, 'Produto nao encontrado.', 1;

                    BEGIN TRANSACTION;

                    UPDATE dbo.Produto
                    SET Estoque = Estoque + @Quantidade
                    WHERE IdProduto = @IdProduto;

                    INSERT INTO dbo.MovimentacaoEstoque (IdProduto, Tipo, Quantidade, Data, Observacao)
                    VALUES (@IdProduto, 'Entrada', @Quantidade, GETDATE(), ISNULL(@Observacao, 'Entrada de mercadoria'));

                    COMMIT TRANSACTION;

                    -- "Value" e o nome de coluna que o EF Core espera em SqlQuery<int>.
                    SELECT Estoque AS Value FROM dbo.Produto WHERE IdProduto = @IdProduto;
                END
                """, suppressTransaction: true);

            // Auditoria automatica: toda alteracao de preco vira um registro em LogSistema.
            migrationBuilder.Sql("""
                CREATE OR ALTER TRIGGER dbo.trg_Produto_AuditaPreco
                ON dbo.Produto
                AFTER UPDATE
                AS
                BEGIN
                    SET NOCOUNT ON;

                    IF NOT UPDATE(Preco) RETURN;

                    INSERT INTO dbo.LogSistema (IdUsuario, Acao, Data)
                    SELECT
                        NULL,
                        CONCAT('Trigger: preco do produto #', i.IdProduto, ' (', i.Nome, ') alterado de R$ ',
                               d.Preco, ' para R$ ', i.Preco, '.'),
                        GETDATE()
                    FROM inserted i
                    INNER JOIN deleted d ON d.IdProduto = i.IdProduto
                    WHERE i.Preco <> d.Preco;
                END
                """, suppressTransaction: true);

            // Auditoria automatica: toda mudanca de status de pedido vira um registro em LogSistema.
            migrationBuilder.Sql("""
                CREATE OR ALTER TRIGGER dbo.trg_Pedido_AuditaStatus
                ON dbo.Pedido
                AFTER UPDATE
                AS
                BEGIN
                    SET NOCOUNT ON;

                    IF NOT UPDATE(Status) RETURN;

                    INSERT INTO dbo.LogSistema (IdUsuario, Acao, Data)
                    SELECT
                        NULL,
                        CONCAT('Trigger: pedido #', i.IdPedido, ' mudou de "', d.Status, '" para "', i.Status, '".'),
                        GETDATE()
                    FROM inserted i
                    INNER JOIN deleted d ON d.IdPedido = i.IdPedido
                    WHERE i.Status <> d.Status;
                END
                """, suppressTransaction: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP TRIGGER IF EXISTS dbo.trg_Pedido_AuditaStatus;");
            migrationBuilder.Sql("DROP TRIGGER IF EXISTS dbo.trg_Produto_AuditaPreco;");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.sp_RegistrarEntradaEstoque;");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.sp_ProdutosEstoqueBaixo;");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.sp_RelatorioVendasPeriodo;");
        }
    }
}
