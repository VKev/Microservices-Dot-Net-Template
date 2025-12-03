using Application;
using Infrastructure;
using Infrastructure.Context;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models; // Needed for JWT in Swagger
using Serilog;
using SharedLibrary.Configs;
using SharedLibrary.Middleware;
using SharedLibrary.Migrations;
using SharedLibrary.Utils;
using System;
using System.IO;
using System.Linq;
using Serilog.Events;

var builder = WebApplication.CreateBuilder(args);
// Allow automatic EF Core migrations when enabled via env
const string AutoApplyMigrationsEnvVar = "AutoApply__Migrations";
var autoApplySetting = builder.Configuration["AutoApply:Migrations"]
                        ?? builder.Configuration[AutoApplyMigrationsEnvVar];
var shouldAutoApplyMigrations = bool.TryParse(autoApplySetting, out var parsedAutoApply) && parsedAutoApply;

if (!shouldAutoApplyMigrations)
{
    builder.Services.Replace(ServiceDescriptor.Scoped<IMigrator, NoOpMigrator>());
}

var environment = builder.Environment;
const string CorsPolicyName = "AllowFrontend";
var configuredOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();
var allowedCorsOrigins = (configuredOrigins ?? Array.Empty<string>())
    .Where(origin => !string.IsNullOrWhiteSpace(origin))
    .Distinct(StringComparer.OrdinalIgnoreCase)
    .ToArray();

if (allowedCorsOrigins.Length == 0)
{
    allowedCorsOrigins = new[] { "http://localhost:5173" };
}

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Configure forwarded headers for CloudFront/ALB support
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                               ForwardedHeaders.XForwardedProto |
                               ForwardedHeaders.XForwardedHost;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicyName, policy =>
    {
        policy
            .WithOrigins(allowedCorsOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

// --- Swagger with JWT "Authorize" button ---
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "User API",
        Version = "v1"
    });

    // Add the JWT bearer definition so Swagger UI shows the "Authorize" button
    var jwtSecurityScheme = new OpenApiSecurityScheme
    {
        Scheme = "bearer",
        BearerFormat = "JWT",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Description = "Put **_ONLY_** your JWT token here (no need to type 'Bearer ').",
        Reference = new OpenApiReference
        {
            Id = "Bearer",
            Type = ReferenceType.SecurityScheme
        }
    };

    c.AddSecurityDefinition(jwtSecurityScheme.Reference.Id, jwtSecurityScheme);

    // Apply the bearer auth globally to all operations.
    // (If you want to require it only on [Authorize] endpoints, add an IOperationFilter that checks attributes.)
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { jwtSecurityScheme, Array.Empty<string>() }
    });
});

builder.Services.AddAuthorization();

builder.Host.UseSerilog((hostingContext, loggerConfiguration) =>
    loggerConfiguration
        .MinimumLevel.Information()
        .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
        .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
        .MinimumLevel.Override("Microsoft.EntityFrameworkCore.Database.Command", LogEventLevel.Warning)
        .ReadFrom.Configuration(hostingContext.Configuration)
        .Enrich.FromLogContext()
        .WriteTo.Console());

builder.Services.ConfigureOptions<DatabaseConfigSetup>();
builder.Services.AddDbContext<MyDbContext>((serviceProvider, options) =>
{
    var databaseConfig = serviceProvider.GetRequiredService<IOptions<DatabaseConfig>>().Value;
    options.UseNpgsql(databaseConfig.ConnectionString, actions =>
    {
        actions.EnableRetryOnFailure(databaseConfig.MaxRetryCount);
        actions.CommandTimeout(databaseConfig.CommandTimeout);
    });

    if (environment.IsDevelopment())
    {
        options.EnableDetailedErrors(databaseConfig.EnableDetailedErrors);
        options.EnableSensitiveDataLogging(databaseConfig.EnableSensitiveDataLogging);
    }
});

builder.Services
    .AddApplication()
    .AddInfrastructure();

