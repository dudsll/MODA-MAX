IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
CREATE TABLE [Categoria] (
    [IdCategoria] int NOT NULL IDENTITY,
    [Nome] nvarchar(50) NOT NULL,
    CONSTRAINT [PK_Categoria] PRIMARY KEY ([IdCategoria])
);

CREATE TABLE [Cliente] (
    [IdCliente] int NOT NULL IDENTITY,
    [Nome] nvarchar(100) NOT NULL,
    [Tipo] nvarchar(10) NOT NULL,
    [Documento] nvarchar(20) NOT NULL,
    [Email] nvarchar(100) NOT NULL,
    [Telefone] nvarchar(20) NULL,
    [Endereco] nvarchar(200) NULL,
    CONSTRAINT [PK_Cliente] PRIMARY KEY ([IdCliente])
);

CREATE TABLE [Fornecedor] (
    [IdFornecedor] int NOT NULL IDENTITY,
    [Nome] nvarchar(100) NOT NULL,
    [CNPJ] nvarchar(20) NULL,
    [Contato] nvarchar(100) NULL,
    [Telefone] nvarchar(20) NULL,
    CONSTRAINT [PK_Fornecedor] PRIMARY KEY ([IdFornecedor])
);

CREATE TABLE [Usuario] (
    [IdUsuario] int NOT NULL IDENTITY,
    [Nome] nvarchar(100) NOT NULL,
    [Email] nvarchar(100) NOT NULL,
    [Senha] nvarchar(256) NOT NULL,
    [Nivel] nvarchar(30) NOT NULL,
    CONSTRAINT [PK_Usuario] PRIMARY KEY ([IdUsuario])
);

CREATE TABLE [Pedido] (
    [IdPedido] int NOT NULL IDENTITY,
    [IdCliente] int NOT NULL,
    [DataPedido] datetime2 NOT NULL,
    [TiposVenda] nvarchar(10) NOT NULL,
    [Status] nvarchar(50) NOT NULL,
    [ValorTotal] decimal(10,2) NOT NULL,
    CONSTRAINT [PK_Pedido] PRIMARY KEY ([IdPedido]),
    CONSTRAINT [CK_Pedido_ValorTotal] CHECK ([ValorTotal] >= 0),
    CONSTRAINT [FK_Pedido_Cliente_IdCliente] FOREIGN KEY ([IdCliente]) REFERENCES [Cliente] ([IdCliente]) ON DELETE NO ACTION
);

CREATE TABLE [Produto] (
    [IdProduto] int NOT NULL IDENTITY,
    [Nome] nvarchar(200) NOT NULL,
    [Descricao] nvarchar(500) NULL,
    [Tamanho] nvarchar(10) NOT NULL,
    [Cor] nvarchar(30) NOT NULL,
    [Preco] decimal(10,2) NOT NULL,
    [Estoque] int NOT NULL,
    [IdCategoria] int NOT NULL,
    [IdFornecedor] int NOT NULL,
    CONSTRAINT [PK_Produto] PRIMARY KEY ([IdProduto]),
    CONSTRAINT [CK_Produto_Estoque] CHECK ([Estoque] >= 0),
    CONSTRAINT [CK_Produto_Preco] CHECK ([Preco] >= 0),
    CONSTRAINT [FK_Produto_Categoria_IdCategoria] FOREIGN KEY ([IdCategoria]) REFERENCES [Categoria] ([IdCategoria]) ON DELETE NO ACTION,
    CONSTRAINT [FK_Produto_Fornecedor_IdFornecedor] FOREIGN KEY ([IdFornecedor]) REFERENCES [Fornecedor] ([IdFornecedor]) ON DELETE NO ACTION
);

CREATE TABLE [LogSistema] (
    [IdLog] int NOT NULL IDENTITY,
    [IdUsuario] int NULL,
    [Acao] nvarchar(max) NOT NULL,
    [Data] datetime2 NOT NULL,
    CONSTRAINT [PK_LogSistema] PRIMARY KEY ([IdLog]),
    CONSTRAINT [FK_LogSistema_Usuario_IdUsuario] FOREIGN KEY ([IdUsuario]) REFERENCES [Usuario] ([IdUsuario]) ON DELETE SET NULL
);

