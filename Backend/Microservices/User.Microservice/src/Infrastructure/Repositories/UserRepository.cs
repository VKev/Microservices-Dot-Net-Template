using Domain.Entities;
using Domain.Repositories;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;

namespace Infrastructure.Repositories
{
    public class UserRepository : IUserRepository
    {
        private readonly MyDbContext _context;

        public UserRepository(MyDbContext context)
        {
            _context = context;
        }

        public async Task AddAsync(User entity, CancellationToken cancellationToken = default)
        {
            await _context.Users.AddAsync(entity, cancellationToken);
        }

        public async Task AddRangeAsync(IEnumerable<User> entities, CancellationToken cancellationToken = default)
        {
            await _context.Users.AddRangeAsync(entities, cancellationToken);
        }

        public async Task<User?> GetByIdAsync(object id, CancellationToken cancellationToken = default)
        {
            return await _context.Users.FindAsync(new[] { id }, cancellationToken);
        }

        public async Task<IReadOnlyList<User>> GetAllAsync(CancellationToken cancellationToken = default)
        {
            return await _context.Users.AsNoTracking().ToListAsync(cancellationToken);
        }

        public async Task<IReadOnlyList<User>> FindAsync(System.Linq.Expressions.Expression<Func<User, bool>> predicate, CancellationToken cancellationToken = default)
        {
            return await _context.Users.Where(predicate).ToListAsync(cancellationToken);
        }

        public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken)
        {
            return _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Email == email, cancellationToken);
        }

        public Task<User?> GetByEmailWithRolesAsync(string email, CancellationToken cancellationToken)
        {
            return _context.Users
                .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
                .FirstOrDefaultAsync(u => u.Email == email, cancellationToken);
        }

        public Task<User?> GetByRefreshTokenAsync(string refreshToken, CancellationToken cancellationToken)
        {
            return _context.Users
                .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
                .FirstOrDefaultAsync(u => u.RefreshToken == refreshToken, cancellationToken);
        }

        public async Task<IReadOnlyList<User>> GetAllWithRolesAsync(CancellationToken cancellationToken)
        {
            return await _context.Users
                .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
                .AsNoTracking()
                .ToListAsync(cancellationToken);
        }

        public void Update(User entity)
        {
            _context.Users.Update(entity);
        }

        public async Task DeleteByIdAsync(object id, CancellationToken cancellationToken = default)
        {
            var entity = await _context.Users.FindAsync(new[] { id }, cancellationToken);
            if (entity != null)
            {
                _context.Users.Remove(entity);
            }
        }

        public void Delete(User entity)
        {
            _context.Users.Remove(entity);
        }

        public void DeleteRange(IEnumerable<User> entities)
        {
            _context.Users.RemoveRange(entities);
        }
    }
}
