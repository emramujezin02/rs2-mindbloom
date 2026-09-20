# MindBloom

MindBloom is a mental health application that connects clients, therapists, and administrators through a mobile application, a desktop administration portal, and a .NET backend. The system supports user registration and authentication, therapist profiles, appointment booking, payments, memberships, chat, notifications, therapist recommendations, educational content, workshops, and administrator reports.

The repository is organized so that the active source projects are clearly separated:

```text
MindBloom/
├── backend/
│   └── src/
│       ├── MindBloom.API/
│       ├── MindBloom.Application/
│       ├── MindBloom.Domain/
│       ├── MindBloom.Infrastructure/
│       ├── MindBloom.Messaging.Contracts/
│       ├── MindBloom.NotificationsWorker/
│       ├── MindBloom.Shared/
│       ├── MindBloom.IntegrationTests/
│       ├── MindBloom.SecurityTests/
│       └── MindBloom.UnitTests/
├── frontend/
│   ├── mindbloom_mobile/
│   ├── mindbloom_desktop/
│   └── scripts/
├── docs/
├── docker-compose.yml
├── build-images.ps1
├── MindBloom.sln
└── README.md
```

## Architecture overview

The backend is a .NET 9 solution organized into layers:

- `MindBloom.API` exposes the REST API, Swagger/OpenAPI documentation, JWT authentication, authorization policies, health check endpoints, a metrics endpoint, and SignalR hubs.
- `MindBloom.Application` contains DTOs, validators, service abstractions, and use-case contracts.
- `MindBloom.Domain` contains domain entities, enums, and core business concepts.
- `MindBloom.Infrastructure` implements EF Core persistence, SQL Server access, Identity, Stripe, RabbitMQ publishing, SignalR services, uploads/geocoding, and other technical services.
- `MindBloom.Messaging.Contracts` shares message contract types between the API and the Worker process.
- `MindBloom.NotificationsWorker` is a separate background process that consumes RabbitMQ messages and handles email/push/integration-event delivery outside the HTTP request flow.

The frontend consists of two Flutter applications:

- `frontend/mindbloom_mobile` - mobile application for clients and therapists.
- `frontend/mindbloom_desktop` - desktop administration portal.

A typical synchronous flow:

```text
Flutter Mobile/Desktop -> MindBloom.API -> Application -> Infrastructure -> SQL Server
```

A typical asynchronous notification flow:

```text
MindBloom.API -> RabbitMQ -> Notifications Worker -> Email/Firebase push/SQL status
```

Realtime flow:

```text
Flutter client <-> SignalR hubs (/hubs/notifications, /hubs/chat) <-> Backend services
```

A more detailed system description is available in [docs/system-architecture.md](docs/system-architecture.md).

## Prerequisites

For local development, it is recommended to have:

- Git
- Docker Desktop with Docker Compose support
- .NET SDK 9.x
- Flutter SDK
- Android Studio / Android SDK for the mobile emulator
- Visual Studio 2022 with the Windows desktop workload for Flutter Windows builds
- Stripe CLI for local webhook testing
- Firebase service account JSON if real push notifications are being tested

Check the basic tools:

```powershell
git --version
dotnet --version
docker --version
docker compose version
flutter --version
```

## Environment configuration

The root `.env` file is used for Docker Compose and backend configuration. Do not commit real secret values.

Create a local `.env` file:

```powershell
Copy-Item .env.example .env
```

For final evaluation, a separate configuration package named `MindBloom-Environment.zip` may also be provided. That package is not included in the public GitHub Release assets or in the source repository, is password-protected, and contains sensitive/local configuration files required to run the evaluation environment. The password is delivered separately to the evaluator. After downloading it, the evaluator should extract the package and place the received configuration files in their intended project locations before starting the system. The package, its password, and the real configuration values must not be committed or uploaded as a public release asset.

At minimum, check and fill in values for:

