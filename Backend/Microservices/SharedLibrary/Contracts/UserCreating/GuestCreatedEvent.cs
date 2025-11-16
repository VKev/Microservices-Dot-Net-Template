using System;

namespace SharedLibrary.Contracts.UserCreating
{
    public class GuestCreatedEvent
    {
        public Guid CorrelationId { get; set; }
        public string Name { get; set; } = null!;
        public string Email { get; set; } = null!;
        public string Password { get; set; } = null!;
        public string? ProviderName { get; set; }
        public string? ProviderUserId { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? Gender { get; set; }
        public string? PhoneNumber { get; set; }
    }
}
