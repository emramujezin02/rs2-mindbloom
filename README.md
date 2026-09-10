# MindBloom

MindBloom is a mental health platform that connects clients, therapists and administrators through a mobile application, desktop administration application and ASP.NET Core backend.

The system includes:

- ASP.NET Core Web API
- Flutter mobile application
- Flutter desktop administration application
- SQL Server
- RabbitMQ
- Notifications Worker
- Stripe sandbox payments
- Firebase push notifications
- email notifications
- SignalR realtime communication
- recommendation system
- PDF reporting
- Docker Compose infrastructure

---

# Local Development Setup

## Prerequisites

Before starting the project, install:

- Git
- Docker Desktop
- Docker Compose
- .NET SDK 9
- Flutter SDK

Depending on the functionality being tested, you may also need:

- Android Studio / Android Emulator
- Stripe CLI
- Firebase service account credentials
- Gmail application password

Verify the main tools:

```bash
git --version
docker --version
docker compose version
dotnet --version
flutter --version
```

When using the complete Docker Compose environment, a locally installed SQL Server or RabbitMQ instance is not required.

---

# Environment Configuration

The repository contains an `.env.example` file with all required configuration keys and safe placeholder values.

Create a local `.env` file from it.

## Windows PowerShell

```powershell
Copy-Item .env.example .env
```

## Windows Command Prompt

```cmd
copy .env.example .env
```

## Linux / macOS

```bash
cp .env.example .env
```

Open `.env` and replace the placeholder values where required.

Important configuration groups include:

- application environment
- API port
- SQL Server
- JWT
- RabbitMQ
- SMTP / email
- Stripe
- Firebase
- Google Maps
- CORS
- uploads
- Docker image versioning

Example:

```env
ASPNETCORE_ENVIRONMENT=Development
DOTNET_ENVIRONMENT=Development

API_PORT=8080
WORKER_HEALTH_PORT=8081

API_URL=http://localhost:5110

MOBILE_API_BASE_URL=http://10.0.2.2:5110
DESKTOP_API_BASE_URL=http://localhost:5110

SQL_SERVER_DATABASE=220075

IMAGE_VERSION=1.0.0

The required MindBloom demonstration database name is:

```text
220075

JWT_SECRET=replace-with-a-random-secret-with-at-least-32-characters

EMAIL_USERNAME=your-email@example.com
EMAIL_PASSWORD=your-email-app-password

STRIPE_SECRET_KEY=your-stripe-test-secret-key
STRIPE_WEBHOOK_SECRET=your-stripe-test-webhook-secret
```

Do not commit the real `.env` file.

Only `.env.example` containing safe placeholder values should be stored in source control.

---

# API URL Configuration

MindBloom has two local API paths:

- Visual Studio / `dotnet run` HTTP profile: `http://localhost:5110`
- Docker API container: `http://localhost:8080`

For everyday mobile development, prefer the Visual Studio HTTP profile on port `5110`.

The backend is available from the host computer at:

```text
http://localhost:5110
```

Flutter applications receive the API address through:

```text
--dart-define=API_BASE_URL=<url>
```

This means the source code does not need to be changed when the API address changes.

## Android Emulator

Android Emulator cannot use `localhost` to access the API running on the host computer.

Use:

```text
http://10.0.2.2:5110
```

Example:

```powershell
cd MindBloom.Frontend
.\scripts\run-mobile.ps1
```

## Desktop Application

When the desktop application and Docker API run on the same computer, use:

```text
http://localhost:5110
```

Example:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5110
```

The Docker-hosted API remains available on `http://localhost:8080` when the full compose stack is running.

---

# Docker Environment

The Docker environment contains:

- MindBloom API
- MindBloom Notifications Worker
- SQL Server
- RabbitMQ
- RabbitMQ Management UI
- persistent Docker volumes

Docker Compose exposes the API on port:

```text
8080
```

The Worker health endpoint is exposed on:

```text
8081
```

---

# Validate Docker Compose

Before starting the environment, validate the Compose configuration:

```bash
docker compose config
```

Display configured services:

```bash
docker compose config --services
```

Expected services include:

```text
sql-server
rabbitmq
notifications-worker
api
```

---

# Build the Docker Environment

From the repository root:

```bash
docker compose build
```

To rebuild without Docker cache:

```bash
docker compose build --no-cache
```

---

# Start the Docker Environment

Build and start all services:

```bash
docker compose up -d --build
```

Check container status:

```bash
docker compose ps
```

Required services should eventually report a running or healthy state.

Expected services:

```text
mindbloom-sql-server
mindbloom-rabbitmq
mindbloom-api
mindbloom-notifications-worker
```

---

# Stop the Docker Environment

