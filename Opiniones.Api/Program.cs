using System.Security.Cryptography;
using System.Text;
using Opiniones.Fuentes;

var builder = WebApplication.CreateBuilder(args);
var conexion = builder.Configuration.GetConnectionString("OpinionesClientesDB");
var token = builder.Configuration["Api:Token"];

if (string.IsNullOrWhiteSpace(conexion))
    throw new InvalidOperationException("Configura ConnectionStrings__OpinionesClientesDB.");
if (string.IsNullOrWhiteSpace(token))
    throw new InvalidOperationException("Configura Api__Token.");

var tokenHash = SHA256.HashData(Encoding.UTF8.GetBytes(token));
builder.Services.AddSingleton(new RepositorioOpiniones(conexion));
var app = builder.Build();

app.MapGet("/api/comentarios", async (
    HttpRequest solicitud, long? despuesDe, int? limite, RepositorioOpiniones repo, CancellationToken ct) =>
{
    var autorizacion = solicitud.Headers.Authorization.ToString();
    if (!autorizacion.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ||
        !CryptographicOperations.FixedTimeEquals(
            tokenHash, SHA256.HashData(Encoding.UTF8.GetBytes(autorizacion[7..]))))
        return Results.Unauthorized();

    var cursor = despuesDe ?? 0;
    var cantidad = limite ?? 500;
    if (cursor < 0 || cantidad is < 1 or > 1000)
        return Results.BadRequest("El cursor debe ser no negativo y el límite debe estar entre 1 y 1000.");

    try
    {
        var datos = new List<OpinionOrigen>(cantidad + 1);
        await foreach (var registro in repo.LeerComentariosAsync(cursor, cantidad + 1, ct))
            datos.Add(registro);

        long? siguiente = null;
        if (datos.Count > cantidad)
        {
            datos.RemoveAt(cantidad);
            siguiente = datos[^1].IdOpinion;
        }
        return Results.Ok(new PaginaComentarios(datos, siguiente));
    }
    catch (Exception ex) when (!ct.IsCancellationRequested)
    {
        app.Logger.LogError("Error consultando comentarios. Tipo: {TipoError}.", ex.GetType().Name);
        return Results.Problem("No se pudo consultar la base de datos.");
    }
});

await app.RunAsync();
