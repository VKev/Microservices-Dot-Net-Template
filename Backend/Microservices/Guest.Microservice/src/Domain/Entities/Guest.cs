using System.Collections.ObjectModel;

namespace Domain.Entities;

public sealed class Guest
{
    private readonly List<Guestrolemapping> _guestrolemappings = new();

    private Guest()
    {
        // Required by EF Core
    }

    private Guest(string fullname, string email, string? phoneNumber)
    {
        Guestid = 0; // Database-generated
        Fullname = !string.IsNullOrWhiteSpace(fullname) ? fullname : throw new ArgumentException("Full name is required", nameof(fullname));
        Email = !string.IsNullOrWhiteSpace(email) ? email : throw new ArgumentException("Email is required", nameof(email));
        Phonenumber = phoneNumber;
        // Store as "unspecified" to align with timestamp without time zone columns
        Createdat = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
    }

    public int Guestid { get; private set; }

    public string Fullname { get; private set; } = null!;

    public string Email { get; private set; } = null!;

    public string? Phonenumber { get; private set; }

    public DateTime? Createdat { get; private set; }

    public IReadOnlyCollection<Guestrolemapping> Guestrolemappings => new ReadOnlyCollection<Guestrolemapping>(_guestrolemappings);

    public static Guest Create(string fullname, string email, string? phoneNumber = null)
        => new(fullname, email, phoneNumber);

    public void UpdateContact(string? phoneNumber)
    {
        Phonenumber = phoneNumber;
    }

    public void UpdateProfile(string fullname)
    {
        Fullname = !string.IsNullOrWhiteSpace(fullname) ? fullname : Fullname;
    }
}
