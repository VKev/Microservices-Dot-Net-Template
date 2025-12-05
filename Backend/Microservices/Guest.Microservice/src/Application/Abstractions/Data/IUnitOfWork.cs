namespace Application.Abstractions.Data;

/// <summary>
/// Local unit of work abstraction for committing changes within the service boundary.
/// </summary>
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
