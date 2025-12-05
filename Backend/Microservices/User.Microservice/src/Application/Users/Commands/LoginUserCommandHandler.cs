using Domain.Entities;
using Domain.Repositories;
using MediatR;
using SharedLibrary.Authentication;
using SharedLibrary.Common.ResponseModel;
using SharedLibrary.Extensions;

namespace Application.Users.Commands;

public class LoginUserCommandHandler : IRequestHandler<LoginUserCommand, Result<LoginResponse>>
{
    private readonly IUserRepository _userRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;

    public LoginUserCommandHandler(
        IUserRepository userRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService)
    {
        _userRepository = userRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
    }

    public async Task<Result<LoginResponse>> Handle(LoginUserCommand request, CancellationToken cancellationToken)
    {
        var user = await _userRepository.GetByEmailWithRolesAsync(request.Email, cancellationToken);

        if (user == null)
        {
            return Result.Failure<LoginResponse>(new Error("Auth.InvalidCredentials", "Invalid email or password"));
        }

        // Verify password
        if (!_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            return Result.Failure<LoginResponse>(new Error("Auth.InvalidCredentials", "Invalid email or password"));
        }

        // Get user roles (provide default role if none assigned)
        var roles = user.UserRoles?.Select(ur => ur.Role.RoleName).ToList() ?? new List<string> { "User" };

        // Generate tokens
        var accessToken = _jwtTokenService.GenerateToken(user.UserId, user.Email, roles);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        // Update user with refresh token (tracked entity; do not call Update to avoid overwriting immutable fields)
        user.SetRefreshToken(refreshToken, DateTimeExtensions.PostgreSqlUtcNow.AddDays(7)); // timestamptz requires UTC

        var response = new LoginResponse(
            AccessToken: accessToken,
            RefreshToken: refreshToken,
            ExpiresAt: DateTimeExtensions.PostgreSqlUtcNow.AddMinutes(60), // client-facing info only
            User: new UserInfo(user.UserId, user.Name, user.Email, roles)
        );

        return Result.Success(response);
    }
}
