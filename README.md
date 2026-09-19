# MindBloom

MindBloom je aplikacija za mentalno zdravlje koja povezuje klijente, terapeute i administraciju kroz mobilnu aplikaciju, desktop administrativni portal i .NET backend. Sistem podrzava registraciju i autentifikaciju korisnika, terapijske profile, zakazivanje termina, placanja, clanarine, chat, notifikacije, preporuke terapeuta, edukativni sadrzaj, radionice i administratorske izvjestaje.

Repository je organizovan tako da su aktivni source projekti jasno odvojeni:

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

## Arhitektura ukratko

Backend je .NET 9 rjesenje organizovano po slojevima:

- `MindBloom.API` izlaže REST API, Swagger/OpenAPI dokumentaciju, JWT autentifikaciju, authorization politike, health check endpoint-e, metrics endpoint i SignalR hubove.
- `MindBloom.Application` sadrzi DTO-e, validatore, service abstrakcije i use-case ugovore.
- `MindBloom.Domain` sadrzi domenske entitete, enum-e i osnovne poslovne koncepte.
- `MindBloom.Infrastructure` implementira EF Core persistence, SQL Server pristup, Identity, Stripe, RabbitMQ publishing, SignalR servise, upload/geocoding i druge tehnicke servise.
- `MindBloom.Messaging.Contracts` dijeli message contract tipove izmedju API-ja i Worker procesa.
- `MindBloom.NotificationsWorker` je zaseban background proces koji konzumira RabbitMQ poruke i obradjuje email/push/integration-event delivery izvan HTTP request flow-a.

Frontend se sastoji od dvije Flutter aplikacije:

- `frontend/mindbloom_mobile` - mobilna aplikacija za klijente i terapeute.
- `frontend/mindbloom_desktop` - desktop administrativni portal.

Tipican sinhroni flow:

```text
Flutter Mobile/Desktop -> MindBloom.API -> Application -> Infrastructure -> SQL Server
```

Tipican asinhroni notification flow:

```text
MindBloom.API -> RabbitMQ -> Notifications Worker -> Email/Firebase push/SQL status
```

Realtime flow:

```text
Flutter client <-> SignalR hubs (/hubs/notifications, /hubs/chat) <-> Backend services
```

Detaljniji opis sistema je u [docs/system-architecture.md](docs/system-architecture.md).

## Preduslovi

Za lokalni razvoj preporuceno je imati:

- Git
- Docker Desktop sa Docker Compose podrskom
- .NET SDK 9.x
- Flutter SDK
- Android Studio / Android SDK za mobilni emulator
- Visual Studio 2022 sa Windows desktop workloadom za Flutter Windows build
- Stripe CLI za lokalno testiranje webhook-a
- Firebase service account JSON ako se testiraju stvarne push notifikacije

Provjera osnovnih alata:

```powershell
git --version
dotnet --version
docker --version
docker compose version
flutter --version
```

## Environment konfiguracija

Root `.env` fajl se koristi za Docker Compose i backend konfiguraciju. Nemoj commitati stvarne tajne vrijednosti.

Kreiranje lokalnog `.env` fajla:

```powershell
Copy-Item .env.example .env
```

Za finalnu evaluaciju moze biti dostavljen i odvojeni konfiguracijski paket `MindBloom-Environment.zip`. Taj paket se ne nalazi u public GitHub Release assetima niti u source repository-ju, zasticen je passwordom i sadrzi osjetljive/lokalne konfiguracijske fajlove potrebne za pokretanje evaluacijskog okruzenja. Password se dostavlja odvojeno evaluatoru. Nakon preuzimanja, evaluator treba raspakovati paket i postaviti dobijene konfiguracijske fajlove na njihove predvidjene lokacije u projektu prije pokretanja sistema. Paket, njegov password i stvarne konfiguracijske vrijednosti se ne smiju commitati niti uploadovati kao public release asset.

Minimalno provjeri i popuni vrijednosti za:

