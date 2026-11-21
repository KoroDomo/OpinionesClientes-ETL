using System.Globalization;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;
using Opiniones.Fuentes;

namespace Opiniones.Extraccion;

public sealed record AjustesExtraccion(string RutaCsv, string Staging, string Token, int TamanoPagina);
public sealed record EncuestaOrigen(
    string IdOpinion, string IdCliente, string IdProducto, string Fecha, string Comentario,
    string Clasificacion, string PuntajeSatisfaccion, string Fuente);

public interface IExtractor
{
    string Nombre { get; }
    IAsyncEnumerable<object> LeerAsync(CancellationToken ct);
}

public sealed class CsvExtractor(AjustesExtraccion ajustes) : IExtractor
{
    public string Nombre => "encuestas";

    public async IAsyncEnumerable<object> LeerAsync([EnumeratorCancellation] CancellationToken ct)
    {
        await using var archivo = new FileStream(ajustes.RutaCsv, FileMode.Open, FileAccess.Read,
            FileShare.Read, 65536, FileOptions.Asynchronous | FileOptions.SequentialScan);
        using var texto = new StreamReader(archivo, new UTF8Encoding(false, true));
        using var csv = new CsvReader(texto, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            Delimiter = ",",
            DetectColumnCountChanges = true,
            ExceptionMessagesContainRawData = false,
            PrepareHeaderForMatch = args => NormalizarCabecera(args.Header)
        });

        await foreach (var fila in csv.GetRecordsAsync<EncuestaOrigen>(ct))
            yield return fila;
    }

    private static string NormalizarCabecera(string valor) => string.Concat(
        valor.Trim().Normalize(NormalizationForm.FormD)
            .Where(c => CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark))
        .ToUpperInvariant();
}

public sealed class DatabaseExtractor(RepositorioOpiniones repositorio) : IExtractor
{
    public string Nombre => "resenas";

    public async IAsyncEnumerable<object> LeerAsync([EnumeratorCancellation] CancellationToken ct)
    {
        await foreach (var fila in repositorio.LeerResenasAsync(ct))
            yield return fila;
    }
}

public sealed class ApiExtractor(IHttpClientFactory http, AjustesExtraccion ajustes) : IExtractor
{
    public string Nombre => "comentarios";

    public async IAsyncEnumerable<object> LeerAsync([EnumeratorCancellation] CancellationToken ct)
    {
        using var cliente = http.CreateClient("Comentarios");
        long cursor = 0;

        while (true)
        {
            using var solicitud = new HttpRequestMessage(HttpMethod.Get,
                FormattableString.Invariant($"api/comentarios?despuesDe={cursor}&limite={ajustes.TamanoPagina}"));
            solicitud.Headers.Authorization = new AuthenticationHeaderValue("Bearer", ajustes.Token);
            using var respuesta = await cliente.SendAsync(solicitud, ct);
            respuesta.EnsureSuccessStatusCode();
            var pagina = await respuesta.Content.ReadFromJsonAsync<PaginaComentarios>(cancellationToken: ct)
                ?? throw new InvalidDataException("La API no devolvió una página de comentarios.");

            var ultimo = cursor;
            foreach (var fila in pagina.Comentarios)
            {
                if (fila.IdOpinion <= ultimo)
                    throw new InvalidDataException("La API devolvió comentarios fuera de orden.");
                ultimo = fila.IdOpinion;
                yield return fila;
            }

            if (pagina.SiguienteCursor is not long siguiente)
                yield break;
            if (siguiente <= cursor || siguiente != ultimo)
                throw new InvalidDataException("La API devolvió un cursor inválido.");
            cursor = siguiente;
        }
    }
}
