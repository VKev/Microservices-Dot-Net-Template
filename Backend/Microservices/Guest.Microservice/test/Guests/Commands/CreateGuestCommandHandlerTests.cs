using System;
using SharedLibrary.Common.ResponseModel;
using Application.Guests.Commands;
using Domain.Repositories;
using FluentAssertions;
using MassTransit;
using Moq;

namespace test.Guests.Commands
{
    public class CreateGuestCommandHandlerTests
    {
        private readonly Mock<IGuestRepository> _guestRepositoryMock;
        private readonly Mock<IPublishEndpoint> _publishEndpointMock;

        public CreateGuestCommandHandlerTests()
        {
            _guestRepositoryMock = new();
            _publishEndpointMock = new();
        }

        [Fact]
        public async Task Handle_Should_ReturnSuccessResult_When_UserNotExist()
        {
            var command = new CreateGuestCommand("test_user", "test_user_email");
            var handler = new CreateGuestCommandHandler(_guestRepositoryMock.Object, _publishEndpointMock.Object);
            Result result = await handler.Handle(command,default);
            result.IsSuccess.Should().BeTrue();
        }
    }
}