CREATE TABLE [ItemPedido] (
    [IdItem] int NOT NULL IDENTITY,
    [IdPedido] int NOT NULL,
    [IdProduto] int NOT NULL,
    [Quantidade] int NOT NULL,
    [PrecoUnitario] decimal(10,2) NOT NULL,
    [Desconto] decimal(10,2) NOT NULL,
    CONSTRAINT [PK_ItemPedido] PRIMARY KEY ([IdItem]),
    CONSTRAINT [CK_ItemPedido_Quantidade] CHECK ([Quantidade] > 0),
    CONSTRAINT [FK_ItemPedido_Pedido_IdPedido] FOREIGN KEY ([IdPedido]) REFERENCES [Pedido] ([IdPedido]) ON DELETE CASCADE,
    CONSTRAINT [FK_ItemPedido_Produto_IdProduto] FOREIGN KEY ([IdProduto]) REFERENCES [Produto] ([IdProduto]) ON DELETE NO ACTION
);

CREATE TABLE [MovimentacaoEstoque] (
    [IdMovi] int NOT NULL IDENTITY,
    [IdProduto] int NOT NULL,
    [Tipo] nvarchar(20) NOT NULL,
    [Quantidade] int NOT NULL,
    [Data] datetime2 NOT NULL,
    [Observacao] nvarchar(200) NULL,
    CONSTRAINT [PK_MovimentacaoEstoque] PRIMARY KEY ([IdMovi]),
    CONSTRAINT [FK_MovimentacaoEstoque_Produto_IdProduto] FOREIGN KEY ([IdProduto]) REFERENCES [Produto] ([IdProduto]) ON DELETE NO ACTION
);

CREATE INDEX [IX_ItemPedido_IdPedido] ON [ItemPedido] ([IdPedido]);

CREATE INDEX [IX_ItemPedido_IdProduto] ON [ItemPedido] ([IdProduto]);

CREATE INDEX [IX_LogSistema_IdUsuario] ON [LogSistema] ([IdUsuario]);

CREATE INDEX [IX_MovimentacaoEstoque_IdProduto] ON [MovimentacaoEstoque] ([IdProduto]);

CREATE INDEX [IX_Pedido_DataPedido] ON [Pedido] ([DataPedido]);

CREATE INDEX [IX_Pedido_IdCliente] ON [Pedido] ([IdCliente]);

CREATE INDEX [IX_Produto_IdCategoria] ON [Produto] ([IdCategoria]);

CREATE INDEX [IX_Produto_IdFornecedor] ON [Produto] ([IdFornecedor]);

CREATE UNIQUE INDEX [IX_Usuario_Email] ON [Usuario] ([Email]);

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20261030025741_EstruturaInicialSqlServer', N'10.0.14');

COMMIT;
GO

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
GO

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
GO

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
GO

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
GO

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
GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20261030025750_ProceduresETriggers', N'10.0.14');
GO

BEGIN TRANSACTION;
CREATE TABLE [RecuperacaoSenha] (
    [IdRecuperacao] int NOT NULL IDENTITY,
    [IdUsuario] int NOT NULL,
    [TokenHash] nvarchar(64) NOT NULL,
    [CriadoEm] datetime2 NOT NULL,
    [ExpiraEm] datetime2 NOT NULL,
    [UsadoEm] datetime2 NULL,
    CONSTRAINT [PK_RecuperacaoSenha] PRIMARY KEY ([IdRecuperacao]),
    CONSTRAINT [FK_RecuperacaoSenha_Usuario_IdUsuario] FOREIGN KEY ([IdUsuario]) REFERENCES [Usuario] ([IdUsuario]) ON DELETE CASCADE
);

CREATE INDEX [IX_RecuperacaoSenha_IdUsuario] ON [RecuperacaoSenha] ([IdUsuario]);

CREATE UNIQUE INDEX [IX_RecuperacaoSenha_TokenHash] ON [RecuperacaoSenha] ([TokenHash]);

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20261031213905_RecuperacaoSenha', N'10.0.14');

COMMIT;
GO

