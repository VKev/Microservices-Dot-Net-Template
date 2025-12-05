namespace Application.Abstractions.Data;

/// <summary>
/// Local unit of work abstraction for the User service boundary.
/// </summary>
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
