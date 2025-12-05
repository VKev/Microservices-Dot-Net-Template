using SharedLibrary.Common.ResponseModel;
using Application.Users.Commands;
using Domain.Repositories;
using FluentAssertions;
using MassTransit;
using Moq;
using SharedLibrary.Authentication;

namespace test.Users.Commands
{
    public class RegisterUserCommandHandlerTests
    {
        private readonly Mock<IUserRepository> _userRepositoryMock;
        private readonly Mock<IRoleRepository> _roleRepositoryMock;
        private readonly Mock<IUserRoleRepository> _userRoleRepositoryMock;
        private readonly Mock<IPasswordHasher> _passwordHasherMock;
        private readonly Mock<IPublishEndpoint> _publishEndpointMock;

        public RegisterUserCommandHandlerTests()
        {
            _userRepositoryMock = new();
            _roleRepositoryMock = new();
            _userRoleRepositoryMock = new();
            _passwordHasherMock = new();
            _publishEndpointMock = new();
            _passwordHasherMock.Setup(p => p.HashPassword(It.IsAny<string>())).Returns("hashed");
        }

        [Fact]
        public async Task Handle_Should_ReturnSuccessResult_When_UserNotExist()
        {
            var command = new RegisterUserCommand("test_user", "test_user_email", "test_password");
            var handler = new RegisterUserCommandHandler(_userRepositoryMock.Object, _roleRepositoryMock.Object, _userRoleRepositoryMock.Object, _passwordHasherMock.Object, _publishEndpointMock.Object);
            Result result = await handler.Handle(command,default);
            result.IsSuccess.Should().BeTrue();
        }
    }
}
