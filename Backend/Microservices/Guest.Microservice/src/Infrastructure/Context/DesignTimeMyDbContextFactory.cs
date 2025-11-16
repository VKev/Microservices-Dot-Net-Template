using System;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace Infrastructure.Context
{
    public class DesignTimeMyDbContextFactory : IDesignTimeDbContextFactory<MyDbContext>
    {
        public MyDbContext CreateDbContext(string[] args)
        {
            string? connectionString = null;
            foreach (var arg in args)
            {
                const string prefix = "--connection-string=";
                if (arg.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                {
                    connectionString = arg.Substring(prefix.Length).Trim('"');
                    break;
                }
            }

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            var config = new ConfigurationBuilder()
                .AddEnvironmentVariables()
                .Build();

            var host = config["Database:Host"] ?? config["DATABASE__HOST"] ?? config["DATABASE_HOST"] ?? "localhost";
            var port = config["Database:Port"] ?? config["DATABASE__PORT"] ?? config["DATABASE_PORT"] ?? "5432";
            var database = config["Database:Name"] ?? config["DATABASE__NAME"] ?? config["DATABASE_NAME"] ?? "guestservice_db";
            var username = config["Database:Username"] ?? config["DATABASE__USERNAME"] ?? config["DATABASE_USERNAME"] ?? "postgres";
            var password = config["Database:Password"] ?? config["DATABASE__PASSWORD"] ?? config["DATABASE_PASSWORD"] ?? "password";
            var sslMode = config["Database:SslMode"] ?? config["DATABASE__SSLMODE"] ?? config["DATABASE_SSLMODE"] ?? "Prefer";
            connectionString = $"Host={host};Port={port};Database={database};Username={username};Password={password};SslMode={sslMode}";
        }

            var optionsBuilder = new DbContextOptionsBuilder<MyDbContext>();
            optionsBuilder.UseNpgsql(connectionString!);
            return new MyDbContext(optionsBuilder.Options);
        }
    }
}
