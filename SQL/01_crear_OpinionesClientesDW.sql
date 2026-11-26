USE master;
GO

IF DB_ID(N'OpinionesClientesDW') IS NULL
    EXEC(N'CREATE DATABASE OpinionesClientesDW');
GO

USE OpinionesClientesDW;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    IF DB_NAME() <> N'OpinionesClientesDW'
        THROW 50001, 'No se pudo seleccionar OpinionesClientesDW. Revise los mensajes anteriores.', 1;

    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.DimFecha', N'U') IS NULL
    CREATE TABLE dbo.DimFecha
    (
        FechaKey INT NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY,
        Fecha DATE NOT NULL CONSTRAINT UQ_DimFecha_Fecha UNIQUE,
        Anio SMALLINT NOT NULL,
        Trimestre TINYINT NOT NULL,
        Mes TINYINT NOT NULL,
        Dia TINYINT NOT NULL,
        CONSTRAINT CK_DimFecha_Valores CHECK
        (
            FechaKey = YEAR(Fecha) * 10000 + MONTH(Fecha) * 100 + DAY(Fecha)
            AND Anio = YEAR(Fecha)
            AND Trimestre = DATEPART(QUARTER, Fecha)
            AND Mes = MONTH(Fecha)
            AND Dia = DAY(Fecha)
        )
    );

    IF OBJECT_ID(N'dbo.DimProducto', N'U') IS NULL
    CREATE TABLE dbo.DimProducto
    (
        ProductoKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProducto PRIMARY KEY,
        IdProductoOLTP INT NOT NULL CONSTRAINT UQ_DimProducto_Origen UNIQUE,
        Nombre NVARCHAR(150) NOT NULL,
        Categoria NVARCHAR(100) NOT NULL
    );

    IF OBJECT_ID(N'dbo.DimCliente', N'U') IS NULL
    CREATE TABLE dbo.DimCliente
    (
        ClienteKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCliente PRIMARY KEY,
        IdClienteOLTP INT NOT NULL CONSTRAINT UQ_DimCliente_Origen UNIQUE,
        Nombre NVARCHAR(150) NOT NULL,
        Email NVARCHAR(254) NULL,
        Pais NVARCHAR(60) NULL,
        GrupoEdad NVARCHAR(20) NULL,
        TipoCliente NVARCHAR(40) NULL
    );

    IF OBJECT_ID(N'dbo.DimFuente', N'U') IS NULL
    CREATE TABLE dbo.DimFuente
    (
        FuenteKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimFuente PRIMARY KEY,
        IdFuenteOLTP VARCHAR(30) NOT NULL CONSTRAINT UQ_DimFuente_Origen UNIQUE,
        TipoFuente NVARCHAR(30) NOT NULL,
        Canal NVARCHAR(50) NULL,
        CONSTRAINT CK_DimFuente_Tipo CHECK
            (TipoFuente IN (N'Encuesta', N'ResenaWeb', N'RedSocial'))
    );

    IF OBJECT_ID(N'dbo.DimClasificacion', N'U') IS NULL
    CREATE TABLE dbo.DimClasificacion
    (
        ClasificacionKey TINYINT NOT NULL CONSTRAINT PK_DimClasificacion PRIMARY KEY,
        Nombre NVARCHAR(10) NOT NULL CONSTRAINT UQ_DimClasificacion_Nombre UNIQUE,
        CONSTRAINT CK_DimClasificacion_Valores CHECK
        (
            (ClasificacionKey = 1 AND Nombre = N'Positiva') OR
            (ClasificacionKey = 2 AND Nombre = N'Negativa') OR
            (ClasificacionKey = 3 AND Nombre = N'Neutra') OR
            (ClasificacionKey = 4 AND Nombre = N'Pendiente')
        )
    );

    IF OBJECT_ID(N'dbo.DimEvento', N'U') IS NULL
    CREATE TABLE dbo.DimEvento
    (
        EventoKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEvento PRIMARY KEY,
        CodigoEvento NVARCHAR(50) NOT NULL CONSTRAINT UQ_DimEvento_Codigo UNIQUE,
        Nombre NVARCHAR(150) NOT NULL,
        TipoEvento NVARCHAR(40) NOT NULL,
        FechaInicio DATE NOT NULL,
        FechaFin DATE NULL,
        CONSTRAINT CK_DimEvento_Fechas CHECK
            (FechaFin IS NULL OR FechaFin >= FechaInicio)
    );

    IF OBJECT_ID(N'dbo.HechoOpiniones', N'U') IS NULL
    CREATE TABLE dbo.HechoOpiniones
    (
        OpinionKey BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HechoOpiniones PRIMARY KEY,
        IdOpinionOLTP BIGINT NOT NULL CONSTRAINT UQ_HechoOpiniones_Origen UNIQUE,
        ProductoKey INT NOT NULL,
        ClienteKey INT NULL,
        FuenteKey INT NOT NULL,
        FechaKey INT NOT NULL,
        ClasificacionKey TINYINT NOT NULL
            CONSTRAINT DF_HechoOpiniones_Clasificacion DEFAULT (4),
        EventoKey INT NULL,
        IdRegistroOrigen NVARCHAR(100) NOT NULL,
        FechaOpinion DATETIME2(0) NOT NULL,
        Comentario NVARCHAR(MAX) NOT NULL,
        PuntajeSatisfaccion TINYINT NULL,
        FechaCarga DATETIME2(0) NOT NULL
            CONSTRAINT DF_HechoOpiniones_FechaCarga DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_HechoOpiniones_Fuente_Registro UNIQUE (FuenteKey, IdRegistroOrigen),
        CONSTRAINT CK_HechoOpiniones_Puntaje CHECK
            (PuntajeSatisfaccion IS NULL OR PuntajeSatisfaccion BETWEEN 1 AND 5),
        CONSTRAINT CK_HechoOpiniones_Fecha CHECK
            (FechaKey = YEAR(FechaOpinion) * 10000 + MONTH(FechaOpinion) * 100 + DAY(FechaOpinion)),
        CONSTRAINT CK_HechoOpiniones_Comentario CHECK
            (LEN(LTRIM(RTRIM(Comentario))) > 0),
        CONSTRAINT CK_HechoOpiniones_Registro CHECK
            (LEN(LTRIM(RTRIM(IdRegistroOrigen))) > 0),
        CONSTRAINT FK_HechoOpiniones_Producto FOREIGN KEY (ProductoKey)
            REFERENCES dbo.DimProducto (ProductoKey),
        CONSTRAINT FK_HechoOpiniones_Cliente FOREIGN KEY (ClienteKey)
            REFERENCES dbo.DimCliente (ClienteKey),
        CONSTRAINT FK_HechoOpiniones_Fuente FOREIGN KEY (FuenteKey)
            REFERENCES dbo.DimFuente (FuenteKey),
        CONSTRAINT FK_HechoOpiniones_Fecha FOREIGN KEY (FechaKey)
            REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_HechoOpiniones_Clasificacion FOREIGN KEY (ClasificacionKey)
            REFERENCES dbo.DimClasificacion (ClasificacionKey),
        CONSTRAINT FK_HechoOpiniones_Evento FOREIGN KEY (EventoKey)
            REFERENCES dbo.DimEvento (EventoKey)
    );

    INSERT INTO dbo.DimClasificacion (ClasificacionKey, Nombre)
    SELECT v.ClasificacionKey, v.Nombre
    FROM (VALUES (1, N'Positiva'), (2, N'Negativa'), (3, N'Neutra'), (4, N'Pendiente'))
        AS v(ClasificacionKey, Nombre)
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.DimClasificacion AS d
        WHERE d.ClasificacionKey = v.ClasificacionKey
    );

    IF NOT EXISTS (SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.HechoOpiniones') AND name = N'IX_HechoOpiniones_Fecha_Producto')
        CREATE INDEX IX_HechoOpiniones_Fecha_Producto
        ON dbo.HechoOpiniones (FechaKey, ProductoKey)
        INCLUDE (ClasificacionKey, PuntajeSatisfaccion, FuenteKey);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT DB_NAME() AS BaseCreada, N'Modelo disponible' AS Resultado;
GO
