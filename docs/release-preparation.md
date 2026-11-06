# MindBloom v1.1.1 — release preparation

Application version: **1.1.1+3** (Android versionCode 3).
Local documentation and binary packaging are verified. This guide records the
preparation checks; public download availability must be verified separately.

## Source and provenance

Public source: https://github.com/emramujezin02/rs2-mindbloom

The independent source baseline is
`8fe3d20085d77c08839b857861e92af94b7829d2` (1,663 manifest-verified files).
The application binaries were built before this history replacement from the
corresponding approved submission application sources. They were not rebuilt
from the new SHA; byte-for-byte build reproducibility is not claimed.

The sanitized-source manifest SHA-256 is
`E3F27BDB756DBEF42B66D02202861DB0DC37585B9639D220476C193D5052CFFB`.
Documentation and release tag-default changes are tracked separately
and do not change Flutter application code or the packaged binaries.

Do not push the original dirty repository or reconnect its history. Private
runtime uploads and environment archives are absent from the clean current
source. Old known GitHub commit trees still returned metadata during the
security review; complete server-side historical removal is not established.
GitHub Support follow-up and private credential exposure assessment remain open.
Do not reuse or distribute a historical private environment archive.

## Public package and verified artifacts

`MindBloom-Release-v1.1.1.zip` contains exactly 22 files:

```text
Android/app-release.apk
Windows/mindbloom_desktop.exe
Windows/*.dll
Windows/data/app.so
Windows/data/icudtl.dat
Windows/data/flutter_assets/...
```

- ZIP size: **53,150,000 bytes**.
- ZIP SHA-256:
  `B0420D73AF20D402BC683D9647ECA7BA57D59CFA4FAC45E539D00B5B294E7116`.
- APK: **75,330,095 bytes**, package `com.example.mindbloom_mobile`,
  versionName `1.1.1`, versionCode `3`; not debuggable.
- APK SHA-256:
  `85F54100E6D32C7FFE53BAD71B17487D310772FB460BBE962D808FE4475203A1`.
- Complete Windows runtime: **21 files, 40,777,106 bytes**.
- EXE product/file version: `1.1.1+3`.
- EXE SHA-256:
  `43A3F3B667EDD221BBEF62B4A187FC60673E9C31BFD70218BAB970E18D95260F`.
- Windows AOT `data/app.so` SHA-256:
  `280DCF37664BA62E04FA06DAEC7AE7027F6C642B89C6D53CD917599701BA37C1`.

All 22 ZIP entries were read and SHA-256 compared with their original artifacts.
The archive has no unexpected/duplicate entries or unsafe traversal paths.
Roboto Regular/Bold, license and notice are present in
`Windows/data/flutter_assets/assets/fonts/`. PDFium, Flutter and native plugin
DLLs, ICU data and the complete assets directory are included.

Do not distribute only the EXE. No source, Git history, real `.env`, private
configuration, runtime documents, QA evidence, backups, Docker images or old
Release ZIPs are included. Source and setup instructions belong in the public
repository, not in this binary-only archive.

## Private configuration

Copy `.env.example` to a local ignored `.env` and supply fresh private values.
Template values are examples, not operational credentials. Never log secrets,
include them in screenshots, commit them, or put them in a Release asset.

Configure SQL password/database, JWT signing secret, RabbitMQ credentials and
queue/exchange names. Stripe uses sandbox keys only. Email requires the intended
SMTP account. Firebase requires a private service-account file supplied separately
and made available at the configured container path; the base Compose file does
not supply that secret mount. A path alone does not establish working push delivery.

Android source builds additionally require the approved local Maps configuration
and a Stripe sandbox publishable key, never a Stripe secret key. Keep local build
inputs ignored and redact logs containing encoded key arguments. Existing binaries
retain their approved configuration; this packaging task did not change it.

## Docker source builds

No sanitized API image build has completed successfully. Two controlled attempts
were cancelled after QA RabbitMQ became unhealthy; compilation failure was not
established. No prebuilt API or Worker distribution is promised and no Docker
image is included in the package.

Compose defaults both application image tags to `1.1.1-source`, meaning
**build locally first**. Per-service versions override legacy `IMAGE_VERSION`.
The clean-checkout helper defaults to the same local source-build tag.
Build API then Worker, not in parallel:

```powershell
$env:API_IMAGE_VERSION = '1.1.1-source'
$env:WORKER_IMAGE_VERSION = '1.1.1-source'
docker compose config --quiet
docker compose build api
docker compose build notifications-worker
```

Do not claim image security/runtime verification from source checks alone.
If a build fails, stop before startup and preserve existing data.
The following installation procedure has not been executed by this packaging task.

