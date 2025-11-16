using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Domain.Entities;
using Domain.Repositories;
using Infrastructure.Common;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;

namespace Infrastructure.Repositories
{
    public class GuestRepository :  Repository<Guest>, IGuestRepository
    {
        public GuestRepository(MyDbContext context) : base(context)
        {
        }

        public Task<Guest?> GetByEmailAsync(string email, CancellationToken cancellationToken)
        {
            return _context.Guests.FirstOrDefaultAsync(g => g.Email == email, cancellationToken);
        }
    }
}