var app = builder.Build();
if (shouldAutoApplyMigrations)
{
    using var scope = app.Services.CreateScope();
    try
    {
        var dbContext = scope.ServiceProvider.GetRequiredService<MyDbContext>();
        var pending = dbContext.Database.GetPendingMigrations().ToList();
        if (pending.Count > 0)
        {
            app.Logger.LogInformation("Applying {Count} pending EF Core migrations: {Migrations}", pending.Count, string.Join(", ", pending));
            dbContext.Database.Migrate();
            app.Logger.LogInformation("EF Core migrations applied successfully at startup.");
        }
        else
        {
            app.Logger.LogInformation("No pending EF Core migrations detected; skipping apply.");
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Failed to apply EF Core migrations at startup. Continuing without applying migrations.");
    }
}
else
{
    app.Logger.LogInformation("EF Core migrations skipped (set {EnvVar}=true to enable).", AutoApplyMigrationsEnvVar);
}
// Health check endpoints
app.MapGet("/health", () => new { status = "ok" });
app.MapGet("/api/health", () => new { status = "ok" });

// Debug endpoint to check headers
app.MapGet("/debug/headers", (HttpContext context) =>
{
    var headers = context.Request.Headers
        .ToDictionary(h => h.Key, h => h.Value.ToString());
    return Results.Ok(new
    {
        headers,
        scheme = context.Request.Scheme,
        host = context.Request.Host.ToString(),
        path = context.Request.Path.ToString()
    });
});

// ---------- middleware order matters ----------

// 1) Forwarded headers FIRST
app.UseForwardedHeaders();

// 2) Respect CloudFront viewer scheme (HTTPS at the edge)
app.Use((ctx, next) =>
{
    var cfProto = ctx.Request.Headers["CloudFront-Forwarded-Proto"].ToString();
    if (string.Equals(cfProto, "https", StringComparison.OrdinalIgnoreCase))
    {
        ctx.Request.Scheme = "https";
        ctx.Request.IsHttps = true;
    }
    return next();
});

// 3) Logging
app.UseSerilogRequestLogging();

// 4) Only redirect to HTTPS if scheme is already corrected by step #2
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// 5) CORS
app.UseCors(CorsPolicyName);

// 6) Swagger (server URL patched via PreSerialize)
app.UseSwagger(c =>
{
    c.PreSerializeFilters.Add((swagger, httpReq) =>
    {
        var proto = httpReq.Headers["CloudFront-Forwarded-Proto"].FirstOrDefault()
                    ?? httpReq.Headers["X-Forwarded-Proto"].FirstOrDefault();

        if (string.IsNullOrWhiteSpace(proto))
        {
            var cfVisitor = httpReq.Headers["CF-Visitor"].FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(cfVisitor))
            {
                var schemeVal = cfVisitor.Split('"').FirstOrDefault(s => s.Equals("https", StringComparison.OrdinalIgnoreCase));
                if (!string.IsNullOrWhiteSpace(schemeVal))
                {
                    proto = schemeVal;
                }
            }
        }

        proto ??= httpReq.Scheme;

        var host = httpReq.Headers["Host"].FirstOrDefault()
                   ?? httpReq.Host.Value;

        if (!string.IsNullOrEmpty(proto) && !string.IsNullOrEmpty(host))
        {
            swagger.Servers = new List<OpenApiServer>
            {
                new OpenApiServer { Url = $"{proto}://{host}" }
            };
        }
    });
});

app.UseSwaggerUI(c =>
{
    // Relative path is safer behind proxies/CDNs
    c.SwaggerEndpoint("./v1/swagger.json", "User API V1");
    c.RoutePrefix = "swagger";
});

if (app.Environment.IsDevelopment())
{
    app.MapGet("/", context =>
    {
        context.Response.Redirect("/swagger");
        return Task.CompletedTask;
    });
}

// 7) Auth pipeline
app.UseRouting();
app.UseMiddleware<JwtMiddleware>();
app.UseAuthorization();
app.MapControllers();

// Log startup information
var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("User microservice started on port {Port}",
    builder.Configuration["ASPNETCORE_URLS"] ?? "5002");

app.Run();