## Fresh evaluator installation

Use a genuinely fresh machine/installation, not the owner's host or existing
Compose project. Explicit names in Compose mean `-p` alone does not isolate it.
Never remove volumes to manufacture a fresh database.

1. Install Docker Desktop/Compose and Git. Obtain the clean reviewed source.
   Privately configure `.env` from the public template.
2. Choose an unused evaluator database and build both application services
   successfully as described above.
3. Start dependencies on that fresh installation only:

```powershell
$env:SQL_SERVER_DATABASE = 'MindBloomEvaluation111'
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:DOTNET_ENVIRONMENT = 'Development'
$env:SEED_ENABLED = 'false'
docker compose config --quiet
docker compose up -d --no-build sql-server rabbitmq
docker compose ps
```

Wait for dependency health. Confirm that the selected database is new/empty.
Development API startup invokes migrations even when seed is false.
Only for that deliberate first initialization:

```powershell
$env:SEED_ENABLED = 'true'
docker compose up -d --no-build api
Invoke-WebRequest http://localhost:8080/health/ready
```

After successful initialization, disable the full seed and replace only this
new evaluator API's runtime environment:

```powershell
$env:SEED_ENABLED = 'false'
docker compose up -d --no-build --no-deps --force-recreate api
docker compose up -d --no-build notifications-worker
Invoke-WebRequest http://localhost:8080/health/live
Invoke-WebRequest http://localhost:8080/health/ready
```

Do not apply this procedure to `220075` or another existing database.
Production startup does not run the Development bootstrap.
Keep seed disabled for later starts; inspect failure logs without deleting data.
The source includes 85 migrations and Task 19's idempotent article seed and
explicit therapy links; verify a fresh installation rather than assuming counts.
Demo accounts are documented in the root README and must remain confined to
evaluation, not exposed production installations.

## Android and Windows use

Android Release targets `http://10.0.2.2:8080`, the standard Android emulator's
host alias. INTERNET permission is present and release HTTP is scoped to that
host. This does not establish physical-phone connectivity. Debug/Profile use
the existing local-development default. The current Release signing setup uses
the existing debug certificate and is not production signing.

Windows targets `http://localhost:8080`. Install Microsoft Visual C++ 2015-2022
Redistributable x64 where required. Extract the complete Windows directory before
launching `mindbloom_desktop.exe`. Normal login uses the recipient's configured
backend; do not use the owner's database for recipient smoke tests.

For source builds, use the Flutter versions/lockfiles in the repository, existing
Windows C++/CMake tooling and Android SDK. Preserve dependencies. Build serially:

```powershell
# frontend/mindbloom_mobile; approved private build inputs supplied locally
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:8080

# frontend/mindbloom_desktop
flutter pub get
$env:CMAKE_BUILD_PARALLEL_LEVEL = '1'
flutter build windows --release --no-pub --dart-define=API_BASE_URL=http://localhost:8080
```

The mobile command alone does not supply payment configuration: without the
private sandbox publishable-key input, the payment flow is unavailable.
Do not use `--no-pub` for the Android retry that must refresh plugin registration.

## Verification evidence and limitations

Previous phases passed 23 focused desktop UTC tests and 8 PDF tests. All ten
B/H/S Latin characters survived text extraction and seven PDF pages were visually
inspected. Final Windows AOT/font assets contain those changes, but the final
executable was not launched to protect existing credential storage.
Do not present earlier PDF rendering tests as a final-binary GUI smoke test.

The isolated final QA API passed 47 runtime checks; that was a previous QA image,
not the uncompleted sanitized API image. Notification API/read-state checks and
fake-timer polling tests do not establish real Flutter GUI polling or external
email/Firebase delivery. Fresh-install, physical-device, complete end-to-end GUI
and real Stripe sandbox payment acceptance remain separate verification steps.

USD labels and per-currency dashboard reporting preserve amounts without currency
conversion. Reserved appointment payment uses stored Appointment.Price. No live
payment is claimed. Footer contacts are demonstration data; official social
profiles are unconfigured and legal pages remain drafts.

## Publication gate

Prepared tag: `v1.1.1`.
Prepared title: **MindBloom v1.1.1 - November Submission**.
Prepared description: [release-notes-v1.1.1.md](release-notes-v1.1.1.md).

Publication follows the separately approved final-publication procedure.
The final Release must target the reviewed
documentation commit. See [v1.1.1](https://github.com/emramujezin02/rs2-mindbloom/releases/tag/v1.1.1). Use DRAFT -> upload ZIP -> verify asset -> publish ->
anonymous download and SHA-256 verification. Do not mark a DLWMS link ready
before that final public download check.
