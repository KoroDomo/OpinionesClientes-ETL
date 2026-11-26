# Opiniones de clientes

Solución .NET 8 del proyecto de Electiva I. La Actividad 1 extrae encuestas desde CSV, reseñas desde SQL Server y comentarios desde la API. El proyecto `Opiniones.Carga` incorpora la carga de dimensiones de `OpinionesClientesDW` con ADO.NET y procedimientos almacenados.

## Ejecutar la carga de dimensiones

1. Usa la misma instancia de SQL Server que en las prácticas anteriores. Debe contener `OpinionesClientesDB` con sus catálogos y opiniones ya validados. El usuario necesita leer esas tablas y desplegar los objetos en el DW. La aplicación se conecta con la cuenta que tenga acceso a ambas bases.
2. En SSMS abre y ejecuta completo (F5) `SQL/01_crear_OpinionesClientesDW.sql`. Es el script del modelo estrella. Después ejecuta `SQL/02_procedimientos_dimensiones.sql` para instalar los procedimientos y el catálogo de entrada `stg.Eventos`.
3. En una terminal PowerShell, desde la carpeta de la solución, ejecuta los comandos siguientes. Ajusta el nombre del servidor al de tu instancia local.

```powershell
$env:ConnectionStrings__OpinionesClientesDW = 'Server=localhost\SQLEXPRESS;Database=OpinionesClientesDW;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;'
dotnet build .\Opiniones.Actividad1.sln
dotnet run --project .\Opiniones.Carga --no-build
```

4. Consulta las seis filas del resumen. Cada una muestra las inserciones, las actualizaciones y el total de la tabla al confirmar la transacción. Repite el último comando con el origen sin cambios para verificar cero inserciones y actualizaciones.
5. Abre `SQL/03_verificar_dimensiones.sql` en SSMS. El bloque A compara los tamaños y cuenta los hechos. B y C muestran registros. D cuenta claves de origen sin correspondencia. El catálogo del DW incorpora el estado adicional `Pendiente`.

## Origen de los datos

| Dimensión | Fuente |
| --- | --- |
| DimCliente | Clientes de la base transaccional. País, grupo de edad y tipo de cliente admiten NULL. |
| DimProducto | Productos y Categorias. Se conserva el identificador del producto. |
| DimFuente | FuenteDatos. En este proyecto CSV corresponde a Encuesta, Web a ResenaWeb y Red Social a RedSocial. |
| DimFecha | Días distintos de las opiniones aceptadas en la tabla transaccional Opiniones. |
| DimClasificacion | Catálogo fijo del modelo. El origen se valida por nombre y Pendiente tiene la clave 4. |
| DimEvento | Eventos verificados registrados en OpinionesClientesDW.stg.Eventos. Los archivos de la práctica no traen un catálogo de campañas. |

Los identificadores del staging JSONL de la extracción pueden carecer de correspondencia en los catálogos. Por eso la carga usa los registros consolidados en SQL Server. Se ejecuta de forma independiente de la API y del Worker de extracción. Las modificaciones descriptivas se aplican a la fila existente (tipo 1). Una excepción durante la carga revierte la transacción completa.