- SQL Server: `SQL_SERVER_PORT`, `SQL_SERVER_DATABASE`, `SQL_SERVER_PASSWORD`, `DB_CONNECTION`
- JWT: `JWT_SECRET`, `JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_EXPIRATION_MINUTES`
- RabbitMQ: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`, `RABBITMQ_VIRTUAL_HOST` and queue/exchange variables
- Email: `EMAIL_USERNAME`, `EMAIL_PASSWORD`
- Stripe backend: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- Firebase Worker: `FIREBASE_CREDENTIALS_PATH`, `FIREBASE_BATCH_SIZE`, `FIREBASE_RETRY_COUNT`, `FIREBASE_RETRY_DELAY_SECONDS`
- Google Maps: `GOOGLE_MAPS_API_KEY`, `GOOGLE_MAPS_GEOCODING_URL`
- Uploads: `UPLOAD_ROOT_PATH`, `UPLOAD_MAX_IMAGE_SIZE_MB`, `UPLOAD_MAX_DOCUMENT_SIZE_MB`
- Docker image tag: `IMAGE_VERSION`

The demo database uses the name:

```text
220075
```

For Stripe sandbox integration tests, an additional process environment variable is used:

```powershell
$env:STRIPE_SANDBOX_SECRET_KEY="<YOUR_STRIPE_TEST_SECRET_KEY>"
```

This value must be a Stripe test secret key that starts with `sk_test_`. Do not enter a live key and do not commit the test secret to the repository.

## Docker backend environment

Docker Compose defines four main services:

- `sql-server` - SQL Server 2022, port from `SQL_SERVER_PORT` or `1433`
- `rabbitmq` - RabbitMQ with the management plugin, ports `5672` and `15672`
- `api` - MindBloom API image `mindbloom-api:${IMAGE_VERSION:-1.0.0}`, local port from `API_PORT` or `8080`
- `notifications-worker` - Worker image `mindbloom-worker:${IMAGE_VERSION:-1.0.0}`, health port from `WORKER_HEALTH_PORT` or `8081`

Check the Compose configuration:

```powershell
docker compose config
```

Start the complete backend environment:

```powershell
docker compose up -d --build
```

Check the status:

```powershell
docker compose ps
```

Stop without deleting data:

```powershell
docker compose down
```

Optional destructive reset/troubleshooting: the following command deletes Docker volume data, including persistent SQL Server/RabbitMQ data. It is not part of the normal startup/shutdown flow and is used only when you intentionally want a fresh local environment.

```powershell
docker compose down -v
```

The Docker build context is the repository root, and the Dockerfile paths are:

```text
backend/src/MindBloom.API/Dockerfile
backend/src/MindBloom.NotificationsWorker/Dockerfile
```

## Backend locally

Restore, build, and test from the root folder:

```powershell
dotnet restore MindBloom.sln
dotnet build MindBloom.sln
dotnet test MindBloom.sln
```

Run the API locally:

```powershell
dotnet run --project backend/src/MindBloom.API/MindBloom.API.csproj
```

Run the Worker process locally:

```powershell
dotnet run --project backend/src/MindBloom.NotificationsWorker/MindBloom.Worker.csproj
```

The backend code supports:

- REST API controllers under `/api`
- Swagger UI in Development mode
- health check endpoints `/health/live` and `/health/ready`
- metrics endpoint `/metrics`
- SignalR hubs `/hubs/notifications` and `/hubs/chat`
- JWT Bearer authentication and role/policy authorization
- rate limiting middleware

If the API is started through Docker Compose, the standard URL is:

```text
http://localhost:8080
```

If the API is started locally through the Visual Studio/http profile, the mobile script targets the following by default:

```text
http://10.0.2.2:5110
```

## Swagger/OpenAPI

Swagger UI is available in Development mode:

```text
http://localhost:8080/swagger
```

For local `dotnet run`, the port may depend on the launch profile. If the HTTP profile on port `5110` is used, Swagger is:

```text
http://localhost:5110/swagger
```

The REST API documentation for the defense is located at [docs/api-documentation.md](docs/api-documentation.md).

## RabbitMQ and Notifications Worker

RabbitMQ is used for asynchronous notification processing and integration event messages. The API publishes messages, and `MindBloom.NotificationsWorker` consumes them from RabbitMQ queues. The Worker then handles delivery through email, Firebase push, and related persistence/integration flows.

Compose uses the RabbitMQ management UI at:

```text
http://localhost:15672
```

Queue/exchange/routing key values are configured through `.env` variables with the `RABBITMQ_` prefix, including notification exchange, email queue, integration-event queue, retry exchange, and dead-letter queue configuration.

## SQL Server

SQL Server is the primary persistence store for the backend. The EF Core model, Identity tables, business tables, chat, notifications, payments, memberships, workshops, articles, journaling/mood data, and reference data are documented in:

[docs/database-schema.md](docs/database-schema.md)

The local SQL Server port comes from:

```text
SQL_SERVER_PORT
```

Database name for the demo environment:

```text
220075
```

## Flutter Mobile

The mobile application is located in:

```text
frontend/mindbloom_mobile
```

Basic commands:

```powershell
cd frontend/mindbloom_mobile
flutter pub get
flutter analyze
flutter test
```

Run through the project:

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:5110 --dart-define=STRIPE_PUBLISHABLE_KEY=<YOUR_STRIPE_TEST_PUBLISHABLE_KEY>
```

