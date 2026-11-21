using System.Diagnostics;
using System.Text.Json;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Opiniones.Extraccion;

public sealed class Worker(
    IEnumerable<IExtractor> extractores, AjustesExtraccion ajustes,
    IHostApplicationLifetime ciclo, ILogger<Worker> logger) : BackgroundService
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await Task.Yield();
        var inicio = DateTimeOffset.UtcNow;
        var id = $"{inicio:yyyyMMdd_HHmmss}_{Guid.NewGuid():N}";
        var temporal = Path.Combine(ajustes.Staging, $".{id}.tmp");
        var destino = Path.Combine(ajustes.Staging, id);
        var reloj = Stopwatch.StartNew();

        try
        {
            Directory.CreateDirectory(temporal);
            var resultados = await Task.WhenAll(extractores.Select(e => ExtraerAsync(e, temporal, ct)));
            await using (var manifiesto = File.Create(Path.Combine(temporal, "resumen.json")))
            {
                await JsonSerializer.SerializeAsync(manifiesto,
                    new { inicio, totalFilas = resultados.Sum(r => r.Filas), milisegundos = reloj.ElapsedMilliseconds, fuentes = resultados },
                    new JsonSerializerOptions(Json) { WriteIndented = true }, ct);
            }
            ct.ThrowIfCancellationRequested();
            Directory.Move(temporal, destino);
            logger.LogInformation("Extracción completa en {Milisegundos} ms. Staging: {Carpeta}.",
                reloj.ElapsedMilliseconds, destino);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            Environment.ExitCode = 2;
            logger.LogWarning("Extracción cancelada.");
        }
        catch (Exception ex)
        {
            Environment.ExitCode = 1;
            logger.LogError("La extracción no se completó. Tipo: {TipoError}.", ex.GetType().Name);
        }
        finally
        {
            try
            {
                if (Directory.Exists(temporal)) Directory.Delete(temporal, recursive: true);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                logger.LogWarning("No se pudo limpiar la carpeta temporal de la ejecución {Ejecucion}.", id);
            }
            ciclo.StopApplication();
        }
    }

    private async Task<ResultadoFuente> ExtraerAsync(IExtractor extractor, string carpeta, CancellationToken ct)
    {
        var reloj = Stopwatch.StartNew();
        long filas = 0;
        try
        {
            await using var archivo = new FileStream(Path.Combine(carpeta, $"{extractor.Nombre}.jsonl"),
                FileMode.CreateNew, FileAccess.Write, FileShare.None, 65536, useAsync: true);
            await using var escritor = new StreamWriter(archivo);
            await foreach (var fila in extractor.LeerAsync(ct))
            {
                await escritor.WriteLineAsync(JsonSerializer.Serialize(fila, Json).AsMemory(), ct);
                filas++;
            }
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            logger.LogError("Falló {Fuente} tras {Filas} filas. Tipo: {TipoError}.",
                extractor.Nombre, filas, ex.GetType().Name);
            throw;
        }

        if (filas == 0) logger.LogWarning("{Fuente} respondió correctamente, con cero filas.", extractor.Nombre);
        logger.LogInformation("{Fuente}: {Filas} filas en {Milisegundos} ms.",
            extractor.Nombre, filas, reloj.ElapsedMilliseconds);
        return new ResultadoFuente(extractor.Nombre, filas, reloj.ElapsedMilliseconds);
    }

    private sealed record ResultadoFuente(string Fuente, long Filas, long Milisegundos);
}
