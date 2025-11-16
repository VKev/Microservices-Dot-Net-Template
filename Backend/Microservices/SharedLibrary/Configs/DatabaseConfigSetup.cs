using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Configuration;

namespace SharedLibrary.Configs
{
    public class DatabaseConfigSetup : IConfigureOptions<DatabaseConfig>
    {
        private readonly string ConfigurationSectionName = "DatabaseConfigurations";
        private readonly IConfiguration _configuration;
        private readonly EnvironmentConfig _env;

        public DatabaseConfigSetup(IConfiguration configuration, EnvironmentConfig env)
        {
            _configuration = configuration;
            _env = env;
        }

        public void Configure(DatabaseConfig options)
        {
            var sslMode = _configuration["DATABASE_SSLMODE"] ?? "Prefer";
            options.ConnectionString = $"Host={_env.DatabaseHost};Port={_env.DatabasePort};Database={_env.DatabaseName};Username={_env.DatabaseUser};Password={_env.DatabasePassword};SslMode={sslMode}";

            // Allow optional overrides from configuration section (env or other providers)
            var section = _configuration.GetSection(ConfigurationSectionName);
            options.MaxRetryCount = section.GetValue<int?>("MaxRetryCount") ?? options.MaxRetryCount;
            options.CommandTimeout = section.GetValue<int?>("CommandTimeout") ?? options.CommandTimeout;
            options.EnableDetailedErrors = section.GetValue<bool?>("EnableDetailedErrors") ?? options.EnableDetailedErrors;
            options.EnableSensitiveDataLogging = section.GetValue<bool?>("EnableSensitiveDataLogging") ?? options.EnableSensitiveDataLogging;
        }
    }
} 