- SQL Server: `SQL_SERVER_PORT`, `SQL_SERVER_DATABASE`, `SQL_SERVER_PASSWORD`, `DB_CONNECTION`
- JWT: `JWT_SECRET`, `JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_EXPIRATION_MINUTES`
- RabbitMQ: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`, `RABBITMQ_VIRTUAL_HOST` i queue/exchange varijable
- Email: `EMAIL_USERNAME`, `EMAIL_PASSWORD`
- Stripe backend: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- Firebase Worker: `FIREBASE_CREDENTIALS_PATH`, `FIREBASE_BATCH_SIZE`, `FIREBASE_RETRY_COUNT`, `FIREBASE_RETRY_DELAY_SECONDS`
- Google Maps: `GOOGLE_MAPS_API_KEY`, `GOOGLE_MAPS_GEOCODING_URL`
- Uploads: `UPLOAD_ROOT_PATH`, `UPLOAD_MAX_IMAGE_SIZE_MB`, `UPLOAD_MAX_DOCUMENT_SIZE_MB`
- Docker image tag: `IMAGE_VERSION`

Demo baza koristi naziv:

```text
220075
```

Za Stripe sandbox integration testove koristi se dodatna process environment varijabla:

```powershell
$env:STRIPE_SANDBOX_SECRET_KEY="<YOUR_STRIPE_TEST_SECRET_KEY>"
```

Ta vrijednost mora biti Stripe test secret key koji pocinje sa `sk_test_`. Ne upisuj live key i ne commitaj test secret u repository.

## Docker backend okruzenje

Docker Compose definise cetiri glavna servisa:

- `sql-server` - SQL Server 2022, port iz `SQL_SERVER_PORT` ili `1433`
- `rabbitmq` - RabbitMQ sa management pluginom, portovi `5672` i `15672`
- `api` - MindBloom API image `mindbloom-api:${IMAGE_VERSION:-1.0.0}`, lokalni port iz `API_PORT` ili `8080`
- `notifications-worker` - Worker image `mindbloom-worker:${IMAGE_VERSION:-1.0.0}`, health port iz `WORKER_HEALTH_PORT` ili `8081`

Provjera Compose konfiguracije:

```powershell
docker compose config
```

Pokretanje kompletnog backend okruzenja:

```powershell
docker compose up -d --build
```

Provjera statusa:

```powershell
docker compose ps
```

Zaustavljanje bez brisanja podataka:

```powershell
docker compose down
```

Opcionalni destruktivni reset/troubleshooting: sljedeca komanda brise Docker volume podatke, ukljucujuci perzistentne SQL Server/RabbitMQ podatke. Nije dio normalnog startup/shutdown toka i koristi se samo kada namjerno zelis fresh lokalno okruzenje.

```powershell
docker compose down -v
```

Docker build kontekst je root repository-ja, a Dockerfile putanje su:

```text
backend/src/MindBloom.API/Dockerfile
backend/src/MindBloom.NotificationsWorker/Dockerfile
```

## Backend lokalno

Restore, build i test iz root foldera:

```powershell
dotnet restore MindBloom.sln
dotnet build MindBloom.sln
dotnet test MindBloom.sln
```

Pokretanje API-ja lokalno:

```powershell
dotnet run --project backend/src/MindBloom.API/MindBloom.API.csproj
```

Pokretanje Worker procesa lokalno:

```powershell
dotnet run --project backend/src/MindBloom.NotificationsWorker/MindBloom.Worker.csproj
```

Backend iz koda podrzava:

- REST API controller-e pod `/api`
- Swagger UI u Development modu
- health check endpoint-e `/health/live` i `/health/ready`
- metrics endpoint `/metrics`
- SignalR hubove `/hubs/notifications` i `/hubs/chat`
- JWT Bearer autentifikaciju i role/policy authorization
- rate limiting middleware

Ako se API pokrece kroz Docker Compose, standardni URL je:

```text
http://localhost:8080
```

Ako se API pokrece lokalno kroz Visual Studio/http profil, mobilni skript po defaultu cilja:

```text
http://10.0.2.2:5110
```

## Swagger/OpenAPI

Swagger UI je dostupan u Development modu:

```text
http://localhost:8080/swagger
```

Za lokalni `dotnet run` port moze zavisiti od launch profila. Ako se koristi HTTP profil na portu `5110`, Swagger je:

```text
http://localhost:5110/swagger
```

REST API dokumentacija za odbranu nalazi se u [docs/api-documentation.md](docs/api-documentation.md).

## RabbitMQ i Notifications Worker

RabbitMQ se koristi za asinhronu obradu notifikacija i integration event poruka. API objavljuje poruke, a `MindBloom.NotificationsWorker` ih konzumira iz RabbitMQ queue-ova. Worker zatim obradjuje delivery kroz email, Firebase push i povezane persistence/integration tokove.

Compose koristi RabbitMQ management UI na:

```text
http://localhost:15672
```

Queue/exchange/routing key vrijednosti konfigurisane su preko `.env` varijabli sa prefiksom `RABBITMQ_`, ukljucujuci notification exchange, email queue, integration-event queue, retry exchange i dead-letter queue konfiguraciju.

## SQL Server

SQL Server je primarni persistence store za backend. EF Core model, Identity tabele, poslovne tabele, chat, notifikacije, placanja, clanarine, radionice, clanke, journaling/mood podatke i referentne podatke dokumentuje:

[docs/database-schema.md](docs/database-schema.md)

Lokalni SQL Server port dolazi iz:

```text
SQL_SERVER_PORT
```

Database name za demo okruzenje:

```text
220075
```

## Flutter Mobile

Mobilna aplikacija se nalazi u:

```text
frontend/mindbloom_mobile
```

Osnovne komande:

```powershell
cd frontend/mindbloom_mobile
flutter pub get
flutter analyze
flutter test
```

Pokretanje preko projekta:

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:5110 --dart-define=STRIPE_PUBLISHABLE_KEY=<YOUR_STRIPE_TEST_PUBLISHABLE_KEY>
```