Run through the helper script:

```powershell
cd frontend
.\scripts\run-mobile.ps1
```

`run-mobile.ps1` uses the default `API_BASE_URL=http://10.0.2.2:5110`. It reads the Stripe publishable key from a parameter, the `STRIPE_PUBLISHABLE_KEY` environment variable, or `frontend\.env.local`.

Example with explicit values:

```powershell
.\scripts\run-mobile.ps1 -ApiBaseUrl "http://10.0.2.2:5110" -StripePublishableKey "<YOUR_STRIPE_TEST_PUBLISHABLE_KEY>"
```

Mobile `STRIPE_PUBLISHABLE_KEY` must start with `pk_test_`. If it is not set, the application starts, but the payment flow remains unavailable for that run.

Android Google Maps configuration for source builds is read from:

```text
frontend/mindbloom_mobile/android/local.properties
```

Add the following locally to that file:

```text
MAPS_API_KEY=<YOUR_GOOGLE_MAPS_API_KEY>
```

The real Google Maps API key must not be committed to Git. `local.properties` is intentionally ignored/untracked, and the existing Android Gradle settings read `MAPS_API_KEY` from that file and pass it to the Android manifest. This key is required for the integrated therapist location map to work in the Android application. The backend `GOOGLE_MAPS_API_KEY` from the root `.env` remains a separate backend configuration.

## Flutter Desktop

The desktop administration portal is located in:

```text
frontend/mindbloom_desktop
```

Basic commands:

```powershell
cd frontend/mindbloom_desktop
flutter pub get
flutter analyze
flutter test
```

Run:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

The desktop application uses the following by default:

```text
http://localhost:8080
```

If you run the API locally on a different port, pass the appropriate `API_BASE_URL`.

## Dart define values

Active Flutter projects use the following compile-time values:

| Project | Value | Purpose |
| --- | --- | --- |
| Mobile | `API_BASE_URL` | Backend API base URL |
| Mobile | `STRIPE_PUBLISHABLE_KEY` | Stripe test publishable key for the mobile payment sheet |
| Desktop | `API_BASE_URL` | Backend API base URL |
| Desktop | `APP_ENV` | Displays the environment label in the admin settings section |

## Stripe sandbox

The backend Stripe integration uses:

- `STRIPE_SECRET_KEY` - Stripe secret key for backend PaymentIntent/refund operations
- `STRIPE_WEBHOOK_SECRET` - webhook signing secret for Stripe webhook event validation

The mobile Stripe integration uses:

- `STRIPE_PUBLISHABLE_KEY` - publishable key that starts with `pk_test_`

Sandbox integration tests use:

- `STRIPE_SANDBOX_SECRET_KEY` - test secret key that starts with `sk_test_`

Local webhook example with Stripe CLI:

```powershell
stripe listen --forward-to http://localhost:8080/api/stripe/webhook
```

Set the webhook signing secret printed by Stripe CLI in `.env` as `STRIPE_WEBHOOK_SECRET`. Do not use the publishable key or Stripe API secret as the webhook secret.

## Firebase push notifications

The Notifications Worker uses Firebase Admin/FCM if `FIREBASE_CREDENTIALS_PATH` is configured. If the path is not configured, the code registers a no-op push notification service, so the backend can work without a real Firebase credential file, but real push notifications are not active then.

Configuration values:

