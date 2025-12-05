using System;
using SharedLibrary.Configs;
using Microsoft.Extensions.DependencyInjection;
using Domain.Repositories;
using Infrastructure.Repositories;
using Infrastructure.Common;
using MassTransit;
using Application.Consumers;
using Application.Abstractions.Data;

namespace Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructure(this IServiceCollection services)
        {

            services.AddScoped<IGuestRepository, GuestRepository>();
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
            services.AddSingleton<EnvironmentConfig>();
            services.AddMassTransit(busConfigurator =>
            {
                busConfigurator.SetKebabCaseEndpointNameFormatter();
                busConfigurator.AddConsumer<UserCreatedConsumer>();
                busConfigurator.UsingRabbitMq((context, cfg) =>
                {
                    var env = context.GetRequiredService<EnvironmentConfig>();

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
