using System;
using SharedLibrary.Configs;
using Microsoft.Extensions.DependencyInjection;
using Domain.Repositories;
using Infrastructure.Repositories;
using Infrastructure.Common;
using MassTransit;
using Application.Sagas;
using Application.Consumers;
using Application.Abstractions.Data;

namespace Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructure(this IServiceCollection services)
        {

            
            services.AddScoped<IUserRepository, UserRepository>();
            services.AddScoped<IRoleRepository, RoleRepository>();
            services.AddScoped<IUserRoleRepository, UserRoleRepository>();
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
            services.AddSingleton<EnvironmentConfig>();

            using var provider = services.BuildServiceProvider();
            var env = provider.GetRequiredService<EnvironmentConfig>();
            var redisConnection = $"{env.RedisHost}:{env.RedisPort},password={env.RedisPassword}";

            services.AddMassTransit(busConfigurator =>
            {
                busConfigurator.SetKebabCaseEndpointNameFormatter();
                busConfigurator.AddConsumer<GuestCreatedConsumer>();

                busConfigurator.AddSagaStateMachine<UserCreatingSaga, UserCreatingSagaData>()
                    .RedisRepository(r =>
                    {
                        r.DatabaseConfiguration(redisConnection);
                        r.KeyPrefix = "user-creating-saga";
                        r.Expiry = TimeSpan.FromMinutes(10);
                    });

                busConfigurator.UsingRabbitMq((context, cfg) =>
                {
                    if (env.IsRabbitMqCloud)
                    {
                        cfg.Host(env.RabbitMqUrl);
                    }
                    else
                    {
                        cfg.Host(new Uri($"rabbitmq://{env.RabbitMqHost}:{env.RabbitMqPort}/"), h =>
                        {
                            h.Username(env.RabbitMqUser);
                            h.Password(env.RabbitMqPassword);
                        });
                    }

                    cfg.ConfigureEndpoints(context);
                });
            });
            return services;
        }
    }
}
