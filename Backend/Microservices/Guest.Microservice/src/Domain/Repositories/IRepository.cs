using System.Linq.Expressions;

namespace Domain.Repositories;

/// <summary>
/// Minimal repository abstraction local to the domain layer to avoid infrastructure dependencies.
/// </summary>
/// <typeparam name="T">Aggregate root or entity type.</typeparam>
public interface IRepository<T> where T : class
{
    Task AddAsync(T entity, CancellationToken cancellationToken = default);
    Task AddRangeAsync(IEnumerable<T> entities, CancellationToken cancellationToken = default);
    Task<T?> GetByIdAsync(object id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<T>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<T>> FindAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default);
    void Update(T entity);
    Task DeleteByIdAsync(object id, CancellationToken cancellationToken = default);
    void Delete(T entity);
    void DeleteRange(IEnumerable<T> entities);
}
