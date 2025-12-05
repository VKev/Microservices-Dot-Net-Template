using System;
using System.Collections.Generic;
using SharedLibrary.Common.ResponseModel;
using SharedLibrary.Abstractions.Messaging;
using Application.Common;
using Domain.Entities;
using Domain.Repositories;
using MassTransit;
using SharedLibrary.Contracts.UserCreating;

namespace Application.Guests.Commands
{
    public sealed record CreateGuestCommand(
        string Fullname,
        string Email,
        string? PhoneNumber = null,
        DateTime? DateOfBirth = null,
        string? Gender = null
    ) : ICommand;
    internal sealed class CreateGuestCommandHandler : ICommandHandler<CreateGuestCommand>
    {
        private readonly IGuestRepository _guestRepository;
        private readonly IPublishEndpoint _publishEndpoint;

        public CreateGuestCommandHandler(IGuestRepository guestRepository, IPublishEndpoint publishEndpoint)
        {
            _guestRepository = guestRepository;
            _publishEndpoint = publishEndpoint;
        }
        public async Task<Result> Handle(CreateGuestCommand command, CancellationToken cancellationToken)
        {
            var existing = await _guestRepository.GetByEmailAsync(command.Email, cancellationToken);
            if (existing != null)
            {
                return Result.Failure(new Error("Guest.EmailExists", "Guest already exists with this email."));
            }

            var correlationId = Guid.NewGuid();
            var generatedPassword = $"Guest-{Guid.NewGuid():N}";

            var guest = Guest.Create(command.Fullname, command.Email, command.PhoneNumber);
            await _guestRepository.AddAsync(guest, cancellationToken);

            await _publishEndpoint.Publish(new GuestCreatedEvent
            {
                CorrelationId = correlationId,
                Name = command.Fullname,
                Email = command.Email,
                Password = generatedPassword,
                ProviderName = "guest-service",
                ProviderUserId = command.Email,
                DateOfBirth = command.DateOfBirth,
                Gender = string.IsNullOrWhiteSpace(command.Gender) ? "Unknown" : command.Gender,
                PhoneNumber = command.PhoneNumber ?? string.Empty
            }, cancellationToken);

            return Result.Success();
        }
    }
}
