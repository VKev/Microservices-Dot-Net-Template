using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MassTransit;
using SharedLibrary.Contracts.UserCreating;

namespace Application.Sagas
{
    public class UserCreatingSaga : MassTransitStateMachine<UserCreatingSagaData>
    {
        public State GuestCreating { get; set; } = null!;
        public State Completed { get; set; } = null!;
        public State Failed { get; set; } = null!;


        public Event<UserCreatingSagaStart> userCreated { get; set; } = null!;
        public Event<GuestCreatedEvent> GuestCreated { get; set; } = null!;
        public Event<GuestCreatedFailureEvent> GuestCreatedFailed { get; set; } = null!;

        public UserCreatingSaga()
        {
            InstanceState(x => x.CurrentState);

            Event(() => userCreated, e => e.CorrelateById(m => m.Message.CorrelationId));
            Event(() => GuestCreated, e => e.CorrelateById(m => m.Message.CorrelationId));
            Event(() => GuestCreatedFailed, e => e.CorrelateById(m => m.Message.CorrelationId));

            Initially(
                When(userCreated)
                .TransitionTo(GuestCreating)
                .ThenAsync(async context =>
                {
                    context.Saga.CorrelationId = context.Message.CorrelationId;
                    context.Saga.UserCreated = true;

                    await context.Publish(new UserCreatedEvent
                    {
                        CorrelationId = context.Message.CorrelationId,
                        Name = context.Message.Name,
                        Email = context.Message.Email
                    });
                })
            );

            During(GuestCreating,
                When(GuestCreated)
                    .Then(context =>
                    {
                        context.Saga.GuestCreated = true;
                    })
                    .TransitionTo(Completed),

                When(GuestCreatedFailed)
                    .Then(context =>
                    {
                        Console.WriteLine($"Guest creation failed: {context.Message.Reason}");
                    })
                    .TransitionTo(Failed)
            );

            During(Completed,
                When(GuestCreated)
                    .Then(context =>
                    {
                        // Ignore duplicate GuestCreated events after completion (e.g., redeliveries)
                    }),
                When(GuestCreatedFailed)
                    .Then(context =>
                    {
                        // Ignore late failure messages once the saga is already completed
                    }));

            SetCompletedWhenFinalized();
        }
    }
}