Stop containers while preserving Docker volumes:

```bash
docker compose down
```

Persisted SQL Server and RabbitMQ data remain available for the next startup.

---

# Reset the Local Docker Environment

> WARNING: The following command removes Docker volumes and deletes persisted local Docker data.

```bash
docker compose down -v
```

Then recreate the environment:

```bash
docker compose up -d --build
```

Use this only when the local Docker data can safely be deleted.

---

# MindBloom Mobile Application

The mobile Flutter application communicates with the ASP.NET Core API.

Navigate to the mobile project directory:

```powershell
cd MindBloom.Frontend\mindbloom_mobile
```

Install dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

## Android Emulator

For normal Visual Studio + Android emulator development, start `MindBloom.API` with the `http` profile and then run:

```powershell
cd MindBloom.Frontend
.\scripts\run-mobile.ps1
```

The Android emulator uses:

```text
10.0.2.2
```

instead of:

```text
localhost
```

to access services running on the host computer.

The mobile development URL for this path is:

```text
http://10.0.2.2:5110
```

If Stripe mobile payments are being tested, also provide the Stripe sandbox publishable key:

```powershell
.\scripts\run-mobile.ps1 -StripePublishableKey pk_test_your_key
```

Only Stripe sandbox/test publishable keys should be used during development.

---

# MindBloom Desktop Application

Navigate to the desktop project directory:

```powershell
cd MindBloom.Frontend\mindbloom_desktop
```

Install dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Run the Windows desktop application:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

The desktop application should use:

```text
http://localhost:8080
```

when the Docker API runs on the same computer.

---

# API and Swagger

The API is available locally at:

```text
http://localhost:8080
```

In the Development environment, Swagger is available at:

```text
http://localhost:8080/swagger
```

Swagger availability depends on the application environment and must not be assumed to be enabled in Production.

---

# Health Checks

The API exposes health endpoints used by Docker.

The API container internally checks:

```text
http://localhost:8080/health/ready
```

The Notifications Worker also exposes a health endpoint through Docker.

Check all container states with:

```bash
docker compose ps
```

---

# RabbitMQ

RabbitMQ is used for asynchronous communication between the API and Notifications Worker.

The main local ports are:

```text
AMQP:
5672

Management UI:
15672
```

Open the RabbitMQ Management UI:

```text
http://localhost:15672
```

RabbitMQ credentials are configured through `.env`.

The Management UI can be used to inspect:

- exchanges
- queues
- bindings
- consumers
- connections
- message rates
- retry queues
- dead-letter queues

Do not use default development credentials in Production.

---

# Notifications Worker

MindBloom uses a separate Notifications Worker for asynchronous processing.

The Worker handles functionality such as:

- notification integration events
- email notification processing
- push notification processing
- RabbitMQ retry flows
- dead-letter handling
- duplicate-event protection
- monitoring

The Worker connects to SQL Server and RabbitMQ through Docker service hostnames.

Firebase configuration is optional for Worker startup.

If valid Firebase credentials are configured, the Firebase push service is enabled.

If Firebase credentials are not configured, the Worker continues running without Firebase push delivery instead of terminating the complete Worker process.

Firebase credentials are configured with:

```text
FIREBASE_CREDENTIALS_PATH
```

The real Firebase service-account JSON file must never be committed to source control.

---

# SMTP / Email

Email configuration is supplied through environment variables.

Important variables include:

```text
SMTP_HOST
SMTP_PORT
SMTP_ENABLE_SSL
EMAIL_USERNAME
EMAIL_PASSWORD
```

For Gmail, an application-specific password may be required instead of the normal Google account password.

Never commit a real email application password.

---

# Stripe Sandbox

MindBloom payment functionality uses Stripe sandbox/test mode during development.

Backend configuration:

```text
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
```

The secret key must be a Stripe test key.

Never commit Stripe secret keys.

## Stripe CLI

Install Stripe CLI if local webhook testing is required.

Login:

```bash
stripe login
```

Forward local Stripe webhook events to the API:

```bash
stripe listen --forward-to http://localhost:8080/api/stripe/webhook
```

Stripe CLI provides a webhook signing secret beginning with:

```text
whsec_
```

Configure that value locally as:

```env
STRIPE_WEBHOOK_SECRET=whsec_your_local_secret
```

Do not commit the real webhook secret.

---

# Firebase

Firebase is used for push notifications.

Configure:

```text
FIREBASE_CREDENTIALS_PATH
FIREBASE_BATCH_SIZE
FIREBASE_RETRY_COUNT
FIREBASE_RETRY_DELAY_SECONDS
```

`FIREBASE_CREDENTIALS_PATH` must point to a valid Firebase service-account JSON file when Firebase push notifications are enabled.

