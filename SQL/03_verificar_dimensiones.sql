USE [OpinionesClientesDW];
GO
-- A. Ejecutar antes y después de la carga.
SELECT N'DimCliente' AS Dimension,
       (SELECT COUNT_BIG(*) FROM OpinionesClientesDB.dbo.Clientes) AS FilasOrigen,
       (SELECT COUNT_BIG(*) FROM dbo.DimCliente) AS TotalDW
UNION ALL SELECT N'DimProducto', (SELECT COUNT_BIG(*) FROM OpinionesClientesDB.dbo.Productos),
       (SELECT COUNT_BIG(*) FROM dbo.DimProducto)
UNION ALL SELECT N'DimFuente', (SELECT COUNT_BIG(*) FROM OpinionesClientesDB.dbo.FuenteDatos),
       (SELECT COUNT_BIG(*) FROM dbo.DimFuente)
UNION ALL SELECT N'DimFecha', (SELECT COUNT(DISTINCT CONVERT(DATE, Fecha)) FROM OpinionesClientesDB.dbo.Opiniones),
       (SELECT COUNT_BIG(*) FROM dbo.DimFecha)
UNION ALL SELECT N'DimClasificacion', (SELECT COUNT_BIG(*) FROM OpinionesClientesDB.dbo.Clasificaciones),
       (SELECT COUNT_BIG(*) FROM dbo.DimClasificacion)
UNION ALL SELECT N'DimEvento', (SELECT COUNT_BIG(*) FROM stg.Eventos),
       (SELECT COUNT_BIG(*) FROM dbo.DimEvento);

SELECT COUNT_BIG(*) AS OpinionesEnHechos FROM dbo.HechoOpiniones;
GO
-- B. Muestras de clientes, productos y fuentes.
SELECT TOP (5) ClienteKey, IdClienteOLTP, Nombre, Pais, GrupoEdad, TipoCliente
FROM dbo.DimCliente ORDER BY IdClienteOLTP;

SELECT TOP (5) ProductoKey, IdProductoOLTP, Nombre, Categoria
FROM dbo.DimProducto ORDER BY IdProductoOLTP;

SELECT TipoFuente, COUNT_BIG(*) AS Fuentes FROM dbo.DimFuente GROUP BY TipoFuente ORDER BY TipoFuente;
SELECT TOP (5) FuenteKey, IdFuenteOLTP, TipoFuente, Canal
FROM dbo.DimFuente ORDER BY CASE WHEN Canal IS NULL THEN 1 ELSE 0 END, IdFuenteOLTP;
GO
-- C. Fechas, clasificaciones y eventos.
SELECT TOP (10) FechaKey, Fecha, Anio, Trimestre, Mes, Dia FROM dbo.DimFecha ORDER BY Fecha;
SELECT ClasificacionKey, Nombre FROM dbo.DimClasificacion ORDER BY ClasificacionKey;
SELECT TOP (5) EventoKey, CodigoEvento, Nombre, TipoEvento, FechaInicio, FechaFin
FROM dbo.DimEvento ORDER BY CodigoEvento;
GO
-- D. Claves del origen que siguen sin correspondencia en el DW.
SELECT N'Clientes' AS Origen, COUNT_BIG(*) AS ClavesSinCorrespondencia
FROM OpinionesClientesDB.dbo.Clientes AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCliente AS d WHERE d.IdClienteOLTP = s.IdCliente)
UNION ALL SELECT N'Productos', COUNT_BIG(*) FROM OpinionesClientesDB.dbo.Productos AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimProducto AS d WHERE d.IdProductoOLTP = s.IdProducto)
UNION ALL SELECT N'Fuentes', COUNT_BIG(*) FROM OpinionesClientesDB.dbo.FuenteDatos AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimFuente AS d WHERE d.IdFuenteOLTP = s.IdFuente COLLATE DATABASE_DEFAULT)
UNION ALL SELECT N'Fechas', COUNT(DISTINCT CONVERT(DATE, s.Fecha)) FROM OpinionesClientesDB.dbo.Opiniones AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimFecha AS d WHERE d.Fecha = CONVERT(DATE, s.Fecha))
UNION ALL SELECT N'Clasificaciones', COUNT_BIG(*) FROM OpinionesClientesDB.dbo.Clasificaciones AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimClasificacion AS d WHERE d.Nombre = s.Nombre COLLATE DATABASE_DEFAULT)
UNION ALL SELECT N'Eventos', COUNT_BIG(*) FROM stg.Eventos AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimEvento AS d WHERE d.CodigoEvento = s.CodigoEvento);
GO
