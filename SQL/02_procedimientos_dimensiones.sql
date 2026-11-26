USE [OpinionesClientesDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'stg') IS NULL
    EXEC(N'CREATE SCHEMA stg AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'stg.Eventos', N'U') IS NULL
    CREATE TABLE stg.Eventos
    (
        CodigoEvento NVARCHAR(50) PRIMARY KEY,
        Nombre NVARCHAR(150) NOT NULL,
        TipoEvento NVARCHAR(40) NOT NULL,
        FechaInicio DATE NOT NULL,
        FechaFin DATE NULL,
        CHECK (FechaFin IS NULL OR FechaFin >= FechaInicio)
    );
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarDimCliente
AS
BEGIN
    SET NOCOUNT ON;

    SELECT IdCliente AS IdClienteOLTP, Nombre, Email
    INTO #Origen
    FROM OpinionesClientesDB.dbo.Clientes;

    UPDATE d
    SET Nombre = s.Nombre, Email = s.Email
    FROM dbo.DimCliente AS d
    JOIN #Origen AS s ON s.IdClienteOLTP = d.IdClienteOLTP
    WHERE EXISTS (
        SELECT s.Nombre COLLATE Latin1_General_100_BIN2, s.Email COLLATE Latin1_General_100_BIN2
        EXCEPT
        SELECT d.Nombre COLLATE Latin1_General_100_BIN2, d.Email COLLATE Latin1_General_100_BIN2
    );
    DECLARE @Actualizadas BIGINT = ROWCOUNT_BIG();

    INSERT dbo.DimCliente (IdClienteOLTP, Nombre, Email)
    SELECT s.IdClienteOLTP, s.Nombre, s.Email
    FROM #Origen AS s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCliente AS d WHERE d.IdClienteOLTP = s.IdClienteOLTP);
    DECLARE @Insertadas BIGINT = ROWCOUNT_BIG();

    SELECT N'DimCliente', @Insertadas, @Actualizadas, COUNT_BIG(*) FROM dbo.DimCliente;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarDimProducto
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.IdProducto AS IdProductoOLTP, p.Nombre, c.Nombre AS Categoria
    INTO #Origen
    FROM OpinionesClientesDB.dbo.Productos AS p
    JOIN OpinionesClientesDB.dbo.Categorias AS c ON c.IdCategoria = p.IdCategoria;

    UPDATE d
    SET Nombre = s.Nombre, Categoria = s.Categoria
    FROM dbo.DimProducto AS d
    JOIN #Origen AS s ON s.IdProductoOLTP = d.IdProductoOLTP
    WHERE EXISTS (
        SELECT s.Nombre COLLATE Latin1_General_100_BIN2, s.Categoria COLLATE Latin1_General_100_BIN2
        EXCEPT
        SELECT d.Nombre COLLATE Latin1_General_100_BIN2, d.Categoria COLLATE Latin1_General_100_BIN2
    );
    DECLARE @Actualizadas BIGINT = ROWCOUNT_BIG();

    INSERT dbo.DimProducto (IdProductoOLTP, Nombre, Categoria)
    SELECT s.IdProductoOLTP, s.Nombre, s.Categoria
    FROM #Origen AS s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimProducto AS d WHERE d.IdProductoOLTP = s.IdProductoOLTP);
    DECLARE @Insertadas BIGINT = ROWCOUNT_BIG();

    SELECT N'DimProducto', @Insertadas, @Actualizadas, COUNT_BIG(*) FROM dbo.DimProducto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarDimFuente
AS
BEGIN
    SET NOCOUNT ON;

    SELECT IdFuente COLLATE DATABASE_DEFAULT AS IdFuenteOLTP,
           CASE TRIM(TipoFuente)
               WHEN N'CSV' THEN N'Encuesta'
               WHEN N'Web' THEN N'ResenaWeb'
               WHEN N'Red Social' THEN N'RedSocial'
           END AS TipoFuente, Canal
    INTO #Origen
    FROM OpinionesClientesDB.dbo.FuenteDatos;

    IF EXISTS (SELECT 1 FROM #Origen WHERE TipoFuente IS NULL)
        THROW 51001, 'Hay un TipoFuente sin equivalencia. Revise FuenteDatos antes de cargar.', 1;

    UPDATE d
    SET TipoFuente = s.TipoFuente, Canal = s.Canal
    FROM dbo.DimFuente AS d
    JOIN #Origen AS s ON s.IdFuenteOLTP = d.IdFuenteOLTP
    WHERE EXISTS (
        SELECT s.TipoFuente COLLATE Latin1_General_100_BIN2, s.Canal COLLATE Latin1_General_100_BIN2
        EXCEPT
        SELECT d.TipoFuente COLLATE Latin1_General_100_BIN2, d.Canal COLLATE Latin1_General_100_BIN2
    );
    DECLARE @Actualizadas BIGINT = ROWCOUNT_BIG();

    INSERT dbo.DimFuente (IdFuenteOLTP, TipoFuente, Canal)
    SELECT s.IdFuenteOLTP, s.TipoFuente, s.Canal
    FROM #Origen AS s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimFuente AS d WHERE d.IdFuenteOLTP = s.IdFuenteOLTP);
    DECLARE @Insertadas BIGINT = ROWCOUNT_BIG();

    SELECT N'DimFuente', @Insertadas, @Actualizadas, COUNT_BIG(*) FROM dbo.DimFuente;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarDimFecha
AS
BEGIN
    SET NOCOUNT ON;

    WITH Fechas AS (
        SELECT DISTINCT CONVERT(DATE, Fecha) AS Fecha FROM OpinionesClientesDB.dbo.Opiniones
    )
    INSERT dbo.DimFecha (FechaKey, Fecha, Anio, Trimestre, Mes, Dia)
    SELECT YEAR(f.Fecha) * 10000 + MONTH(f.Fecha) * 100 + DAY(f.Fecha), f.Fecha,
           YEAR(f.Fecha), DATEPART(QUARTER, f.Fecha), MONTH(f.Fecha), DAY(f.Fecha)
    FROM Fechas AS f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimFecha AS d WHERE d.Fecha = f.Fecha);
    DECLARE @Insertadas BIGINT = ROWCOUNT_BIG();

    SELECT N'DimFecha', @Insertadas, CONVERT(BIGINT, 0), COUNT_BIG(*) FROM dbo.DimFecha;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarDimClasificacion
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Catalogo TABLE (Clave TINYINT PRIMARY KEY, Nombre NVARCHAR(10) UNIQUE);
    INSERT @Catalogo VALUES (1, N'Positiva'), (2, N'Negativa'), (3, N'Neutra'), (4, N'Pendiente');

    IF EXISTS (
        SELECT 1 FROM OpinionesClientesDB.dbo.Clasificaciones AS c
        WHERE NOT EXISTS (
            SELECT 1 FROM @Catalogo AS d WHERE d.Nombre = c.Nombre COLLATE DATABASE_DEFAULT
        )
    )
        THROW 51002, 'Hay una clasificación sin equivalencia en el catálogo del DW.', 1;

    INSERT dbo.DimClasificacion (ClasificacionKey, Nombre)
    SELECT c.Clave, c.Nombre FROM @Catalogo AS c
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimClasificacion AS d WHERE d.ClasificacionKey = c.Clave);
    DECLARE @Insertadas BIGINT = ROWCOUNT_BIG();

    SELECT N'DimClasificacion', @Insertadas, CONVERT(BIGINT, 0), COUNT_BIG(*) FROM dbo.DimClasificacion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarDimEvento
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CodigoEvento, Nombre, TipoEvento, FechaInicio, FechaFin
    INTO #Origen
    FROM stg.Eventos;

    UPDATE d
    SET Nombre = s.Nombre, TipoEvento = s.TipoEvento, FechaInicio = s.FechaInicio, FechaFin = s.FechaFin
    FROM dbo.DimEvento AS d
    JOIN #Origen AS s ON s.CodigoEvento = d.CodigoEvento
    WHERE EXISTS (
        SELECT s.Nombre COLLATE Latin1_General_100_BIN2, s.TipoEvento COLLATE Latin1_General_100_BIN2, s.FechaInicio, s.FechaFin
        EXCEPT
        SELECT d.Nombre COLLATE Latin1_General_100_BIN2, d.TipoEvento COLLATE Latin1_General_100_BIN2, d.FechaInicio, d.FechaFin
    );
    DECLARE @Actualizadas BIGINT = ROWCOUNT_BIG();

    INSERT dbo.DimEvento (CodigoEvento, Nombre, TipoEvento, FechaInicio, FechaFin)
    SELECT s.CodigoEvento, s.Nombre, s.TipoEvento, s.FechaInicio, s.FechaFin
    FROM #Origen AS s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimEvento AS d WHERE d.CodigoEvento = s.CodigoEvento);
    DECLARE @Insertadas BIGINT = ROWCOUNT_BIG();

    SELECT N'DimEvento', @Insertadas, @Actualizadas, COUNT_BIG(*) FROM dbo.DimEvento;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarDimensiones
AS
BEGIN
    SET NOCOUNT ON;

    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    DECLARE @Resultado TABLE (
        Orden INT IDENTITY(1,1), Dimension SYSNAME,
        Insertadas BIGINT, Actualizadas BIGINT, Total BIGINT
    );

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Bloqueo INT;
        EXEC @Bloqueo = sys.sp_getapplock @Resource = N'OpinionesClientesDW.CargaDimensiones',
            @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 30000;
        IF @Bloqueo < 0 THROW 51003, 'Otra carga mantiene el bloqueo. Repita la ejecución.', 1;
        INSERT @Resultado EXEC dbo.usp_CargarDimCliente;
        INSERT @Resultado EXEC dbo.usp_CargarDimProducto;
        INSERT @Resultado EXEC dbo.usp_CargarDimFuente;
        INSERT @Resultado EXEC dbo.usp_CargarDimFecha;
        INSERT @Resultado EXEC dbo.usp_CargarDimClasificacion;
        INSERT @Resultado EXEC dbo.usp_CargarDimEvento;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT Dimension, Insertadas, Actualizadas, Total FROM @Resultado ORDER BY Orden;
END;
GO
