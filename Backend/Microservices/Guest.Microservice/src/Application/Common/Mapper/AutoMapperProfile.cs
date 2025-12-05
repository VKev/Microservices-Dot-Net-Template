using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Application.Guests.Commands;
using Application.Guests.Queries;
using AutoMapper;
using Domain.Entities;

namespace Application.Common.Mapper
{
    public class AutoMapperProfile : Profile
    {
        public AutoMapperProfile()
        {
            CreateMap<CreateGuestCommand, Guest>()
                .ConstructUsing(src => Guest.Create(src.Fullname, src.Email, src.PhoneNumber));

            CreateMap<Guest, GetGuestResponse>();
        }
        
    }
}
