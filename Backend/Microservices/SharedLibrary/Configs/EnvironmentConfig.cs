using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

namespace SharedLibrary.Configs
{
    public class EnvironmentConfig
    {
        private readonly IConfiguration _configuration;

        public EnvironmentConfig(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        private string Get(params string[] keys)
        {
            foreach (var key in keys)
            {
                var value = _configuration[key];
                if (!string.IsNullOrWhiteSpace(value))
                {
                    return value;
                }
            }

            return string.Empty;
        }

        private int GetInt(string fallback, params string[] keys)
        {
            foreach (var key in keys)
            {
                var value = _configuration[key];
                if (int.TryParse(value, out var parsed))
                {
                    return parsed;
                }
            }

            return int.TryParse(fallback, out var final) ? final : 0;
        }

        public string DatabaseHost => Get("Database:Host", "DATABASE__HOST", "DATABASE_HOST").DefaultIfEmpty("localhost");
        public int DatabasePort => GetInt("5432", "Database:Port", "DATABASE__PORT", "DATABASE_PORT");
        public string DatabaseName => Get("Database:Name", "DATABASE__NAME", "DATABASE_NAME").DefaultIfEmpty("microservices_db");
        public string DatabaseUser => Get("Database:Username", "DATABASE__USERNAME", "DATABASE_USERNAME").DefaultIfEmpty("postgres");
        public string DatabasePassword => Get("Database:Password", "DATABASE__PASSWORD", "DATABASE_PASSWORD").DefaultIfEmpty("password");
        public string DatabaseProvider => Get("Database:Provider", "DATABASE__PROVIDER", "DATABASE_PROVIDER").DefaultIfEmpty("postgres");
        
        // RabbitMQ Cloud Configuration (priority)
        public string? RabbitMqUrl => Get("RabbitMq:Url", "RABBITMQ__URL", "RABBITMQ_URL").NullIfEmpty();
        
        // RabbitMQ Local Configuration (fallback)
        public string RabbitMqHost => Get("RabbitMq:Host", "RABBITMQ__HOST", "RABBITMQ_HOST").DefaultIfEmpty("rabbit-mq");
        public int RabbitMqPort  => GetInt("5672", "RabbitMq:Port", "RABBITMQ__PORT", "RABBITMQ_PORT");
        public string RabbitMqUser => Get("RabbitMq:Username", "RABBITMQ__USERNAME", "RABBITMQ_USERNAME").DefaultIfEmpty("username");
        public string RabbitMqPassword => Get("RabbitMq:Password", "RABBITMQ__PASSWORD", "RABBITMQ_PASSWORD").DefaultIfEmpty("password");
        
        // Helper property to determine if using cloud RabbitMQ
        public bool IsRabbitMqCloud => !string.IsNullOrEmpty(RabbitMqUrl);

        public string RedisHost => Get("Redis:Host", "REDIS__HOST", "REDIS_HOST").DefaultIfEmpty("redis");
        public string RedisPassword => Get("Redis:Password", "REDIS__PASSWORD", "REDIS_PASSWORD").DefaultIfEmpty("default");
        public int RedisPort => GetInt("6379", "Redis:Port", "REDIS__PORT", "REDIS_PORT");
    }

    internal static class EnvironmentConfigExtensions
    {
        public static string DefaultIfEmpty(this string value, string fallback) =>
            string.IsNullOrWhiteSpace(value) ? fallback : value;

        public static string? NullIfEmpty(this string value) =>
            string.IsNullOrWhiteSpace(value) ? null : value;
    }
}
