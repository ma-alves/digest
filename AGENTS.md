# AGENTS.md

## Commands
- Run app: `./mvnw spring-boot:run` (requires PostgreSQL running on localhost:5432)
- Run tests: `./mvnw test`
- Package: `./mvnw package`

## Development Setup

### Option 1: Docker Compose (Recommended)
```bash
# Start PostgreSQL database
docker-compose up -d postgres

# Run application (requires NEWSAPI_KEY in .env)
./mvnw spring-boot:run
```

### Option 2: Manual PostgreSQL
```bash
# Start PostgreSQL with correct database name
docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=digest -v digest-volume:/var/lib/postgresql/data postgres:17

# If database "digest" doesn't exist, create it:
docker exec <container-name> psql -U postgres -c "CREATE DATABASE digest;"

# Run application
export NEWSAPI_KEY=$(grep NEWSAPI_KEY .env | cut -d'=' -f2)
./mvnw spring-boot:run
```

### Test Environment
- Tests use H2 in-memory database
- Test properties file: `src/test/resources/application.properties` with dummy API key

## Setup Files
- `.env.example`: Copy to `.env` and add your NEWSAPI_KEY
- `docker-compose.yaml`: PostgreSQL setup with `digest` database pre-created

## Architecture
- Single Spring Boot 4.0.5 app (Java 25)
- Package: `com.example.digest`
- Entry: `DigestApplication.java`

## Tech Stack
- Spring Boot, Spring Batch, Spring Quartz Scheduler
- Spring Web MVC for REST API
- Spring Data JPA with PostgreSQL
- H2 in-memory database for tests