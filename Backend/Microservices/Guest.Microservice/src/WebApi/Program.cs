using Application;
using Infrastructure;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models;
using Serilog;
using SharedLibrary.Configs;
using SharedLibrary.Middleware;
using SharedLibrary.Migrations;

var solutionDirectory = Directory.GetParent(Directory.GetCurrentDirectory())?.FullName ?? "";
if (!string.IsNullOrWhiteSpace(solutionDirectory))
{
    DotNetEnv.Env.Load(Path.Combine(solutionDirectory, ".env"));
}

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

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Guest API",
        Version = "v1"
    });

    var jwtSecurityScheme = new OpenApiSecurityScheme
    {
        Scheme = "bearer",
        BearerFormat = "JWT",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Description = "Paste your JWT token here (no need to type 'Bearer ').",
        Reference = new OpenApiReference
        {
            Id = "Bearer",
            Type = ReferenceType.SecurityScheme
        }
    };

    c.AddSecurityDefinition(jwtSecurityScheme.Reference.Id, jwtSecurityScheme);

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { jwtSecurityScheme, Array.Empty<string>() }
    });

});

builder.Services.AddAuthorization();

builder.Host.UseSerilog((hostingContext, loggerConfiguration) =>
    loggerConfiguration
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

app.MapGet("/health", () => new { status = "ok" });
app.MapGet("/api/health", () => new { status = "ok" });

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Guest API V1");
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

app.UseSerilogRequestLogging();

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseMiddleware<JwtMiddleware>();

app.UseAuthorization();

app.MapControllers();

var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("Guest microservice started on port {Port}",
    builder.Configuration["ASPNETCORE_URLS"] ?? "5001");

app.Run();
