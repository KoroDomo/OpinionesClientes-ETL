using System.Text;
using Microsoft.Data.SqlClient;
using Opiniones.Fuentes;

Console.OutputEncoding = Encoding.UTF8;
var conexion = Environment.GetEnvironmentVariable("ConnectionStrings__OpinionesClientesDW");
if (string.IsNullOrWhiteSpace(conexion))
{
    Console.Error.WriteLine("Define ConnectionStrings__OpinionesClientesDW en esta terminal.");
    return 1;
}

try
{
    var resultados = await new CargadorDimensiones(conexion).EjecutarAsync();
    Console.WriteLine("OpinionesClientesDW | Carga de dimensiones");
    Console.WriteLine($"{"Dimensión",-19} {"Insertadas",10} {"Actualizadas",12} {"Total DW",9}");
    foreach (var fila in resultados)
        Console.WriteLine($"{fila.Dimension,-19} {fila.Insertadas,10} {fila.Actualizadas,12} {fila.Total,9}");

    Console.WriteLine("Transacción confirmada.");
    if (resultados.Any(f => f.Dimension == "DimEvento" && f.Total == 0))
        Console.WriteLine("DimEvento sin filas: no hay eventos en el catálogo de entrada.");
    return 0;
}
catch (Exception ex) when (ex is SqlException or InvalidOperationException or ArgumentException)
{
    Console.Error.WriteLine($"Carga sin confirmar: {ex.Message}");
    return 1;
}
