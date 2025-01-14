# Microservices .NET Template

This repository provides a robust template for building .NET microservices applications. It includes:
- **Ocelot API Gateway**: For routing and aggregating requests.
- **RabbitMQ**: As a message broker for inter-service communication.
- **Saga Pattern**: For managing distributed transactions.

---

## Quick Start

### Development Setup

1. **Clone this repository:**

   ```bash
   git clone <your-repo-url>
   cd microservices-dot-net-template
   ```

2. **Create a `.env` file for each microservice:**

   In `Microservices/<YourServiceName>.Microservice/src`, create a `.env` file with the following content:

   ```env
   ASPNETCORE_ENVIRONMENT=Development
   DATABASE_HOST=YOUR_DATABASE_HOST
   DATABASE_PORT=YOUR_DATABASE_PORT
   DATABASE_NAME=YOUR_DATABASE_NAME
   DATABASE_USERNAME=YOUR_USERNAME
   DATABASE_PASSWORD=YOUR_PASSWORD
   ASPNETCORE_URLS=http://localhost:5001
   RABBITMQ_HOST=localhost
   RABBITMQ_PORT=5672
   RABBITMQ_USERNAME=YOUR_USERNAME
   RABBITMQ_PASSWORD=YOUR_PASSWORD
   REDIS_HOST=localhost
   REDIS_PASSWORD=YOUR_PASSWORD
   REDIS_PORT=6379
   ```
3. **Create a `.env` file for the API Gateway:**

In `ApiGateway/src`, create a `.env` file with the following content:

```env
ASPNETCORE_ENVIRONMENT=Development
USER_MICROSERVICE_HOST=localhost
USER_MICROSERVICE_PORT=5002
GUEST_MICROSERVICE_HOST=localhost
GUEST_MICROSERVICE_PORT=5001
```
- Refer to launch.json in `WebApi/Properties` of each microservice to determine the correct port and configuration.

- Update the `ocelot.Development.json` or `ocelot.Production.json` files in `ApiGateway/src` to map these settings properly. Add new services here if required.

4. **Ensure RabbitMQ and Redis are running:**

   Use the configuration specified in your `.env` files. You can either run them on the cloud or locally using Docker.

5. **Run the services locally:**

   - **Start the API Gateway:**
     ```bash
     cd ApiGateway/src
     dotnet run
     ```
   - **Start a microservice:**
     ```bash
     cd Microservices/<YourServiceName>.Microservice/src/WebApi
     dotnet run
     ```
   - **Repeat for additional microservices:**
     Navigate to their respective `WebApi` directories and run `dotnet run`.

---

### Docker Setup

#### Development with Docker Compose

1. **Setup Docker Compose:**
   Ensure all fields in `docker-compose.yml` are properly configured.

2. **Start the application:**
   ```bash
   docker-compose -p microservices up --build -d
   ```

3. **Rebuild and restart (if needed):**
   ```bash
   docker-compose -p microservices up
   ```

#### Production with Docker Compose

1. **Configure production settings:**
   Update your cloud database (e.g., PostgreSQL), RabbitMQ, and Redis credentials in `docker-compose-production.yml`.

2. **Start the services:**
   ```bash
   docker-compose -f docker-compose-production.yml -p microservices up --build -d
   ```

3. **Default settings:**
   The app will run on `localhost:2406` by default. Modify `docker-compose-production.yml` to change this setting.

4. **Deploy to distributed servers:**
   - **Build and push Docker images:**
     ```bash
     docker-compose build
     docker tag <image> <docker-hub-repo>
     docker push <docker-hub-repo>
     ```
   - **Update service domains:**
     Adjust the `docker-compose.yml` file to use your server domain for each service.

---

## Key Features

- **Ocelot API Gateway:** Simplifies routing and communication between services.
- **RabbitMQ:** Ensures reliable inter-service messaging.
- **Saga Pattern:** Manages distributed transactions efficiently.
- **Dockerized Setup:** Supports local development and production deployment with Docker Compose.

---

## Additional Notes

- **Environment Configuration:** Use `.env` files to manage environment-specific settings.
- **RabbitMQ Integration:** Ensure all microservices share the same RabbitMQ instance for seamless communication.
- **Monitoring Tools:** Access RabbitMQ Management UI at `http://localhost:15672`.
- **Security:** Update and secure sensitive information before deploying to production.

---

Enjoy building your microservices architecture with .NET!