The credential file must not be committed to source control.

Without Firebase credentials, the Notifications Worker can continue operating using the configured graceful fallback behavior.

---

# Google Maps

Google Maps functionality uses:

```text
GOOGLE_MAPS_API_KEY
GOOGLE_MAPS_GEOCODING_URL
```

The API key must be supplied through local configuration.

Do not hardcode or commit a private Google Maps API key.

---

# Upload Configuration

Upload limits are configured using:

```text
UPLOAD_MAX_IMAGE_SIZE_MB
UPLOAD_MAX_DOCUMENT_SIZE_MB
UPLOAD_ROOT_PATH
```

Example:

```env
UPLOAD_MAX_IMAGE_SIZE_MB=5
UPLOAD_MAX_DOCUMENT_SIZE_MB=10
UPLOAD_ROOT_PATH=uploads
```

---

# Demonstration Accounts

The Development seed contains demonstration users for the main application roles.

## Administrator

```text
Username: desktop
Email: desktop@mindbloom.com
Password: MindBloom123!
Role: Admin
```

## Client

```text
Username: mobile
Email: mobile@mindbloom.com
Password: MindBloom123!
Role: Client
```

## Approved Therapist

```text
Username: therapist.amina
Email: amina@mindbloom.com
Password: MindBloom123!
Role: Therapist
Status: Approved
```

## Pending Therapist

```text
Username: therapist.haris
Email: haris@mindbloom.com
Password: MindBloom123!
Role: Therapist
Status: Pending
```

These accounts are intended only for demonstration and development.

The Development seed also creates representative data such as:

- therapist profiles
- therapy approaches
- therapist specializations
- therapist availability
- appointments
- payments
- memberships
- reviews
- articles
- workshops
- mood entries
- journal data
- notifications
- chat examples

The seed process is designed to be idempotent so restarting the Development environment does not intentionally create duplicate demonstration data.

---

# Logs

Show logs for all Docker services:

```bash
docker compose logs
```

Follow logs continuously:

```bash
docker compose logs -f
```

## API

```bash
docker compose logs -f api
```

## Notifications Worker

```bash
docker compose logs -f notifications-worker
```

## SQL Server

```bash
docker compose logs -f sql-server
```

## RabbitMQ

```bash
docker compose logs -f rabbitmq
```

Docker logging uses log rotation to prevent container logs from growing without limit.

---

# Rebuild a Single Service

It is not necessary to rebuild the complete Docker environment after changing only one backend service.

## API

```bash
docker compose build api
docker compose up -d api
```

Or:

```bash
docker compose up -d --build api
```

## Notifications Worker

```bash
docker compose build notifications-worker
docker compose up -d notifications-worker
```

Or:

```bash
docker compose up -d --build notifications-worker
```

---

# Recreate a Single Container

API:

```bash
docker compose up -d --force-recreate api
```

Notifications Worker:

```bash
docker compose up -d --force-recreate notifications-worker
```

---

# Common Problems

## Docker daemon is not running

Start Docker Desktop and wait until Docker reports that it is ready.

Then retry:

```bash
docker compose up -d
```

---

## Port is already in use

Default local ports:

```text
API: 8080
Worker health endpoint: 8081
SQL Server: 1433
RabbitMQ: 5672
RabbitMQ Management: 15672
```

If Docker reports that a port is already allocated, stop the process using that port or change the corresponding host-side configuration.

---

## Mobile application cannot reach API

For the normal Visual Studio HTTP profile, run:

```powershell
cd MindBloom.Frontend
.\scripts\run-mobile.ps1
```

The script checks `http://localhost:5110/health/live` on the Windows host and passes `API_BASE_URL=http://10.0.2.2:5110` to Flutter.

For Android Emulator, do not use:

```text
http://localhost:5110
```

Use:

```text
http://10.0.2.2:5110
```

If using the Docker API container instead, verify:

```bash
docker compose ps
```

and use `http://10.0.2.2:8080`.

---

## Desktop application cannot reach API

Use:

```text
http://localhost:8080
```

Run:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

Verify that the API container is running:

```bash
docker compose ps
```

---

## SQL Server does not become ready

Check status:

```bash
docker compose ps
```

Inspect logs:

```bash
docker compose logs sql-server
```

Verify SQL Server configuration in `.env`.

---

## Database migration fails

Inspect API logs:

```bash
docker compose logs api
```

After correcting the problem:

```bash
docker compose up -d api
```

For a disposable local environment, Docker volumes can be reset:

```bash
docker compose down -v
docker compose up -d --build
```

> WARNING: This deletes persisted local Docker data.

---

## RabbitMQ connection fails

