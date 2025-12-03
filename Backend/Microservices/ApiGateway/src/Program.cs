using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MMLib.SwaggerForOcelot.DependencyInjection;
using Ocelot.DependencyInjection;
using Ocelot.Middleware;
using SharedLibrary.Authentication;
using SharedLibrary.Middleware;
using Microsoft.AspNetCore.HttpOverrides;

DotNetEnv.Env.Load();

var builder = WebApplication.CreateBuilder(args);
var configuration = builder.Configuration;

// Configure Kestrel to handle large multipart/form-data uploads
builder.Services.Configure<Microsoft.AspNetCore.Server.Kestrel.Core.KestrelServerOptions>(options =>
{
    options.Limits.MaxRequestBodySize = 104857600; // 100 MB
});

builder.Services.Configure<Microsoft.AspNetCore.Http.Features.FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = 104857600; // 100 MB
    options.ValueLengthLimit = 104857600;
    options.MultipartHeadersLengthLimit = 104857600;
});

var runningInContainer = configuration.GetValue<bool>("DOTNET_RUNNING_IN_CONTAINER");

string ResolveHost(string? envHost, string containerDefault)
{
    if (!string.IsNullOrWhiteSpace(envHost))
    {
        return envHost;
    }

    return runningInContainer ? containerDefault : "localhost";
}

const string CorsPolicyName = "AllowFrontend";
var configuredOrigins = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();
var allowedCorsOrigins = (configuredOrigins ?? Array.Empty<string>())
    .Select(origin => origin?.Trim())
    .Where(origin => !string.IsNullOrWhiteSpace(origin))
    .Select(origin => origin!) // filter above ensures non-null
    .Distinct(StringComparer.OrdinalIgnoreCase)
    .ToArray();

if (allowedCorsOrigins.Length == 0)
{
    allowedCorsOrigins = new[] { "http://localhost:5173" };
}

bool allowAnyLoopback = allowedCorsOrigins.Any(origin =>
{
    if (Uri.TryCreate(origin, UriKind.Absolute, out var uri))
    {
        return uri.IsLoopback;
    }

    var lowered = origin.ToLowerInvariant();
    return lowered.Contains("localhost") || lowered.Contains("127.0.0.1") || lowered.Contains("::1");
});

var explicitExternalOrigins = new HashSet<string>(
    allowedCorsOrigins.Where(origin =>
        Uri.TryCreate(origin, UriKind.Absolute, out var uri) && !uri.IsLoopback),
    StringComparer.OrdinalIgnoreCase);

string GetHostForPrefix(string prefix, string serviceSegment, string containerDefault)
{
    return ResolveHost(
        configuration[$"{prefix}_MICROSERVICE_HOST"]
        ?? configuration[$"Services:{serviceSegment}:Host"]
        ?? configuration[$"Services__{serviceSegment}__Host"],
        containerDefault);
}

string? GetPortForPrefix(string prefix, string serviceSegment)
{
    return configuration[$"{prefix}_MICROSERVICE_PORT"]
           ?? configuration[$"Services:{serviceSegment}:Port"]
           ?? configuration[$"Services__{serviceSegment}__Port"];
}

builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicyName, policy =>
    {
        policy
            .SetIsOriginAllowed(origin =>
            {
                if (explicitExternalOrigins.Contains(origin))
                {
                    return true;
                }

                if (!allowAnyLoopback)
                {
                    return false;
                }

                return Uri.TryCreate(origin, UriKind.Absolute, out var uri) && uri.IsLoopback;
            })
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                               ForwardedHeaders.XForwardedProto |
                               ForwardedHeaders.XForwardedHost;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var routes = new JsonArray();

string ToServiceSegment(string prefix)
{
    var lower = prefix.ToLowerInvariant();
    var parts = lower.Split(new[] { '_', '-' }, StringSplitOptions.RemoveEmptyEntries);
    return string.Concat(parts.Select(p => char.ToUpperInvariant(p[0]) + p.Substring(1)));
}

void AddRoute(string prefix, string serviceSegment, string host, int port)
{
    var swaggerKey = prefix.ToLowerInvariant();

    JsonObject BuildRoute(string upstreamTemplate, string downstreamTemplate, bool includeSwaggerKey)
    {
        var route = new JsonObject
        {
            ["UpstreamPathTemplate"] = upstreamTemplate,
            ["UpstreamHttpMethod"] = new JsonArray("Get", "Post", "Put", "Delete", "Options"),
            ["DownstreamScheme"] = "http",
            ["DownstreamHostAndPorts"] = new JsonArray(new JsonObject
            {
                ["Host"] = host,
                ["Port"] = port
            }),
            ["DownstreamPathTemplate"] = downstreamTemplate
        };

        if (includeSwaggerKey)
        {
            route["SwaggerKey"] = swaggerKey;
        }

        return route;
    }

    // Ensure both root and nested endpoints are forwarded.
    routes.Add(BuildRoute($"/api/{serviceSegment}", $"/api/{serviceSegment}", includeSwaggerKey: false));
    routes.Add(BuildRoute($"/api/{serviceSegment}/{{everything}}", $"/api/{serviceSegment}/{{everything}}", includeSwaggerKey: true));
}

int ResolvePort(string? envPort, int containerDefault, int localDefault)
{
    if (int.TryParse(envPort, out var parsed))
    {
        return parsed;
    }

    return runningInContainer ? containerDefault : localDefault;
}

var defaultServices = new[]
{
    new
    {
        Prefix = "USER",
        Service = "User",
        ContainerHost = "user-microservice",
        ContainerPort = 5002,
        LocalPort = 5002
    },
    new
    {
        Prefix = "GUEST",
        Service = "Guest",
        ContainerHost = "guest-microservice",
        ContainerPort = 5001,
        LocalPort = 5001
    }
};

var addedServices = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (var s in defaultServices)
{
    var host = GetHostForPrefix(s.Prefix, s.Service, s.ContainerHost);
    var port = ResolvePort(GetPortForPrefix(s.Prefix, s.Service), s.ContainerPort, s.LocalPort);

    AddRoute(s.Prefix, s.Service, host, port);
    addedServices.Add(s.Service);
}

var envVars = configuration.AsEnumerable().Where(kv => !string.IsNullOrWhiteSpace(kv.Value));
var prefixes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (var entry in envVars)
{
    var key = entry.Key;
    if (string.IsNullOrEmpty(key)) continue;
    if (key.StartsWith("Services:", StringComparison.OrdinalIgnoreCase))
    {
        var parts = key.Split(':', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 2)
        {
            prefixes.Add(parts[1].ToUpperInvariant());
        }
    }
    if (key.EndsWith("_MICROSERVICE_HOST", StringComparison.OrdinalIgnoreCase))
        prefixes.Add(key[..^"_MICROSERVICE_HOST".Length]);
    else if (key.EndsWith("_MICROSERVICE_PORT", StringComparison.OrdinalIgnoreCase))
        prefixes.Add(key[..^"_MICROSERVICE_PORT".Length]);
}

foreach (var prefix in prefixes)
{
    var serviceSegment = ToServiceSegment(prefix);
    if (addedServices.Contains(serviceSegment)) continue;

    var host = GetHostForPrefix(prefix, serviceSegment, $"{prefix.ToLowerInvariant()}-microservice");
    var port = ResolvePort(GetPortForPrefix(prefix, serviceSegment), 80, 80);

    AddRoute(prefix, serviceSegment, host, port);
    addedServices.Add(serviceSegment);
}

var ocelotConfig = new JsonObject
{
    ["Routes"] = routes,
    ["GlobalConfiguration"] = new JsonObject
    {
        ["BaseUrl"] = configuration["BASE_URL"] ?? "http://localhost:2406"
    }
};

var endpointData = new List<(string Key, string Name, string Url)>();
var addedSwaggerServices = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (var s in defaultServices)
{
    var host = GetHostForPrefix(s.Prefix, s.Service, s.ContainerHost);
    var port = ResolvePort(GetPortForPrefix(s.Prefix, s.Service), s.ContainerPort, s.LocalPort);

    var key = s.Prefix.ToLowerInvariant();
    var name = $"{s.Service} API";
    var url = $"http://{host}:{port}/swagger/v1/swagger.json";

    endpointData.Add((key, name, url));
    addedSwaggerServices.Add(s.Service);
}

foreach (var prefix in prefixes)
{
    var serviceSegment = ToServiceSegment(prefix);
    if (addedSwaggerServices.Contains(serviceSegment)) continue;

    var host = GetHostForPrefix(prefix, serviceSegment, $"{prefix.ToLowerInvariant()}-microservice");
    var port = ResolvePort(GetPortForPrefix(prefix, serviceSegment), 80, 80);

    var key = prefix.ToLowerInvariant();
    var name = $"{serviceSegment} API";
    var url = $"http://{host}:{port}/swagger/v1/swagger.json";

    endpointData.Add((key, name, url));
    addedSwaggerServices.Add(serviceSegment);
}

JsonArray BuildSwaggerEndpoints()
{
    var endpoints = new JsonArray();
    foreach (var (key, name, url) in endpointData)
    {
        endpoints.Add(new JsonObject
        {
            ["Key"] = key,
            ["TransformByOcelotConfig"] = true,
            ["Config"] = new JsonArray(new JsonObject
            {
                ["Name"] = name,
                ["Version"] = "v1",
                ["Url"] = url
            })
        });
    }
    return endpoints;
}

var swaggerConfig = new JsonObject
{
    ["SwaggerForOcelot"] = new JsonObject
    {
        ["SwaggerEndPoints"] = BuildSwaggerEndpoints()
    },
    ["SwaggerEndPoints"] = BuildSwaggerEndpoints()
};

var contentRoot = builder.Environment.ContentRootPath;
var ocelotFileName = "ocelot.runtime.json";
var swaggerFileName = "swagger.runtime.json";
var runtimeConfigPath = Path.Combine(contentRoot, ocelotFileName);
var swaggerConfigPath = Path.Combine(contentRoot, swaggerFileName);

File.WriteAllText(runtimeConfigPath, ocelotConfig.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
File.WriteAllText(swaggerConfigPath, swaggerConfig.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

builder.Configuration
    .SetBasePath(contentRoot)
    .AddJsonFile(ocelotFileName, optional: false, reloadOnChange: true)
    .AddJsonFile(swaggerFileName, optional: false, reloadOnChange: true)
    .AddEnvironmentVariables();

builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerForOcelot(builder.Configuration);
builder.Services.AddOcelot(builder.Configuration);

bool enableSwaggerUi = configuration.GetValue<bool>("ENABLE_SWAGGER_UI");

var app = builder.Build();

app.UseForwardedHeaders();

// Ensure downstream components respect original viewer scheme behind proxies/CDN
app.Use((ctx, next) =>
{
    var protoHeader = ctx.Request.Headers["CloudFront-Forwarded-Proto"].FirstOrDefault()
                      ?? ctx.Request.Headers["X-Forwarded-Proto"].FirstOrDefault();

    var cfVisitor = ctx.Request.Headers["CF-Visitor"].FirstOrDefault();
    if (string.IsNullOrWhiteSpace(protoHeader) && !string.IsNullOrWhiteSpace(cfVisitor))
    {
        // CF-Visitor: {"scheme":"https"}
        var schemeVal = cfVisitor.Split('"').FirstOrDefault(s => s.Equals("https", StringComparison.OrdinalIgnoreCase));
        if (!string.IsNullOrWhiteSpace(schemeVal))
        {
            protoHeader = schemeVal;
        }
    }

    if (!string.IsNullOrWhiteSpace(protoHeader))
    {
        var normalized = protoHeader.Split(',', StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault()
            ?.Trim();

        if (!string.IsNullOrEmpty(normalized))
        {
            ctx.Request.Scheme = normalized;
            ctx.Request.IsHttps = string.Equals(normalized, "https", StringComparison.OrdinalIgnoreCase);
        }
    }

    return next();
});

app.UseCors(CorsPolicyName);

app.Use(async (ctx, next) =>
{
    var p = ctx.Request.Path.Value ?? "";
    if (p.Equals("/health", StringComparison.OrdinalIgnoreCase) ||
        p.Equals("/api/health", StringComparison.OrdinalIgnoreCase))
    {
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(new { status = "ok" }));
        return;
    }
    await next();
});

if (enableSwaggerUi || app.Environment.IsDevelopment())
{
    app.UseSwaggerForOcelotUI(
        ocelotUi =>
        {
            ocelotUi.PathToSwaggerGenerator = "/swagger/docs";
            ocelotUi.ReConfigureUpstreamSwaggerJson = AlterUpstreamSwaggerJson;
        },
        swaggerUi =>
        {
            swaggerUi.RoutePrefix = "swagger";
            swaggerUi.DocumentTitle = "API Gateway - Swagger";
            swaggerUi.ConfigObject.AdditionalItems["persistAuthorization"] = true;
        }
    );
}

app.UseWhen(ctx =>
    !ctx.Request.Path.StartsWithSegments("/swagger") &&
    !ctx.Request.Path.StartsWithSegments("/health") &&
    !ctx.Request.Path.StartsWithSegments("/api/health"),
    branch => branch.UseMiddleware<JwtMiddleware>());

bool uiEnabledNow = enableSwaggerUi || app.Environment.IsDevelopment();

app.Use(async (ctx, next) =>
{
    if (uiEnabledNow && (ctx.Request.Path == "/" || string.IsNullOrEmpty(ctx.Request.Path)))
    {
        ctx.Response.Redirect("/swagger", permanent: false);
        return;
    }
    await next();
});

await app.UseOcelot();
app.Run();

static string AlterUpstreamSwaggerJson(HttpContext context, string swaggerJson)
{
    var swagger = Newtonsoft.Json.JsonConvert.DeserializeObject<Newtonsoft.Json.Linq.JObject>(swaggerJson);
    if (swagger != null)
    {
        var protoHeader = context.Request.Headers["CloudFront-Forwarded-Proto"].FirstOrDefault()
                          ?? context.Request.Headers["X-Forwarded-Proto"].FirstOrDefault();
        var cfVisitor = context.Request.Headers["CF-Visitor"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(protoHeader) && !string.IsNullOrWhiteSpace(cfVisitor))
        {
            var schemeVal = cfVisitor.Split('"').FirstOrDefault(s => s.Equals("https", StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrWhiteSpace(schemeVal))
            {
                protoHeader = schemeVal;
            }
        }
        var scheme = protoHeader?.Split(',', StringSplitOptions.RemoveEmptyEntries)
                        .FirstOrDefault()
                        ?.Trim();
        if (string.IsNullOrEmpty(scheme))
        {
            scheme = context.Request.Scheme;
        }

        var servers = new Newtonsoft.Json.Linq.JArray
        {
            new Newtonsoft.Json.Linq.JObject
            {
                ["url"] = $"{scheme}://{context.Request.Host}"
            }
        };
        swagger["servers"] = servers;
        return swagger.ToString();
    }
    return swaggerJson;
}