Pokretanje preko helper skripta:

```powershell
cd frontend
.\scripts\run-mobile.ps1
```

`run-mobile.ps1` koristi default `API_BASE_URL=http://10.0.2.2:5110`. Stripe publishable key cita iz parametra, environment varijable `STRIPE_PUBLISHABLE_KEY` ili `frontend\.env.local`.

Primjer sa eksplicitnim vrijednostima:

```powershell
.\scripts\run-mobile.ps1 -ApiBaseUrl "http://10.0.2.2:5110" -StripePublishableKey "<YOUR_STRIPE_TEST_PUBLISHABLE_KEY>"
```

Mobile `STRIPE_PUBLISHABLE_KEY` mora poceti sa `pk_test_`. Ako nije postavljen, aplikacija se pokrece, ali payment flow ostaje nedostupan za taj run.

Android Google Maps konfiguracija za source build se cita iz:

```text
frontend/mindbloom_mobile/android/local.properties
```

U taj fajl lokalno dodaj:

```text
MAPS_API_KEY=<YOUR_GOOGLE_MAPS_API_KEY>
```

Stvarni Google Maps API key se ne smije commitati u Git. `local.properties` je namjerno ignorisan/nepracen, a postojece Android Gradle postavke citaju `MAPS_API_KEY` iz tog fajla i prosljedjuju ga u Android manifest. Ovaj key je potreban da integrisana mapa lokacije terapeuta radi u Android aplikaciji. Backend `GOOGLE_MAPS_API_KEY` iz root `.env` ostaje odvojena backend konfiguracija.

## Flutter Desktop

Desktop administrativni portal se nalazi u:

```text
frontend/mindbloom_desktop
```

Osnovne komande:

```powershell
cd frontend/mindbloom_desktop
flutter pub get
flutter analyze
flutter test
```

Pokretanje:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

Desktop aplikacija po defaultu koristi:

```text
http://localhost:8080
```

Ako API pokreces lokalno na drugom portu, proslijedi odgovarajuci `API_BASE_URL`.

## Dart define vrijednosti

Aktivni Flutter projekti koriste sljedece compile-time vrijednosti:

| Projekat | Vrijednost | Svrha |
| --- | --- | --- |
| Mobile | `API_BASE_URL` | Base URL backend API-ja |
| Mobile | `STRIPE_PUBLISHABLE_KEY` | Stripe test publishable key za mobile payment sheet |
| Desktop | `API_BASE_URL` | Base URL backend API-ja |
| Desktop | `APP_ENV` | Prikaz environment oznake u admin settings dijelu |

## Stripe sandbox

Backend Stripe integracija koristi:

- `STRIPE_SECRET_KEY` - Stripe secret key za backend PaymentIntent/refund operacije
- `STRIPE_WEBHOOK_SECRET` - webhook signing secret za validaciju Stripe webhook dogadjaja

Mobile Stripe integracija koristi:

- `STRIPE_PUBLISHABLE_KEY` - publishable key koji pocinje sa `pk_test_`

Sandbox integration testovi koriste:

- `STRIPE_SANDBOX_SECRET_KEY` - test secret key koji pocinje sa `sk_test_`

Lokalni webhook primjer sa Stripe CLI:

```powershell
stripe listen --forward-to http://localhost:8080/api/stripe/webhook
```