Check RabbitMQ:

```bash
docker compose ps
docker compose logs rabbitmq
```

Verify:

```text
RABBITMQ_HOST
RABBITMQ_PORT
RABBITMQ_USERNAME
RABBITMQ_PASSWORD
RABBITMQ_VIRTUAL_HOST
```

Inside Docker Compose, services communicate using Docker service hostnames rather than using `localhost` to refer to another container.

---

## Startup configuration validation fails

MindBloom validates critical configuration during startup.

Inspect API logs:

```bash
docker compose logs api
```

or Worker logs:

```bash
docker compose logs notifications-worker
```

The startup error should identify the missing configuration setting without exposing its secret value.

---

## JWT configuration error

Verify:

```text
JWT_SECRET
JWT_ISSUER
JWT_AUDIENCE
JWT_EXPIRATION_MINUTES
```

Use a sufficiently long random JWT secret.

Example placeholder:

```env
JWT_SECRET=replace-with-a-random-secret-with-at-least-32-characters
```

Never store real production JWT secrets in README or `.env.example`.

---

## Email sending fails

Verify:

```text
EMAIL_USERNAME
EMAIL_PASSWORD
SMTP_HOST
SMTP_PORT
SMTP_ENABLE_SSL
```

For Gmail, ensure that a valid application-specific password is being used.

---

## Stripe requests fail

Verify:

```text
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
```

Use Stripe sandbox/test credentials in Development.

For webhook testing:

```bash
stripe listen --forward-to http://localhost:8080/api/stripe/webhook
```

---

## Firebase notifications fail

Verify:

```text
FIREBASE_CREDENTIALS_PATH
```

If Firebase is expected to be enabled, ensure that the service-account file exists at the configured path.

If Firebase is intentionally not configured, the Notifications Worker should continue running without Firebase push delivery.

---

# Docker Image Versioning

MindBloom API and Notifications Worker use separate Docker image names:

```text
mindbloom-api
mindbloom-worker
```

Recommended image tags include:

- semantic version, for example `1.0.0`
- current Git commit hash
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

The Docker Compose image version is configured through:

```env
IMAGE_VERSION=1.0.0
```

Using explicit versions makes rollback and reproducible deployment easier.

---

# Production Notes

The local Docker workflow is primarily intended for Development.

Production deployment must use production-specific:

- secrets
- database credentials
- RabbitMQ credentials
- SMTP configuration
- Stripe credentials
- Firebase credentials
- CORS origins
- HTTPS
- resource limits
- retry settings
- persistent storage
- Docker image versions

Development-only functionality such as demonstration seed data, local Stripe forwarding and Development Swagger configuration must not be relied upon in Production.

Real secrets must never be stored in:

- source code
- README
- `.env.example`
- Git history

---

# Quick Start

## 1. Clone repository

```bash
git clone <repository-url>
cd <repository-directory>
```

## 2. Create environment file

Linux/macOS:

```bash
cp .env.example .env
```

Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

Configure the required local secrets in `.env`.

## 3. Validate Docker configuration

```bash
docker compose config
```

## 4. Start backend infrastructure

```bash
docker compose up -d --build
```

## 5. Check status

```bash
docker compose ps
```

## 6. Open Swagger

```text
http://localhost:8080/swagger
```

## 7. Run Android mobile application

For the normal Visual Studio HTTP API profile:

```powershell
cd MindBloom.Frontend
.\scripts\run-mobile.ps1
```

If testing Stripe payments:

```powershell
.\scripts\run-mobile.ps1 -StripePublishableKey pk_test_your_key
```

## 8. Run desktop application

From the desktop Flutter project with the Docker API:

```bash
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

## 9. Useful local addresses

```text
API:
http://localhost:8080

Swagger:
http://localhost:8080/swagger

RabbitMQ Management:
http://localhost:15672
```

## 10. Stop environment

```bash
docker compose down
```

---

# Standard Local URLs

| Component | URL |
|---|---|
| Visual Studio API HTTP profile | `http://localhost:5110` |
| Android emulator to Visual Studio API | `http://10.0.2.2:5110` |
| Docker API from host | `http://localhost:8080` |
| Android emulator to Docker API | `http://10.0.2.2:8080` |
| Docker Swagger | `http://localhost:8080/swagger` |
| RabbitMQ Management | `http://localhost:15672` |
| Worker health port | `http://localhost:8081` |

The standard Flutter configuration variable is:

```text
API_BASE_URL
```

Mobile:

```text
API_BASE_URL=http://10.0.2.2:5110
```

Desktop:

```text
API_BASE_URL=http://localhost:5110
```

This configuration allows MindBloom to be started on another development computer without modifying Flutter source code.
