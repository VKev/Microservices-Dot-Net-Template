using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using SharedLibrary.Common.ResponseModel;
using SharedLibrary.Abstractions.Messaging;
using AutoMapper;
using Domain.Repositories;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Application.Users.Queries
{
    public sealed record GetAllUsersQuery : IQuery<IEnumerable<GetUserResponse>>;
    internal sealed class GetAllUsersQueryHandler : IQueryHandler<GetAllUsersQuery, IEnumerable<GetUserResponse>>
    {
        private readonly IUserRepository _userRepository;
        private readonly IMapper _mapper;

        public GetAllUsersQueryHandler(IUserRepository userRepository, IMapper mapper)
        {
            _userRepository = userRepository;
            _mapper = mapper;
        }


        public async Task<Result<IEnumerable<GetUserResponse>>> Handle(GetAllUsersQuery request, CancellationToken cancellationToken)
        {
            var userResponses = await _userRepository
                .GetAll()
                .Select(u => new GetUserResponse(u.Name, u.Email))
                .ToListAsync(cancellationToken);

            return Result.Success(userResponses.AsEnumerable());
        }
    }
}