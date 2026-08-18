\## Docker image versioning



MindBloom API and Notifications Worker Docker images use versioned tags.



The recommended tags are:



\- semantic version, for example `1.0.0`

\- current Git commit hash

\- `latest` as an additional convenience tag only



The API and Worker use separate image names:



```text

mindbloom-api

mindbloom-worker

# MindBloom - Local Docker Setup

This section describes how to build and run the MindBloom backend locally using Docker.

The local Docker environment includes:

- MindBloom API
- MindBloom Notifications Worker
- SQL Server
- RabbitMQ
- RabbitMQ Management UI
- persistent Docker volumes
- automatic development database migrations
- demonstration seed data

---

## Prerequisites

Before starting the project, install:

- Docker Desktop
- Docker Compose
- Git

Verify that Docker is running:

```bash
docker --version
docker compose version
```

The project does not require a locally installed SQL Server or RabbitMQ when the complete Docker Compose environment is used.

---

## Environment configuration

The repository contains an `.env.example` file with all required configuration keys and safe placeholder values.

Create a local `.env` file from it.

### Windows PowerShell

```powershell
Copy-Item .env.example .env
```

### Windows Command Prompt

```cmd
copy .env.example .env
```

### Linux / macOS

```bash
cp .env.example .env
```

Open `.env` and replace placeholder values where required.

Important configuration groups include:

- application environment
- SQL Server
- JWT
- RabbitMQ
- SMTP / email
- Stripe
- Firebase
- CORS
- Google Maps
- upload configuration
- Docker image version

Example:

```env
ASPNETCORE_ENVIRONMENT=Development
DOTNET_ENVIRONMENT=Development

IMAGE_VERSION=1.0.0

JWT_SECRET=replace-with-a-random-secret-with-at-least-32-characters

EMAIL_USERNAME=your-email@example.com
EMAIL_PASSWORD=your-email-app-password

