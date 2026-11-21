using System.Data;
using System.Runtime.CompilerServices;
using Microsoft.Data.SqlClient;

namespace Opiniones.Fuentes;

public sealed record OpinionOrigen(
    long IdOpinion, string IdRegistroOrigen, int? IdCliente, int IdProducto,
    string IdFuente, string TipoFuente, string? Canal, DateTime Fecha,
    string Comentario, string? Clasificacion, byte? PuntajeSatisfaccion);

public sealed record PaginaComentarios(List<OpinionOrigen> Comentarios, long? SiguienteCursor);

public sealed class RepositorioOpiniones(string conexion)
{
    private const string Seleccion = """
        SELECT TOP (@Limite) o.IdOpinion, o.IdRegistroOrigen, o.IdCliente, o.IdProducto,
               o.IdFuente, f.TipoFuente, f.Canal, o.Fecha, o.Comentario,
               c.Nombre, o.PuntajeSatisfaccion
        FROM dbo.Opiniones AS o
        INNER JOIN dbo.FuenteDatos AS f ON f.IdFuente = o.IdFuente
        LEFT JOIN dbo.Clasificaciones AS c ON c.IdClasificacion = o.IdClasificacion
        WHERE o.IdOpinion > @Cursor AND
        """;

    public IAsyncEnumerable<OpinionOrigen> LeerResenasAsync(CancellationToken ct) =>
        LeerAsync("o.IdFuente = 'RESENAS_WEB'", 0, int.MaxValue, ct);

    public IAsyncEnumerable<OpinionOrigen> LeerComentariosAsync(long cursor, int limite, CancellationToken ct) =>
        LeerAsync("f.TipoFuente = N'Red Social'", cursor, limite, ct);

    private async IAsyncEnumerable<OpinionOrigen> LeerAsync(
        string filtro, long cursor, int limite, [EnumeratorCancellation] CancellationToken ct)
    {
        await using var cn = new SqlConnection(conexion);
        await cn.OpenAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = $"{Seleccion} ({filtro}) ORDER BY o.IdOpinion;";
        cmd.Parameters.Add("@Cursor", SqlDbType.BigInt).Value = cursor;
        cmd.Parameters.Add("@Limite", SqlDbType.Int).Value = limite;
        await using var filas = await cmd.ExecuteReaderAsync(ct);
        while (await filas.ReadAsync(ct))
        {
            yield return new OpinionOrigen(
                filas.GetInt64(0), filas.GetString(1), filas.IsDBNull(2) ? null : filas.GetInt32(2),
                filas.GetInt32(3), filas.GetString(4), filas.GetString(5),
                filas.IsDBNull(6) ? null : filas.GetString(6), filas.GetDateTime(7), filas.GetString(8),
                filas.IsDBNull(9) ? null : filas.GetString(9), filas.IsDBNull(10) ? null : filas.GetByte(10));
        }
    }
}