Webhook signing secret koji Stripe CLI ispise postavi u `.env` kao `STRIPE_WEBHOOK_SECRET`. Ne koristi publishable key ili Stripe API secret kao webhook secret.

## Firebase push notifikacije

Notifications Worker koristi Firebase Admin/FCM ako je konfigurisan `FIREBASE_CREDENTIALS_PATH`. Ako path nije konfigurisan, kod registruje no-op push notification servis, pa backend moze raditi bez stvarnog Firebase credential fajla, ali realne push notifikacije tada nisu aktivne.

Konfiguracijske vrijednosti:

```text
FIREBASE_CREDENTIALS_PATH
FIREBASE_BATCH_SIZE
FIREBASE_RETRY_COUNT
FIREBASE_RETRY_DELAY_SECONDS
```

Ne commitaj Firebase service account JSON.

## Demo korisnici

Seeder kreira sljedece demo korisnike kada je seed ukljucen:

| Uloga | Username | Email | Password | Napomena |
| --- | --- | --- | --- | --- |
| Admin | `desktop` | `desktop@mindbloom.com` | `MindBloom123!` | Desktop admin portal |
| Client | `mobile` | `mobile@mindbloom.com` | `MindBloom123!` | Mobile client demo |
| Therapist | `therapist.amina` | `amina@mindbloom.com` | `MindBloom123!` | Approved therapist |
| Therapist | `therapist.haris` | `haris@mindbloom.com` | `MindBloom123!` | Pending therapist |

Ove vrijednosti su demo seed podaci, ne produkcijske tajne.

## Testovi

Backend:

```powershell
dotnet test MindBloom.sln
```

Ciljani test projekti:

```powershell
dotnet test backend/src/MindBloom.UnitTests/MindBloom.UnitTests.csproj
dotnet test backend/src/MindBloom.IntegrationTests/MindBloom.IntegrationTests.csproj
dotnet test backend/src/MindBloom.SecurityTests/MindBloom.SecurityTests.csproj
```

Stripe sandbox testovi zahtijevaju `STRIPE_SANDBOX_SECRET_KEY` u process environmentu:

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

## Build komande

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

Ako Windows build ima path/cache problem na OneDrive lokaciji, koristi kraci path ili prethodno dogovoreni `subst` workflow i ne mijenjaj aplikacijski kod zbog environment problema.

## Troubleshooting

`docker compose config` prijavljuje missing variable:

- Provjeri da root `.env` postoji.
- Uporedi `.env` sa `.env.example`.
- Ne kopiraj stvarne secret vrijednosti u README ili dokumentaciju.

API container nije healthy:

- Provjeri `docker compose ps`.
- Provjeri SQL Server i RabbitMQ health status.
- Provjeri `docker compose logs api`.

Mobile emulator ne moze dohvatiti API:

- Za Android emulator koristi `http://10.0.2.2:<port>`.
- Za Docker API default je `http://10.0.2.2:8080`.
- Za lokalni Visual Studio/http profil default skripta je `http://10.0.2.2:5110`.

Desktop ne moze dohvatiti API:

- Za Docker API koristi `http://localhost:8080`.
- Ako API radi na lokalnom launch profilu, proslijedi taj port kroz `--dart-define=API_BASE_URL=...`.

Stripe payment flow nije dostupan u mobile aplikaciji:

- Provjeri da je `STRIPE_PUBLISHABLE_KEY` postavljen i da pocinje sa `pk_test_`.
- Provjeri da backend ima `STRIPE_SECRET_KEY` i `STRIPE_WEBHOOK_SECRET`.

Stripe sandbox testovi padaju zbog missing key:

- Postavi `STRIPE_SANDBOX_SECRET_KEY` u istoj PowerShell sesiji u kojoj pokreces test.

Firebase push ne salje stvarne notifikacije:

- Provjeri `FIREBASE_CREDENTIALS_PATH`.
- Provjeri da JSON credential fajl postoji lokalno i nije commitan.

## Dokumentacija

- [System architecture](docs/system-architecture.md)
- [Database schema](docs/database-schema.md)
- [REST API documentation](docs/api-documentation.md)
- [Recommender dokumentacija](docs/recommender-dokumentacija.md)
- [Demo scenario](docs/demo-scenario.md) - preporuceni tok demonstracije za klijentske, terapeutske i administratorske workflow-e.

## Git sigurnost

Ne commitaj:

- `.env`
- Firebase service account JSON
- Stripe secret keys
- webhook signing secrets
- SQL passwords
- lokalne emulator/debug/cache fajlove
