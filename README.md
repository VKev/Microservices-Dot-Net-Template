# Microservices-Dot-Net-Template

docker-compose -p microservices up --build -d

docker-compose -p microservices up


docker-compose -f docker-compose-production.yml -p microservices up --build -d
docker-compose -f docker-compose-production.yml -p microservices up

redis-cli --scan --pattern "user-creating-saga:*" | xargs redis-cli del
