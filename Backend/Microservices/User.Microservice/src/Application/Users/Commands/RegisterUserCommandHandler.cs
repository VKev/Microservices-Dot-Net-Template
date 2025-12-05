using System;
using SharedLibrary.Common.ResponseModel;
using SharedLibrary.Abstractions.Messaging;
using Domain.Entities;
using Domain.Repositories;
using MassTransit;
using SharedLibrary.Contracts.UserCreating;
using SharedLibrary.Authentication;
using SharedLibrary.Extensions;

namespace Application.Users.Commands
{
    public sealed record RegisterUserCommand(
        string Name,
        string Email,
        string Password,
        string? ProviderName = null,
        string? ProviderUserId = null,
        DateTime? DateOfBirth = null,
        string? Gender = null,
        string? PhoneNumber = null
    ) : ICommand;

    internal sealed class RegisterUserCommandHandler : ICommandHandler<RegisterUserCommand>
    {
        private readonly IUserRepository _userRepository;
        private readonly IRoleRepository _roleRepository;
        private readonly IUserRoleRepository _userRoleRepository;
        private readonly IPasswordHasher _passwordHasher;
        private readonly IPublishEndpoint _publishEndpoint;

        public RegisterUserCommandHandler(IUserRepository userRepository, IRoleRepository roleRepository, IUserRoleRepository userRoleRepository, IPasswordHasher passwordHasher, IPublishEndpoint publishEndpoint)
        {
            _userRepository = userRepository;
            _roleRepository = roleRepository;
            _userRoleRepository = userRoleRepository;
            _passwordHasher = passwordHasher;
            _publishEndpoint = publishEndpoint;
        }

        public async Task<Result> Handle(RegisterUserCommand command, CancellationToken cancellationToken)
        {
            var providerName = string.IsNullOrWhiteSpace(command.ProviderName) ? "local" : command.ProviderName!;
            var providerUserId = string.IsNullOrWhiteSpace(command.ProviderUserId) ? command.Email : command.ProviderUserId!;
            var hashedPassword = _passwordHasher.HashPassword(command.Password);
            var now = DateTimeExtensions.PostgreSqlUtcNow;

            var user = User.Create(
                command.Name,
                command.Email,
                hashedPassword,
                providerName,
                providerUserId,
                string.IsNullOrWhiteSpace(command.PhoneNumber) ? string.Empty : command.PhoneNumber,
                now,
                command.DateOfBirth,
                string.IsNullOrWhiteSpace(command.Gender) ? "Unknown" : command.Gender,
                false);

            // Find or create default "User" role
            var userRole = await _roleRepository.GetByNameAsync("User", cancellationToken);
            if (userRole == null)
            {
                userRole = new Role
                {
                    RoleId = Guid.NewGuid(),
                    RoleName = "User",
                    CreatedAt = DateTimeExtensions.PostgreSqlUtcNow
                };
                await _roleRepository.AddAsync(userRole, cancellationToken);
            }

            await _userRepository.AddAsync(user, cancellationToken);

            // Assign default role to user
            var userRoleAssignment = new UserRole
            {
                UserId = user.UserId,
                RoleId = userRole.RoleId
            };

            await _userRoleRepository.AddAsync(userRoleAssignment, cancellationToken);

            await _publishEndpoint.Publish(new UserCreatingSagaStart
            {
                CorrelationId = Guid.NewGuid(),
                Name = user.Name,
                Email = user.Email
            }, cancellationToken);

            return Result.Success();
        }
    }
}
