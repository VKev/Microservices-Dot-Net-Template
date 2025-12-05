using System.Collections.ObjectModel;

namespace Domain.Entities;

public sealed class User
{
    private readonly List<UserRole> _userRoles = new();

    private User()
    {
        // Required by EF Core
    }

    private User(string name, string email, string passwordHash, string providerName, string providerUserId, string? phoneNumber, DateTime createdAtUtc)
    {
        UserId = Guid.NewGuid();
        Name = !string.IsNullOrWhiteSpace(name) ? name : throw new ArgumentException("Name is required", nameof(name));
        Email = !string.IsNullOrWhiteSpace(email) ? email : throw new ArgumentException("Email is required", nameof(email));
        PasswordHash = !string.IsNullOrWhiteSpace(passwordHash) ? passwordHash : throw new ArgumentException("Password hash is required", nameof(passwordHash));
        ProviderName = string.IsNullOrWhiteSpace(providerName) ? "local" : providerName;
        ProviderUserId = string.IsNullOrWhiteSpace(providerUserId) ? email : providerUserId;
        PhoneNumber = phoneNumber ?? string.Empty;
        CreatedAt = createdAtUtc;
        UpdatedAt = createdAtUtc;
    }

    public Guid UserId { get; private set; }

    public string Name { get; private set; } = null!;

    public string Email { get; private set; } = null!;

    public string PasswordHash { get; private set; } = null!;

    public string? ProviderName { get; private set; }

    public string? ProviderUserId { get; private set; }

    public DateTime? UpdatedAt { get; private set; }

    public DateTime? DateOfBirth { get; private set; }

    public string? Gender { get; private set; }

    public string? PhoneNumber { get; private set; }

    public string? RefreshToken { get; private set; }

    public DateTime? RefreshTokenExpiry { get; private set; }

    public DateTime? CreatedAt { get; private set; }

    public bool IsVerified { get; private set; }

    public IReadOnlyCollection<UserRole> UserRoles => new ReadOnlyCollection<UserRole>(_userRoles);

    public static User Create(string name, string email, string passwordHash, string providerName, string providerUserId, string? phoneNumber, DateTime createdAtUtc, DateTime? dateOfBirth, string? gender, bool isVerified = false)
    {
        var user = new User(name, email, passwordHash, providerName, providerUserId, phoneNumber, createdAtUtc)
        {
            DateOfBirth = dateOfBirth,
            Gender = string.IsNullOrWhiteSpace(gender) ? "Unknown" : gender,
            IsVerified = isVerified
        };
        return user;
    }

    public void SetRefreshToken(string refreshToken, DateTime expiresAtUtc)
    {
        RefreshToken = refreshToken;
        RefreshTokenExpiry = expiresAtUtc;
        UpdatedAt = expiresAtUtc;
    }

    public void UpdatePasswordHash(string passwordHash, DateTime updatedAtUtc)
    {
        PasswordHash = passwordHash;
        UpdatedAt = updatedAtUtc;
    }

    public void Verify(DateTime updatedAtUtc)
    {
        IsVerified = true;
        UpdatedAt = updatedAtUtc;
    }

    public void UpdateProfile(string name, string? gender, DateTime? dateOfBirth, string? phoneNumber, DateTime updatedAtUtc)
    {
        Name = !string.IsNullOrWhiteSpace(name) ? name : Name;
        Gender = string.IsNullOrWhiteSpace(gender) ? Gender : gender;
        DateOfBirth = dateOfBirth ?? DateOfBirth;
        PhoneNumber = phoneNumber ?? PhoneNumber;
        UpdatedAt = updatedAtUtc;
    }
}
