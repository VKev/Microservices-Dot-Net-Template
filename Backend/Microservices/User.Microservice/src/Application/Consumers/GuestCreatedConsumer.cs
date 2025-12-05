using System.Threading.Tasks;
using Application.Users.Commands;
using Domain.Repositories;
using MassTransit;
using MediatR;
using SharedLibrary.Contracts.UserCreating;

namespace Application.Consumers
{
    public class GuestCreatedConsumer : IConsumer<GuestCreatedEvent>
    {
        private readonly IMediator _mediator;
        private readonly IUserRepository _userRepository;

        public GuestCreatedConsumer(IMediator mediator, IUserRepository userRepository)
        {
            _mediator = mediator;
            _userRepository = userRepository;
        }

        public async Task Consume(ConsumeContext<GuestCreatedEvent> context)
        {
            var message = context.Message;

            // If user already exists (e.g., created via another flow), consider it a success
            var existingUser = await _userRepository.GetByEmailAsync(message.Email, context.CancellationToken);
            if (existingUser != null)
            {
                await context.Publish(new GuestCreatedEvent
                {
                    CorrelationId = message.CorrelationId,
                    Name = existingUser.Name,
                    Email = existingUser.Email,
                    Password = message.Password,
                    ProviderName = message.ProviderName,
                    ProviderUserId = message.ProviderUserId,
                    DateOfBirth = message.DateOfBirth,
                    Gender = message.Gender,
                    PhoneNumber = message.PhoneNumber
                }, context.CancellationToken);
                return;
            }

            var registerResult = await _mediator.Send(new RegisterUserCommand(
                message.Name,
                message.Email,
                message.Password,
                message.ProviderName,
                message.ProviderUserId,
                message.DateOfBirth,
                message.Gender,
                message.PhoneNumber), context.CancellationToken);

            if (registerResult.IsFailure)
            {
                await context.Publish(new GuestCreatedFailureEvent
                {
                    CorrelationId = message.CorrelationId,
                    Reason = registerResult.Error.Description
                }, context.CancellationToken);
                return;
            }
        }
    }
}
