using Domain.Repositories;
using MediatR;
using SharedLibrary.Authentication;
using SharedLibrary.Common.ResponseModel;
using SharedLibrary.Extensions;

namespace Application.Users.Commands;

public class RefreshTokenCommandHandler : IRequestHandler<RefreshTokenCommand, Result<LoginResponse>>
{
    private readonly IUserRepository _userRepository;
    private readonly IJwtTokenService _jwtTokenService;

    public RefreshTokenCommandHandler(
        IUserRepository userRepository,
        IJwtTokenService jwtTokenService)
    {
        _userRepository = userRepository;
        _jwtTokenService = jwtTokenService;
    }

    public async Task<Result<LoginResponse>> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
    {
        var user = await _userRepository.GetByRefreshTokenAsync(request.RefreshToken, cancellationToken);

        if (user == null || user.RefreshTokenExpiry < DateTimeExtensions.PostgreSqlUtcNow)
        {
            return Result.Failure<LoginResponse>(new Error("Auth.InvalidRefreshToken", "Invalid or expired refresh token"));
        }

        // Get user roles
        var roles = user.UserRoles.Select(ur => ur.Role.RoleName).ToList();

        // Generate new tokens
        var accessToken = _jwtTokenService.GenerateToken(user.UserId, user.Email, roles);
        var newRefreshToken = _jwtTokenService.GenerateRefreshToken();

        // Update user with new refresh token
        user.SetRefreshToken(newRefreshToken, DateTimeExtensions.PostgreSqlUtcNow.AddDays(7));

        var response = new LoginResponse(
            AccessToken: accessToken,
            RefreshToken: newRefreshToken,
            ExpiresAt: DateTime.Now.AddMinutes(60),
            User: new UserInfo(user.UserId, user.Name, user.Email, roles)
        );

        return Result.Success(response);
    }
}
