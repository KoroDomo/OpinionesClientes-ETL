using System.Data;
using Microsoft.Data.SqlClient;

namespace Opiniones.Fuentes;

public sealed record ResultadoDimension(string Dimension, long Insertadas, long Actualizadas, long Total);

public sealed class CargadorDimensiones(string conexion)
{
    public async Task<List<ResultadoDimension>> EjecutarAsync()
    {
        await using var cn = new SqlConnection(conexion);
        await cn.OpenAsync();
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = "dbo.usp_CargarDimensiones";
        cmd.CommandType = CommandType.StoredProcedure;
        cmd.CommandTimeout = 180;
        await using var lector = await cmd.ExecuteReaderAsync();
        var resultados = new List<ResultadoDimension>();
        while (await lector.ReadAsync())
            resultados.Add(new(lector.GetString(0), lector.GetInt64(1), lector.GetInt64(2), lector.GetInt64(3)));
        return resultados;
    }
}