```text
FIREBASE_CREDENTIALS_PATH
FIREBASE_BATCH_SIZE
FIREBASE_RETRY_COUNT
FIREBASE_RETRY_DELAY_SECONDS
```

Do not commit the Firebase service account JSON.

## Demo users

The seeder creates the following demo users when seed is enabled:

| Role | Username | Email | Password | Note |
| --- | --- | --- | --- | --- |
| Admin | `desktop` | `desktop@mindbloom.com` | `MindBloom123!` | Desktop admin portal |
| Client | `mobile` | `mobile@mindbloom.com` | `MindBloom123!` | Mobile client demo |
| Therapist | `therapist.amina` | `amina@mindbloom.com` | `MindBloom123!` | Approved therapist |
| Therapist | `therapist.haris` | `haris@mindbloom.com` | `MindBloom123!` | Pending therapist |

These values are demo seed data, not production secrets.

## Tests

Backend:

```powershell
dotnet test MindBloom.sln
```

Targeted test projects:

```powershell
dotnet test backend/src/MindBloom.UnitTests/MindBloom.UnitTests.csproj
dotnet test backend/src/MindBloom.IntegrationTests/MindBloom.IntegrationTests.csproj
dotnet test backend/src/MindBloom.SecurityTests/MindBloom.SecurityTests.csproj
```

Stripe sandbox tests require `STRIPE_SANDBOX_SECRET_KEY` in the process environment:

```powershell
$env:STRIPE_SANDBOX_SECRET_KEY="<YOUR_STRIPE_TEST_SECRET_KEY>"
dotnet test backend/src/MindBloom.IntegrationTests/MindBloom.IntegrationTests.csproj --filter "FullyQualifiedName~StripeSandboxWorkflowTests"
```

Flutter:

```powershell
cd frontend/mindbloom_mobile
flutter test

cd ../mindbloom_desktop
flutter test
```

## Build commands

Backend Docker images:

```powershell
docker compose build api notifications-worker
```

Mobile Android APK:

```powershell
cd frontend/mindbloom_mobile
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5110 --dart-define=STRIPE_PUBLISHABLE_KEY=<YOUR_STRIPE_TEST_PUBLISHABLE_KEY>
```

Desktop Windows build:

```powershell
cd frontend/mindbloom_desktop
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:8080
```

If the Windows build has a path/cache problem on the OneDrive location, use a shorter path or the previously agreed `subst` workflow and do not change application code because of environment problems.

## Troubleshooting

`docker compose config` reports a missing variable:

- Check that the root `.env` exists.
- Compare `.env` with `.env.example`.
- Do not copy real secret values into README or documentation.

API container is not healthy:

- Check `docker compose ps`.
- Check SQL Server and RabbitMQ health status.
- Check `docker compose logs api`.

Mobile emulator cannot reach the API:

- For the Android emulator, use `http://10.0.2.2:<port>`.
- For the Docker API, the default is `http://10.0.2.2:8080`.
- For the local Visual Studio/http profile, the default script is `http://10.0.2.2:5110`.

Desktop cannot reach the API:

- For the Docker API, use `http://localhost:8080`.
- If the API is running on a local launch profile, pass that port through `--dart-define=API_BASE_URL=...`.

Stripe payment flow is not available in the mobile application:

- Check that `STRIPE_PUBLISHABLE_KEY` is set and starts with `pk_test_`.
- Check that the backend has `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET`.

Stripe sandbox tests fail because of a missing key:

- Set `STRIPE_SANDBOX_SECRET_KEY` in the same PowerShell session in which you run the test.

Firebase push does not send real notifications:

- Check `FIREBASE_CREDENTIALS_PATH`.
- Check that the JSON credential file exists locally and is not committed.

## Documentation

- [System architecture](docs/system-architecture.md)
- [Database schema](docs/database-schema.md)
- [REST API documentation](docs/api-documentation.md)
- [Recommender documentation](docs/recommender-dokumentacija.md)
- [Demo scenario](docs/demo-scenario.md) - recommended demonstration flow for client, therapist, and administrator workflows.

## Git security

Do not commit:

- `.env`
- Firebase service account JSON
- Stripe secret keys
- webhook signing secrets
- SQL passwords
- local emulator/debug/cache files