STRIPE_SECRET_KEY=your-stripe-test-secret-key
STRIPE_WEBHOOK_SECRET=your-stripe-test-webhook-secret
```

Do not commit the real `.env` file.

Only `.env.example` with placeholder values should be stored in source control.

---

## Build the Docker environment

From the repository root run:

```bash
docker compose build
```

To build without using the Docker build cache:

```bash
docker compose build --no-cache
```

---

## Start the application

Start all services:

```bash
docker compose up -d
```

To build and start in one command:

```bash
docker compose up -d --build
```

Check container status:

```bash
docker compose ps
```

All required services should eventually report a running or healthy state.

---

## Stop the application

Stop the containers while keeping persistent volumes:

```bash
docker compose down
```

The database and other persisted Docker data remain available for the next startup.

---

## Reset the local database

WARNING: The following command removes persistent Docker volumes and deletes the local Docker database.

Stop the environment and remove volumes:

```bash
docker compose down -v
```

Start the environment again:

```bash
docker compose up -d --build
```

In the Development environment, MindBloom automatically waits for the database, applies pending EF Core migrations and prepares demonstration seed data.

This makes a completely new local database ready for application testing without manually running EF Core migration commands.

Never use this reset command against an environment containing data that must be preserved.

---

## View logs

Show logs for all services:

```bash
docker compose logs
```

Follow logs continuously:

```bash
docker compose logs -f
```

Show API logs:

```bash
docker compose logs -f api
```

Show Notifications Worker logs:

```bash
docker compose logs -f worker
```

Show SQL Server logs:

```bash
docker compose logs -f sqlserver
```

Show RabbitMQ logs:

```bash
docker compose logs -f rabbitmq
```

Docker logging is configured with log rotation so container logs do not grow without limit.

---

## RabbitMQ Management

RabbitMQ exposes its Management UI locally.

Open:

```text
http://localhost:15672
```

The local development credentials are defined through the RabbitMQ variables in `.env`.

With the default development placeholders:

```text
Username: guest
Password: guest
```

The Management UI can be used to inspect:

- exchanges
- queues
- bindings
- consumers
- connections
- message rates
- dead-letter queues

Do not use default RabbitMQ credentials in production.

---

## API and Swagger

The API is available locally at:

```text
http://localhost:8080
```

In the Development environment, Swagger is available at:

```text
http://localhost:8080/swagger
```

Swagger availability is environment-specific and must not be assumed to be enabled in Production.

---

## Demonstration accounts

The Development seed creates demonstration users for the main application roles.

### Administrator

```text
Username: desktop
Email: desktop@mindbloom.com
Password: MindBloom123!
Role: Admin
```

### Client

```text
Username: mobile
Email: mobile@mindbloom.com
Password: MindBloom123!
Role: Client
```

### Approved therapist

```text
Username: therapist.amina
Email: amina@mindbloom.com
Password: MindBloom123!
Role: Therapist
Status: Approved
```

### Pending therapist

```text
Username: therapist.haris
Email: haris@mindbloom.com
Password: MindBloom123!
Role: Therapist
Status: Pending
```

These accounts are demonstration-only accounts.

The seed process also creates representative application data including therapist profiles, therapy approaches, specializations, availability, appointments with different statuses, payments, memberships, reviews, articles, workshops, mood entries, journal data, notifications and chat examples.

The seeding process is designed to be idempotent so restarting the Development environment does not intentionally create duplicate demonstration records.

---

## Rebuild a single service

It is not necessary to rebuild the complete Docker environment after changing only one application.

### Rebuild API

```bash
docker compose build api
docker compose up -d api
```

Or:

```bash
docker compose up -d --build api
```

### Rebuild Notifications Worker

```bash
docker compose build worker
docker compose up -d worker
```

Or:

```bash
docker compose up -d --build worker
```

---

## Recreate a single container

If an image is already built but the container needs to be recreated:

```bash
docker compose up -d --force-recreate api
```

For the Worker:

```bash
docker compose up -d --force-recreate worker
```

---

## Common problems

### Docker daemon is not running

If Docker commands return an error indicating that the Docker daemon cannot be reached, start Docker Desktop and wait until Docker is ready.

Then retry:

```bash
docker compose up -d
```

---

### Port is already in use

The default local ports include:

```text
API: 8080
Worker health endpoint: 8081
SQL Server: 1433
RabbitMQ: 5672
RabbitMQ Management: 15672
```

If Docker reports that a port is already allocated, stop the application using that port or change the corresponding local port in `.env`.

---

### SQL Server does not become ready

Check container status:

```bash
docker compose ps
```

Inspect SQL Server logs:

```bash
docker compose logs sqlserver
```

The API development startup includes retry/wait logic for initial database availability.

If the database remains unavailable, verify the SQL Server configuration in `.env`.

---

### Database migration fails

Inspect API logs:

```bash
docker compose logs api
```

A failed Development migration stops application startup instead of silently continuing with an invalid database schema.

After correcting the problem, restart the API:

```bash
docker compose up -d api
```

For a completely disposable local database, it can be reset with:

```bash
docker compose down -v
docker compose up -d --build
```

WARNING: This deletes persisted local Docker data.

---

### RabbitMQ connection fails

Check RabbitMQ:

```bash
docker compose ps
docker compose logs rabbitmq
```

Verify the RabbitMQ variables in `.env`, especially:

```text
RABBITMQ_HOST
RABBITMQ_PORT
RABBITMQ_USERNAME
RABBITMQ_PASSWORD
RABBITMQ_VIRTUAL_HOST
```

When services communicate inside Docker Compose they must use the configured Docker service hostname rather than assuming that `localhost` refers to another container.

---

### Startup configuration validation fails

MindBloom validates critical configuration during startup.

If a required option is missing, startup fails and the log identifies the missing configuration option without displaying the secret value.

Check:

```bash
docker compose logs api
```

or:

```bash
docker compose logs worker
```

Then verify the corresponding variable in `.env`.

Critical configuration includes JWT, database, RabbitMQ and other enabled external-service settings.

---

### JWT configuration error

Ensure that `JWT_SECRET` is configured and contains a sufficiently long random value.

Example placeholder:

```env
JWT_SECRET=replace-with-a-random-secret-with-at-least-32-characters
```

Never store a real production JWT secret in README or `.env.example`.

---

### Email sending fails

Verify:

```text
EMAIL_USERNAME
EMAIL_PASSWORD
SMTP_HOST
SMTP_PORT
SMTP_ENABLE_SSL
```

For Gmail, an application-specific password may be required instead of the normal account password.

---

### Stripe requests fail

For local development, use Stripe test/sandbox credentials.

Verify:

```text
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
```

Never place production Stripe secrets in README, `.env.example` or source control.

---

### Firebase notifications fail

Verify:

```text
FIREBASE_CREDENTIALS_PATH
```

The configured credentials file must be available to the environment in which the Notifications Worker runs.

Never commit the real Firebase service-account credentials.

---

## Docker image versioning

MindBloom uses separate Docker images for the API and Notifications Worker:

```text
mindbloom-api
mindbloom-worker
```

Images should receive:

- a semantic version tag
- a Git commit tag
- `latest` only as an additional convenience tag

Example:

```text
mindbloom-api:1.0.0
mindbloom-api:<git-commit>
mindbloom-api:latest

mindbloom-worker:1.0.0
mindbloom-worker:<git-commit>
mindbloom-worker:latest
```

The semantic version used by Docker Compose can be configured through:

```env
IMAGE_VERSION=1.0.0
```

Using explicit version tags allows a previous application image to be selected again when rollback is required.

---

## Production note

The local Docker workflow is intended primarily for Development.

Production deployment must use production-specific:

- secrets
- database credentials
- CORS origins
- HTTPS configuration
- external service credentials
- resource limits
- retry settings
- persistent storage
- image versions

Development-only behavior such as automatic development database preparation, demonstration seed data and development Swagger configuration must not be relied upon in Production.

Production database migrations should follow the defined deployment/migration strategy rather than allowing uncontrolled automatic schema changes during application startup.

---

## Quick start

For a new local installation, the complete workflow is:

```bash
git clone <repository-url>
cd <repository-directory>
cp .env.example .env
docker compose up -d --build
docker compose ps
```

Then open:

```text
API:
http://localhost:8080

Swagger:
http://localhost:8080/swagger

RabbitMQ Management:
http://localhost:15672
```

To stop:

```bash
docker compose down
```

To inspect logs:

```bash
docker compose logs -f
```

To completely reset the disposable local environment:

```bash
docker compose down -v
docker compose up -d --build
```

