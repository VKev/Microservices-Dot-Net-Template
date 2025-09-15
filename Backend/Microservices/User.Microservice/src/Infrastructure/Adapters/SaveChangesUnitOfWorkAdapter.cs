using System.Threading;
using System.Threading.Tasks;
using Application.Abstractions.UnitOfWork;
using SharedLibrary.Abstractions.UnitOfWork;

namespace Infrastructure.Adapters
{
    public class SaveChangesUnitOfWorkAdapter : ISaveChangesUnitOfWork
    {
        private readonly IUnitOfWork _unitOfWork;

        public SaveChangesUnitOfWorkAdapter(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            return _unitOfWork.SaveChangesAsync(cancellationToken);
        }
    }
}


