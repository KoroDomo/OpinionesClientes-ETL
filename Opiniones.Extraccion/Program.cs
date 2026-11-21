using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Opiniones.Extraccion;
using Opiniones.Fuentes;

Console.OutputEncoding = Encoding.UTF8;
var builder = Host.CreateApplicationBuilder(new HostApplicationBuilderSettings
{
    Args = args,
    ContentRootPath = AppContext.BaseDirectory
});
var config = builder.Configuration;
var conexion = config.GetConnectionString("OpinionesClientesDB");
if (string.IsNullOrWhiteSpace(conexion))
    throw new InvalidOperationException("Configura ConnectionStrings__OpinionesClientesDB.");

if (!Uri.TryCreate(config["Api:Url"], UriKind.Absolute, out var apiUrl) ||
    (apiUrl.Scheme != Uri.UriSchemeHttps && !(apiUrl.IsLoopback && apiUrl.Scheme == Uri.UriSchemeHttp)) ||
    !string.IsNullOrEmpty(apiUrl.UserInfo) || !apiUrl.AbsoluteUri.EndsWith('/'))
    throw new InvalidOperationException("Configura Api__Url con HTTPS o HTTP local y una barra final.");

var token = config["Api:Token"];
if (string.IsNullOrWhiteSpace(token))
    throw new InvalidOperationException("Configura Api__Token.");

builder.Services.AddSingleton(new RepositorioOpiniones(conexion));
builder.Services.AddSingleton(new AjustesExtraccion(
    config["Extraccion:Csv"] ?? "Datos/surveys_part1.csv",
    config["Extraccion:Staging"] ?? "Staging",
    token,
    Math.Clamp(config.GetValue("Api:TamanoPagina", 500), 1, 1000)));
builder.Services.AddHttpClient("Comentarios", c => c.BaseAddress = apiUrl)
    .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
builder.Services.AddSingleton<IExtractor, CsvExtractor>();
builder.Services.AddSingleton<IExtractor, DatabaseExtractor>();
builder.Services.AddSingleton<IExtractor, ApiExtractor>();
builder.Services.AddHostedService<Worker>();
await builder.Build().RunAsync();
