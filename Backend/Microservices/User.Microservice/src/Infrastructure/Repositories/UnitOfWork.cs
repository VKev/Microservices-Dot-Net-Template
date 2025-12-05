using Application.Abstractions.Data;
using Infrastructure.Context;

namespace Infrastructure.Repositories;

public sealed class UnitOfWork : IUnitOfWork, IDisposable
{
    private readonly MyDbContext _context;

    public UnitOfWork(MyDbContext context)
    {
        _context = context;
    }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return _context.SaveChangesAsync(cancellationToken);
    }

    public void Dispose()
    {
        _context.Dispose();
    }
}
