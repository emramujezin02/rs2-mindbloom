# Reviewed resubmission — v1.1.0

Approved version: `v1.1.0`; Android and Windows Flutter version: `1.1.0+2`.
Release preparation started from Task 23 commit `cbe830b`. This document does
not mean that new binaries have been built, tagged or published. Build results
and unresolved gates are recorded below. Never re-label a previous binary as
the new version. Keep GitHub `v1.0.0` and all its assets unchanged.

Current status (2026-11-01): Android and Windows **1.1.0+2** builds succeeded,
and the public ZIP is packaged and integrity-verified. No new packaged GUI
smoke test or clean-machine install was performed. Commit, push, tag and GitHub
publication are still awaiting explicit approval. Earlier entries below retain
the chronological build failures and recovery evidence; they are not the final
artifact status.

## Separate an existing installation from a fresh installation

The owner's running `220075` database already has 85 applied migrations,
eight published articles and four featured-article links. Do not initialize,
migrate or seed it as part of packaging. Do not run the commands below on
that machine's existing Compose project or volumes.

A new evaluator installation must build the API and Worker from this reviewed
source. No public prebuilt `1.1.0` Docker images are promised. The two build
contexts and Dockerfiles are defined in `docker-compose.yml`. The script
`build-images.ps1 -Version 1.1.0` builds both versioned images serially and no
longer moves the `latest` tag. It requires a clean reviewed checkout to avoid
labelling uncommitted source with a clean commit tag. These images are compatible source builds;
the owner's already-created containers are a separate runtime deployment.

The base Compose file intentionally retains the existing container/volume
names. `-p` alone does not isolate those explicit names. Use a genuinely fresh
machine/installation for the following procedure, not an additional project
on the owner's host. Do not remove existing volumes to make it appear fresh.

## Fresh evaluator initialization — not executed on 220075

1. Install Docker Desktop, Git and the platform prerequisites in the root
   README. Obtain the reviewed source revision and the private configuration
   package separately. Do not use missing-variable or placeholder secrets.
2. Unlock the configuration locally using the archive application's password
   prompt; the password must arrive through a separate private channel. Place
   the `.env` file at the repository root. Never publish the extracted file.
3. In the new installation's PowerShell session, explicitly choose the new
   images, Development bootstrap mode and an unused evaluation database name:

   ```powershell
   $env:IMAGE_VERSION = '1.1.0'
   $env:ASPNETCORE_ENVIRONMENT = 'Development'
   $env:DOTNET_ENVIRONMENT = 'Development'
   $env:SQL_SERVER_DATABASE = 'MindBloomEvaluation110'
   $env:SEED_ENABLED = 'false'
   docker compose config --quiet
   docker compose build api notifications-worker
   docker compose up -d --no-build sql-server rabbitmq
   ```

   The database name is an explicit fresh-install example, not a request to
   change the owner's `220075` connection. The Compose API/Worker connection
   strings derive from `SQL_SERVER_DATABASE` and use `sql-server,1433`.
   Wait for SQL and RabbitMQ health before continuing.
4. Only after confirming that the selected database is absent/new and has no
   user/business data, opt in to the first full demonstration seed:

   ```powershell
   $env:SEED_ENABLED = 'true'
   docker compose up -d --no-build api
   docker compose logs --tail 100 api
   Invoke-WebRequest http://localhost:8080/health/ready
   ```

   Development startup applies pending migrations before the seed, independently
   of `Seed__Enabled`. `ApplicationDbSeeder` creates demonstration users and
   business records; its article section calls `TherapyApproachArticleSeeder`.
   The latter uses stable SeedKeys and explicit featured links. This is a
   deliberate first initialization of a new database, not a safe update
   procedure for an existing database. Production/Testing startup does not
   perform this Development bootstrap.
5. After successful initialization, disable the full seed and recreate only
   the new evaluator API with the new runtime setting:

   ```powershell
   $env:SEED_ENABLED = 'false'
   docker compose up -d --no-build --no-deps --force-recreate api
   docker compose up -d --no-build notifications-worker
   docker compose ps
   Invoke-WebRequest http://localhost:8080/health/live
   Invoke-WebRequest http://localhost:8080/health/ready
   ```

   Ordinary `docker start` does not replace an existing container's environment.
   Keep `SEED_ENABLED=false` on later invocations. Avoid automatic startup on
   failure until logs have been reviewed; do not delete data to retry a seed.

Expected fresh-data checks: 85 applied migrations at this source revision;
eight published articles; four educational articles in `Therapy Approaches`;
four valid featured links; old/demo reviews without automatic demographic
consent. Compare the public article and therapy-approach DTOs using the routes
documented in the API. Verify counts in SQL read-only. The Task 19 migration
and seed passed isolated tests in earlier work; this exact new Compose
installation procedure has not been executed in Task 24.

## Desktop and Android

- Android package: `com.example.mindbloom_mobile`, versionName `1.1.0`,
  versionCode `2`. Keep the existing signing configuration. The project still
  uses its existing debug signing key for Release; this is not a new
  production signing arrangement. Upgrading an installed APK requires the
  same certificate; versionCode alone does not establish signing continuity.
- Android Release API: `http://10.0.2.2:8080`, the Android emulator's host alias.
  Release cleartext HTTP is scoped to `10.0.2.2`, not globally enabled.
  Debug/Profile retain `http://10.0.2.2:5110`. `API_BASE_URL` overrides remain
  available; HTTPS is required for other hosts under the current policy.
- Windows API: `http://localhost:8080`, not the Android alias.
- Android emulator and native builds must not run concurrently on the 8 GB
  preparation host. No application login or business GUI test is authorized
  against the owner's database by these packaging instructions.

Build commands, after resource checks, from each respective Flutter directory:

```powershell
# frontend/mindbloom_mobile
flutter build apk --release
# Optional existing sandbox payment support requires a valid pk_test_ public
# key passed privately as STRIPE_PUBLISHABLE_KEY; never pass a Stripe secret.

# frontend/mindbloom_desktop
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:8080
```

Without a configured Stripe publishable key the existing mobile payment flow
is unavailable; login does not depend on that key. Do not claim payment
readiness for an APK built without it. No real payments are part of release QA.

Install the newly verified APK with `adb install -r <path-to-new-apk>`. Start
an Android emulator through Android Studio on a host with sufficient memory;
do not use a physical phone and expect `10.0.2.2` to be its API address.
Extract the entire Windows folder before launching `mindbloom_desktop.exe`.
Keep DLLs, `data/app.so`, `data/icudtl.dat`, `data/flutter_assets` and the
other generated runtime files beside the executable. Do not package only EXE.

## Packaging and verification gates

Use the final user-approved archive layout (the old v1.0.0 ZIP stays unchanged):

```text
Android/MindBloom-v1.1.0.apk
Windows/mindbloom_desktop.exe
Windows/*.dll
Windows/data/...
README.txt
```

Use `MindBloom-Release-v1.1.0.zip` only after both new builds succeed. Preserve
the original executable name and all runtime dependencies. Include a short
README with API addresses, startup prerequisites and known limitations.
Exclude environment files, private keys, logs, `.git`, tests and build caches.
Test the archive and verify every entry's SHA-256 against the original files.
A launch of the extracted Windows app is a separate GUI smoke test; do not
claim it has passed from archive/hash checks alone. Verify
Android version/manifest/network policy from the actual new APK, not only
source YAML. Record file sizes, UTC build times and the reviewed source state.

## Private environment package

`MindBloom-Environment.zip` is an existing tracked encrypted package, not an
ordinary release asset. Listing metadata shows one `.env` entry with AES-256
encryption. Do not expose the password in chat, command-line arguments, Git
or release notes. Encryption metadata alone does not prove successful
decryption, CRC/integrity or current variable values. Use the local 7-Zip GUI
password prompt for a private test; do not upload its contents to a service.

The archived data dates from the previous submission. `IMAGE_VERSION` may be
old; use the explicit process override above. `SEED_ENABLED` may be absent;
the new Compose default is false. Compare the decrypted configuration locally
with `.env.example` and README's required-variable list, without logging
values. Do not replace the package or rotate secrets without authorization.
Firebase credentials, Stripe keys and other external-service files must be
provided separately where required; the package listing contains only `.env`.

The current Compose file does not mount a Firebase credential file. The Worker
uses its existing no-op push fallback if the configured file is absent. A
credential path in `.env` alone does not enable native Firebase push inside
Docker. This does not prevent database notifications and Flutter polling, but
real push delivery is not verified or promised by these instructions. A
separate approved read-only secret mount would be needed for real push.

## Known limitations carried forward

- Task 23: 1,178 unique automated PASS; 18 PASS / 3 PARTIAL professor points.
  Full registration/admin verification and one live notification-to-emulator
  journey remain unverified as complete GUI flows due to memory constraints.
- Contacts are clearly demonstration data; official Instagram/Facebook/YouTube
  accounts are unconfigured and their icons intentionally inactive.
- Legal pages are working drafts, not legally approved documents.
- Therapist registration still labels its price KM while payment currency is
  USD. No conversion or price correction is introduced by this release task.
- An isolated real Worker shutdown raised NullReferenceException in resource
  cleanup. It requires separate reproduction/review; a production regression
  has not been established. No business-code patch is included here.

## Publication — requires separate approval

Release notes are prepared in [release-notes-v1.1.0.md](release-notes-v1.1.0.md).
Do not tag `cbe830b` as the final release: it lacks these release-preparation
changes. After review, the user must approve the final release commit, push,
tag and publication separately. Recheck artifact provenance against that
commit; rebuild if relevant source/configuration changed.

After actual publication, anonymously fetch the new release page and assets,
verify downloaded hashes and supply the real version-specific URL for DLWMS.
There is no final new DLWMS link yet. Never substitute the old `v1.0.0` page.

Private archive verification is a user-local action: open the unchanged
`MindBloom-Environment.zip` in 7-Zip File Manager, select **Test**, and enter
the password only in its local password dialog. A successful test establishes
decryption/integrity, not configuration freshness. Compare required variable
names and privately inspect values against `.env.example` without screenshots
or logs of secrets. Keep the new `IMAGE_VERSION=1.1.0` process override and the
fresh-database-only seed procedure. Do not replace the archive automatically.

## Task 24 execution results

Date: 2026-10-31, Europe/Sarajevo. Initial checkout was clean at `cbe830b`
(`verify all review requirements`). Both version changes and the minimal
Compose/build-script changes were explicitly approved before editing.

| Check executed in Task 24 | Result |
|---|---|
| Mobile `flutter analyze --no-pub` | PASS, no issues, 194.7 s |
| Desktop `flutter analyze --no-pub` | PASS, no issues, 61.7 s |
| Mobile API configuration/footer/blog tests, serial | 81 PASS, 0 FAIL, 0 SKIP |
| Desktop pagination/article-picker/private-document tests, serial | 15 PASS, 0 FAIL, 0 SKIP |
| Backend timezone/completion/review-demographics/dashboard unit tests | 78 PASS, 0 FAIL, 0 SKIP; existing unchanged-source assemblies, `--no-build` |
| E2E configuration guard tests | 8 PASS, 0 FAIL, 0 SKIP; existing assemblies, `--no-build`, no SQL writes |
| Full solution build with one MSBuild worker, shared compilation off, 384 MB GC heap limit | FAILED: Roslyn System.OutOfMemoryException compiling Infrastructure; 56.21 s |
| Compose syntax and sanitized resolved configuration | PASS; images 1.1.0, seed=false, API host port 8080, Worker host port 8081 |
| PowerShell build script syntax | PASS, zero parser errors |
| Existing public v1.0.0 ZIP checksum and archive test | PASS; not a new release artifact |
| New Android Release build and binary checks | Latest: second controlled attempt interrupted after healthcheck timeouts; registrant issue fixed; no new APK. See follow-up below. |
| New Windows Release build and extracted GUI launch | BLOCKED / NOT RUN for the same reason |
| New combined ZIP, extraction and checksums | BLOCKED; neither new native build is ready |
| Decrypted private environment-package integrity/configuration | NOT VERIFIED; password was not requested in chat or passed on a command line |
| Fresh Compose initialization, migrations and full seed | NOT RUN in Task 24; source procedure reviewed, earlier isolated migration/seed evidence retained |

There are **182 passing executed test cases in this Task 24 selection**. They
overlap the prior Task 23 coverage; do not add them to 1,178 as new unique
project tests. New full-suite SQL/Worker/GUI tests were not run. The build
failure is separate from test-case results; its 49 diagnostic lines come from
the compiler's out-of-memory stack, not 49 established source defects.

Available RAM varied from approximately 510 to 1,663 MB during these serial
checks (862 MB at the initial release metadata check). The memory-limited
solution build exhausted its configured heap; the limit was not increased and
native builds were not forced. No emulator or Docker image build was started.
No previously built APK or EXE is represented as version 1.1.0. Existing
outputs and old archives have not been deleted or replaced.

Read-only final SQL counts match the Task 23 closeout: 85 migrations, eight
published articles, one category, four approaches/featured links, two reviews
with zero demographic consents, five users, six appointments, one client
membership, five direct payments, four notifications, zero outbox rows,
three refresh tokens and 64 security audits. This is an aggregate check, not
a new all-row hash comparison. No migration, seeder, login or business request
was sent to the owner's database. The initial SQL control wrapper had an LF
terminator error after returning its counts; it was corrected and the SELECT
probe completed successfully without database changes.

All four existing Docker containers are healthy, with the same container IDs
as the retained Task 23 snapshot. No restart/recreate/stop command was executed
by this task. Existing image deployments are not claimed to be new 1.1.0 images.

GitHub v1.0.0 release ID 392214266 and asset ID 575491073 were read only.
Final checks confirm identical release ID, body, update timestamp, asset IDs,
asset digests and local v1.0.0 tag. The old public ZIP is 51,959,707 bytes,
SHA-256 `E46D8B98D9C47CD9BFE337FD9A6698A12776C42373FBB1A1E8C5E6624675FA2F`.
Its complete 18-file/two-directory archive passes `7z t`; its Mobile/Windows
structure was retained in the new packaging plan.

The encrypted environment archive is unchanged: 1,626 bytes, SHA-256
`35ABE4EDDA7CA4423BE0A8B91836EEA814F13C1EE5B5AB99C55875D774640BB9`.
The current *local plaintext* `.env` has `IMAGE_VERSION=1.0.0`; it was not
changed. This does not establish the encrypted archive's current values. The
explicit `IMAGE_VERSION=1.1.0` process override avoids that known stale tag.

Execution artifacts and original public ZIP are outside Git in
`%TEMP%/MindBloomTask24-20261031-181416`. Key logs: `mobile-analyze.log`,
`desktop-analyze.log`, `mobile-tests.jsonl`, `desktop-tests.jsonl`,
`backend-build.log`, `backend-unit.log`, `backend-configuration.log`,
`compose-sanitized.json`, `database-readonly-counts-final.log` and
`v1.0.0-unchanged.json`. No private environment contents were included in them.

**Release readiness: BLOCKED.** Source/configuration and release-description
preparation can be reviewed, but new APK, Windows runtime, combined ZIP and
their checksums are not ready. Before publication: supply sufficient build
resources; rebuild/verify both native artifacts serially; complete the private
configuration check; review outstanding GUI limitations; review and commit the
exact release source; then obtain separate push/tag/release approval. No new
tag, GitHub release or final DLWMS URL has been created.

### Follow-up resource check before native builds

The next continuation preserved all eight modified and two new Task 24 files;
no previous successful test suite or analysis was repeated. Read-only resource
checks on 2026-10-31 recorded:

- Physical RAM: 1,020 MB available / 7,933 MB total.
- Commit charge: 16,606 MB / 28,413 MB limit, 11,806 MB headroom.
- Pagefile: 20,480 MB allocated, 2,605 MB used, 3,473 MB peak.
- System memory compression working set: approximately 892 MB.
- C: free space: 146.58 GB.
- No Java/Gradle/MSBuild/native build processes or emulator were found.
  Four Dart processes belong to active IDE sessions; none was terminated.
- All four existing Docker services are healthy. No service was stopped or
  reconfigured; the current source base remains `cbe830b` plus Task 24 edits.

Commit/pagefile capacity is not exhausted, but that does not remove the risk
of paging stalls to SQL Server with only about 1 GB physical headroom. Given
the earlier SQLPAL/resource incidents, native builds remain BLOCKED pending
more physical memory. No new Android/Windows build was attempted in this
follow-up, and no new ZIP was created. The user was asked to close unnecessary
Edge and extra VS Code windows themselves, aiming for approximately 2.5 GB
available physical memory as a safer reserve for this particular host. This
is an operational target, not a universal Flutter minimum. No arbitrary low
heap limit was applied and no existing application process was stopped.

After the user reported closing additional applications, the next read-only
check found **785 MB available physical RAM**, 11,679 MB commit headroom and
146.58 GB free disk. All four Docker services remained healthy; no Java,
MSBuild or emulator process was found. The user's explicit condition of at
least 2.5 GB available RAM was not met. No native build was started. The safe
alternatives are to make sufficient RAM available without disturbing existing
services, or perform serial native builds on a separate adequately resourced
host using the same reviewed source/configuration. No process/service was
terminated and no database or Docker configuration was changed.

### Controlled Android Release attempt — 2026-10-31

The user subsequently approved one monitored Android attempt without requiring
2.5 GB free physical RAM, and explicitly required stopping after its result
before any Windows build. Initial checks found 1,473 MB available physical
RAM, 11,410 MB commit headroom, a 20 GB Windows pagefile (2,862 MB used),
146.44 GB free disk and all four existing containers healthy. Git still had
the expected eight modified and two new Task 24 files at base `cbe830b`.

The existing APK was copied, not deleted, to the first attempt directory as
`previous-app-release.apk`. Its original SHA-256 and size were recorded.
No project Gradle, signing, WSL, pagefile, database or Docker configuration
was changed. A hidden external PowerShell runner applied only these process
runtime options:

```text
GRADLE_OPTS=-Dorg.gradle.workers.max=1 -Dorg.gradle.parallel=false
```

The Gradle daemon command confirmed the existing `-Xmx2G`; no 384 MB limit was
applied. The default application target `lib/main.dart` and the normal three
Android ABIs were used, without an API_BASE_URL override. The existing valid
sandbox publishable key was supplied using an external define JSON containing
only that public client configuration; no secret Stripe key was passed.

The first Flutter CLI invocation exited before Gradle because the PowerShell
launcher incorrectly passed the define-file argument. Its original logs were
preserved. The launcher argument was corrected, then **one actual Gradle
Release compilation** ran from approximately 19:04:54 to 19:10:03 Sarajevo time.
`assembleRelease` reported 305.6 seconds and exit code 1.

**Actual failure, not an inferred RAM failure:**

```text
Execution failed for task ':app:compileReleaseJavaWithJavac'.
GeneratedPluginRegistrant.java:49:
package dev.flutter.plugins.integration_test does not exist
```

The runner used `flutter build apk --release --no-pub` with the external public
define file. Inspection of the local Flutter 3.44.4 SDK established that
`FlutterCommand.regeneratePlatformSpecificToolingIfApplicable` returns without
regenerating when `shouldRunPub` is false. The ignored generated Android
registrant predated this attempt and still registered IntegrationTestPlugin.
The plugin metadata marks `integration_test` as `dev_dependency=true`, and
the Gradle PluginHandler correctly omits that plugin from Release dependencies.
The stale registrant and Release dependencies therefore disagreed. The chosen
`--no-pub` invocation caused this stale-generated-file problem; it is not a
demonstrated application business-code defect or a missing package to add.

The minimal proposed next attempt is the normal `flutter build apk --release`
**without `--no-pub`**, retaining one-worker runtime settings and the same
private public-key input. Flutter should then regenerate the Release registrant,
excluding dev-only plugins. Do not manually edit the generated Java file,
remove integration_test, upgrade plugins, run clean or delete caches. This
repair/retry has **not been executed**, because the user requested stopping
after this build for review.

Eight resource samples were recorded during the actual compilation. Lowest
observed available physical RAM was 300 MB; lowest observed commit headroom
was 10,220 MB. Paging occurred, but every recorded Docker health sample remained
healthy and restart counts stayed API 1 / Worker 2 / SQL 0 / RabbitMQ 0.
There was no out-of-memory error in this Android build and no forced build
termination. The Gradle process exited after the failed build.

The output APK remained the **old** 75,330,095-byte artifact, SHA-256
`7B7260DBAC60422AB19FF06A05BB9D362DDBDA9C84F64C61072C14AE3D9C2B1D`.
No new 1.1.0 APK exists from this attempt. New version/manifest/signature/API
binary checks consequently remain unperformed; that old hash must not be
presented as a v1.1.0 release checksum. No Windows build, emulator, additional
test suite or new ZIP was started.

Logs are retained outside Git under
`%TEMP%/MindBloomTask24-20261031-181416/controlled-android-20261031-190454-validated/`:
`build.log`, `build-error.log`, `started.json`, `finished.json`, `launcher.json`
and `resource-monitor.jsonl`. The initial CLI wrapper failure and original APK
backup are in sibling `controlled-android-20261031-190407/`. Private runtime
define files are not release assets or Git files.

Current Android status is **FAILED — stale generated plugin registration**,
superseding the earlier NOT RUN/resource-blocked entry. Windows and ZIP remain
not built. No commit, push, tag or publication was performed; v1.0.0 and
existing services/data were not changed. Await user review before retrying.

### Second controlled Android attempt — plugin generation fixed, resource stop

The user explicitly approved a second attempt without `--no-pub`. Existing
Task 24 changes were preserved; no previous tests or full project analysis
were rerun. Initial available RAM was 1,049 MB, commit headroom 11,443 MB,
disk free 145.97 GB; all four services were healthy and no Java/Gradle or
emulator was running.

The command was:

```powershell
$env:GRADLE_OPTS = '-Dorg.gradle.workers.max=1 -Dorg.gradle.parallel=false'
flutter build apk --release --dart-define-from-file=<private-public-key-json>
```

The external JSON held only the existing sandbox publishable key, without an
API_BASE_URL override or any Stripe secret. Existing `-Xmx2G` was confirmed
on the actual Gradle daemon. No permanent Gradle, signing, application,
dependency declaration, WSL or pagefile setting was edited. The standard
Flutter dependency/tooling step regenerated the ignored Android Java
registrant at the beginning of this build; the integration_test registration
was absent afterwards. The first attempt's compile error was therefore
corrected without manual editing or deleting caches.

Start: **2026-10-31 19:20:30 Europe/Sarajevo**. Controlled stop:
**19:31:55**, after **684.5 seconds (11 minutes 24.5 seconds)**. The process
was active and using CPU; the stop was not based merely on elapsed time or
on a fixed free-RAM threshold.

Ten resource samples recorded a lowest available RAM of 423 MB, lowest commit
headroom of 8,358 MB, and a peak of 34,421 pages-in/second with 4,928 page-read
operations/second. The Gradle Java process grew to approximately 2,438 MB of
private commit including its heap/native overhead. Monitoring commands slowed
and existing-container healthchecks began timing out. At the decision point,
API/Worker/SQL had three consecutive failed checks each and RabbitMQ had six,
although their aggregate status still said healthy. Only the verified new
build process tree, rooted at PID 17540, was terminated using the user-approved
safety stop. Termination succeeded; the Gradle daemon PID 4976 was included.
No existing service or unrelated user process was terminated.

**Result: INTERRUPTED for observed system resource/health degradation.**
There was no new Java compilation error and no out-of-memory exception in the
captured second-build log before the stop. The only logged compatibility
warning remained the existing stripe_android/KGP warning. A normal build exit
code/finished.json was not produced because the runner was deliberately stopped;
`controlled-stop.json` and `attempt-summary.json` record that fact instead.

The health impact must not be hidden: API and Worker became unhealthy after
the timeout streaks, and RabbitMQ subsequently became unhealthy. SQL healthchecks
also timed out, while its reported status remained healthy. All four services
then recovered to healthy without manual restart/recreate. The Worker
**automatically restarted once**, count **2 → 3**; API remained 1, SQL 0 and
RabbitMQ 0. Worker incident logs contain timeout/broker-unreachable exceptions
and a shutdown/start sequence. No new SQLPAL fatal marker was found in the
reviewed SQL incident-log window. This is an observed resource incident,
not proof that an application-code change is required.

After recovery, read-only SQL aggregates still match the retained state:
85 migrations, 8 articles, 4 valid featured links, 2 reviews, 5 users,
6 appointments, 1 client membership, 5 payments, 4 notifications, 0 outbox,
3 refresh tokens and 64 security audits. This is not an all-row hash comparison.
No migrations, seed or business writes were initiated by the build task.

No new APK was completed. Both the current output and the preserved previous
APK still have SHA-256
`7B7260DBAC60422AB19FF06A05BB9D362DDBDA9C84F64C61072C14AE3D9C2B1D`
and the current output remains 75,330,095 bytes. This is the old APK, not
v1.1.0. New APK version, manifest, signing and embedded-URL checks cannot be
reported as passed. Debug/Profile/desktop source settings were not changed.

Evidence directory:
`%TEMP%/MindBloomTask24-20261031-181416/controlled-android-second-20261031-192029/`.
It preserves `build.log`, `build-error.log`, `registrant-before.java`, runtime
metadata, resource samples, controlled-stop/summary JSON, health snapshots,
private incident logs and `database-counts-after-recovery.log`. Runtime key
files/logs are not Git or release assets. Read-only GitHub checks again confirm
unchanged v1.0.0 release ID/body/update time/assets/digests and local tag.

Windows build and ZIP remain unstarted. No new retry is authorized by this
result. Before a further attempt, review a resource window that reduces
concurrent host pressure; there is no demonstrated reason to patch business
code, remove integration_test or change signing. Do not repeat the same load
without reviewing this health incident. Await user review; no commit, push,
tag or GitHub Release was performed.

### Scenario B preparation — 2026-10-31 (blocked before build)

The user subsequently approved a fresh backup, an all-table baseline, graceful
stop/start of the four existing MindBloom containers, and one Android attempt.
Windows build, ZIP packaging, Docker Desktop/WSL shutdown and forced container
termination remain unauthorized.

All four containers were initially healthy. There were no active user SQL
requests or open user transactions, no outbox records, and no ready/unacked
RabbitMQ messages (72 queues). The next-two-hour reminder and refresh-token
cleanup checks found no candidates. Container IDs, image IDs, restart policies,
mounts, networks and port mappings were saved outside the repository without
secrets; API and Worker both retain `Seed__Enabled=false`.

A new `COPY_ONLY, CHECKSUM` backup succeeded and passed
`RESTORE VERIFYONLY ... WITH CHECKSUM`. Both copies have identical SHA-256:

- Host: `C:/Users/emram/AppData/Local/MindBloom/Backups/220075/Task24-20261031-210018/220075-task24-scenario-b-20261031-210018.bak`
- Container: `/var/opt/mssql/backup/220075-task24-scenario-b-20261031-210018.bak`
- Size: **17,948,672 bytes**.
- SHA-256: `3746699ECE7163E517C4A105802246EFF66C9F64758BF7578AEA54D035C598BE`.

The existing read-only helper was run with child-process TEMP/TMP pointing at
a new evidence directory, preserving the original Task 23 baseline. All **57
tables** were hashed using sorted row hashes. Baseline and subsequent quiescent
checks agree: 85 migrations, no pending migrations, 8 published articles,
4 valid featured links, 2 old reviews without demographic consent, 5 users,
6 appointments, 1 client membership, 5 payments, 4 notifications, 64 security
audits and 0 outbox records. No changed tables or changed user fields were found.

`docker stop --timeout -1` stopped API and Worker with exit code 0 and no OOM.
Worker logs confirm graceful consumer cancellation and successful shutdown.
RabbitMQ also stopped. The same command for SQL Server sent signal 15 but did
not finish; SQL remained running/healthy and its shutdown log showed no completed
shutdown. No forced signal was sent. The Docker stop request is still pending;
do not assume that stopping its local CLI would cancel the daemon operation.

The build was **not started** because the required graceful stop did not
complete. An interim measurement while SQL was still running was 703 MiB
available physical RAM, 11,224 MiB commit headroom, 98 pages-input/sec,
19 page-reads/sec and 145.5 GiB free disk. This is not a measurement with all
four containers stopped. WSL and Docker Desktop remain running.

RabbitMQ was started again and became healthy. API and Worker remain stopped
at the safety gate: starting them while SQL has an outstanding stop request
could interrupt their database access. SQL is still running/healthy. Additional
shutdown/recovery action requires user review; no build, migration, seed,
container recreation, SQL data write, Windows build or ZIP was performed.

Evidence is under
`%TEMP%/MindBloomTask24-20261031-181416/scenario-b-*/` (the exact directory is
recorded in `scenario-b-current.txt`). It includes backup verification and hash,
57-table baseline/comparisons, sanitized container inventory and shutdown logs.
The old output APK still has SHA-256
`7B7260DBAC60422AB19FF06A05BB9D362DDBDA9C84F64C61072C14AE3D9C2B1D`;
it is not a new 1.1.0 artifact. Existing release assets and backups were not
overwritten. Await approval to resolve the SQL shutdown safety gate.

### Scenario C — successful Android Release, 2026-10-31

Following separate user approvals, the earlier SQL stop was resolved with one
`SHUTDOWN;` (without `WITH NOWAIT`), and the original Docker stop completed.
All four original services were restored healthy and all 57 table hashes were
unchanged before the user approved Scenario C and one Android build.

Scenario C repeated the safety checks: all four services healthy, no active
user SQL transactions/requests, empty outbox and 72 RabbitMQ queues with no
ready/unacked messages, unchanged backup hash and unchanged 57-table hashes.
Only the four MindBloom containers and the docker-desktop WSL distribution
were active. Sanitized container/image/mount/restart-policy inventory was saved.

API and Worker stopped with exit code 0. SQL was stopped using a tracked
`docker stop --timeout -1` plus exactly one `SHUTDOWN;`; the stop request
completed, SQL exited with code 255 and no OOM, and RabbitMQ then stopped with
code 0. No forced signal was sent. All containers were confirmed stopped before
`docker desktop stop` (without `--force`). Docker Desktop stopped successfully.
Although the distro was stopped, vmmemWSL retained approximately 1.1 GiB of
private commit; one conditionally approved `wsl --shutdown` then removed it.

Measured resources (MiB):

| Point | Available physical RAM | Commit headroom | WSL private commit |
|---|---:|---:|---:|
| Before container shutdown | 889 | 11,027 | 3,912 |
| After Docker Desktop stop | 1,957 | 14,794 | 1,128 |
| After WSL shutdown | 2,441 | 15,993 | 0 |

The one authorized build ran from `frontend/mindbloom_mobile` with:

```powershell
$env:GRADLE_OPTS='-Dorg.gradle.workers.max=1 -Dorg.gradle.parallel=false'
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
& 'C:\Users\emram\dev\flutter\bin\flutter.bat' build apk --release "--dart-define-from-file=$definesPath"
```

`$definesPath` referenced the private runtime JSON containing only the existing
sandbox publishable key. No API override, `--no-pub`, code change, generated Java
edit or Gradle-file edit was used. The existing `-Xmx2G` configuration remained.
No emulator, Windows build or parallel test suite ran.

**Result: exit 0**, 791.248 seconds end to end (Gradle reported 776.3 seconds).
The 36 resource samples recorded minimum available RAM 137 MiB, minimum commit
headroom 12,565 MiB and maximum pages-input/sec 22,289. Paging was intermittent;
the build continued to make progress. A read-only JVM sample identified Android
Lint/class loading; GC time was approximately 28 seconds at that sample, rather
than a sustained GC stall. Existing Kotlin/plugin future-compatibility warnings
remain; no fatal build error occurred.

New artifact:

- Path: `frontend/mindbloom_mobile/build/app/outputs/flutter-apk/app-release.apk`
- Version name/code: **1.1.0 / 2**.
- Package: **com.example.mindbloom_mobile**.
- Size: **75,330,095 bytes** (71.8 MiB); same byte length as the previous APK,
  but new modification time and different hash.
- SHA-256: `01F0DE68D885140B3869D7E5F4A7F51D3E76A791C340F3858EFE3123BB9514BD`.
- Release manifest has no debuggable flag and includes INTERNET permission.
- All three AOT libraries (arm64-v8a, armeabi-v7a, x86_64) contain
  `http://10.0.2.2:8080`, and none contains the Debug URL ending in 5110.
- Packaged manifest disables general cleartext traffic and references the
  packaged network-security XML (resource-shrunk path `res/8G.xml`). That XML
  permits cleartext only for `10.0.2.2`, with subdomains disabled.
- APK signature verification passed using v2 signing. The existing release
  configuration uses the **Android Debug certificate**, not a production key.
  Certificate SHA-256:
  `6726c02e0efb7d8bffafe61b2d06554a4366d0bb71b55cc00c166232fc1b06cb`.

The preserved previous APK still has SHA-256
`7B7260DBAC60422AB19FF06A05BB9D362DDBDA9C84F64C61072C14AE3D9C2B1D`.
The preserved v1.0.0 ZIP remains
`E46D8B98D9C47CD9BFE337FD9A6698A12776C42373FBB1A1E8C5E6624675FA2F`.
No release/tag/publishing operation was performed. This APK was inspected,
not installed or subjected to a new login/GUI test in this operation.

Evidence directory:
`%TEMP%/MindBloomTask24-20261031-181416/scenario-c-20261031-213240/`.
It contains build logs, start/finish metadata, 36 resource samples, JVM sample,
APK manifest/resource/signature/embedded-URL evidence and sanitized container
inventory. Private runtime define files and logs are not release assets.

Docker Desktop was restarted successfully after the build. All containers
remained stopped, with identical IDs, images, mounts and restart policies.
The existing SQL and RabbitMQ containers were started first and became healthy.
SQL was ONLINE; the full 57-table hash comparison and 85 migrations/no pending
migrations check passed before the API was started. Reminder, outbox,
idempotency/security-token and refresh-token cleanup gates found no work.
The existing API retained `Seed__Enabled=false`; its startup reported no pending
migrations and zero retention deletions. The existing Worker was then started.

Final state: **all four services running/healthy**, restart counts **0 -> 0**,
RabbitMQ 72 queues with ready/unacked 0, two consumers and four connections.
The final 57-table comparison reported no changed tables or user fields.
Both backup copies still have the expected SHA-256. No seeder, migration apply,
restore, image/container/volume recreation or configuration change was made.
Only this preparation document was updated during the approved operation;
the pre-existing Task 24 working-tree changes were preserved. No generated
file introduced an additional tracked Git change.

Windows Release and final ZIP remain unstarted and require separate approval.

### Windows Release — completed 2026-10-31, verified after session resume 2026-11-01

The user subsequently authorized one Windows Release attempt and the same
Scenario C resource preparation. Initial checks passed: preserved Android APK
hash, all 57 database hashes, 85 migrations/no pending migrations, backup,
empty RabbitMQ/outbox and no active user transactions. Visual Studio 2022 C++
tools, MSBuild and CMake were available. The previous Windows runtime was copied
outside the repository before the build; no prior artifact was deleted.

API and Worker stopped with code 0. Tracked SQL Docker stop plus one
`SHUTDOWN;` completed; SQL exited 255 without OOM. sqlcmd returned nonzero as
the connection closed, but SQL logs and the completed Docker stop independently
confirmed shutdown. RabbitMQ stopped with code 0. Docker Desktop stopped
without force, followed by one approved WSL shutdown. Available RAM increased
from 802 to 2,604 MiB; commit headroom increased from 10,871 to 15,795 MiB.

Exactly one build was launched from `frontend/mindbloom_desktop`:

```powershell
& 'C:\Users\emram\dev\flutter\bin\flutter.bat' build windows --release "--dart-define-from-file=$definesPath"
```

The private runtime define file contained the existing sandbox publishable key
and no API override. No source, CMake, dependency or configuration edit was made.
The subsequent resource-monitor command was not executed: automatic approval
review could not complete because of the usage limit. Consequently there is
**no continuous resource-monitoring evidence for this Windows build**.

On resume, `finished.json`, build log, absence of the original build process,
EXE version and file timestamps confirmed the existing attempt had succeeded.
No second build was run. Exit code **0**, total duration **113.939 seconds**;
Flutter reported Windows compilation time **104.1 seconds**. EXE and AOT data
timestamps fall within the attempt; unchanged plugin DLLs were reused normally.

Runtime: `frontend/mindbloom_desktop/build/windows/x64/runner/Release/`.
It contains **17 files, 39,340,977 bytes**. EXE FileVersion and ProductVersion
are **1.1.0+2**. `data/app.so` contains `http://localhost:8080` and does not contain
the Android emulator URL. Required files include:

- `mindbloom_desktop.exe`
- `flutter_windows.dll`
- `file_selector_windows_plugin.dll`
- `flutter_secure_storage_windows_plugin.dll`
- `printing_plugin.dll`, `pdfium.dll`
- `url_launcher_windows_plugin.dll`
- `data/app.so`, `data/icudtl.dat` and the complete `data/flutter_assets/` tree
  (asset/font/native manifests, notices, fonts and shaders).

The native-assets manifest is empty; it declares no additional bundled FFI
binary. PE dependency inspection confirmed the app/plugin/Flutter/PDFium links.
Microsoft Visual C++ x64 runtime DLLs are external prerequisites, present on this
host. Distribute the **entire Release directory**, not the EXE alone. A new GUI
launch/login or a clean-machine installation was not performed in this step.

| Key file | Bytes | SHA-256 |
|---|---:|---|
| mindbloom_desktop.exe | 92,672 | 818B5F6D0043909579612F3305EE66C30B905F0F8F30A6DD6708F1104169B739 |
| flutter_windows.dll | 21,284,864 | 61B77BC881F5C57AF5F3EEAC4A96FFD9FD87E35B77565F44C678DE105C92C2ED |
| data/app.so | 9,765,776 | 844A24F6D66B12235CB7668B5433059CD8A9BCF243045E79BCB639ADD0F4A5DA |
| data/icudtl.dat | 862,304 | 998367809A821D595928089C197B3F7959F0420F81F79D4D0DAEE53378492ED5 |
| pdfium.dll | 4,749,824 | 0C88EBACC0393FD45FC3E7B35E31E72C9E55B633A846A7ECF4085694DBA68ABD |

The complete nine-file hash inventory and native dependency report are in
`%TEMP%/MindBloomTask24-20261031-181416/windows-release-20261031-215641/`.
This directory also preserves the previous runtime, build logs, start/finish
records, resource snapshots and sanitized container inventory. The Android APK
remains `01F0DE68D885140B3869D7E5F4A7F51D3E76A791C340F3858EFE3123BB9514BD`;
the old v1.0.0 ZIP remains
`E46D8B98D9C47CD9BFE337FD9A6698A12776C42373FBB1A1E8C5E6624675FA2F`.

Docker Desktop was already available on resume, with all four existing
containers stopped and their IDs/images/mounts unchanged. SQL and RabbitMQ were
started first. One read attempt timed out during SQL cold startup; after healthy
status, the checks passed: ONLINE, 85 migrations/no pending, identical 57-table
hashes and no startup work candidates. API retained `Seed__Enabled=false` and
reported no pending migrations and zero retention deletions before Worker start.
No build was repeated, and no ZIP, commit, tag or release was created.

Final resumed verification: all four services running/healthy, with unchanged
container/image/mount/restart-policy identities and restart counts 0 -> 0.
RabbitMQ reports 72 empty queues, two consumers and four connections. The final
57-table comparison reports no changed tables/user fields, 85 migrations and
no pending migrations. The existing backup remains unchanged on host and SQL
volume. `git diff --check` passes; the pre-existing eight modified/two untracked
Task 24 files remain, with only this preparation document updated in the resumed
operation and no additional tracked generated-file changes.

### Final packaging and commit review — 2026-11-01

The user authorized packaging and small documentation corrections, but no new
build, service operation, database write, Git write or GitHub publication.
The Android hash and all nine previously recorded Windows key-file hashes
still match; the Windows runtime remains 17 files / 39,340,977 bytes.

Final archive at repository root: **`MindBloom-Release-v1.1.0.zip`**.
Size: **52,543,818 bytes**. SHA-256:

```text
F4E70E2FB4B5D729CDE1605279698A39A9D66964B1D63E4C989677295019D364
```

The exact archive allowlist is one `Android/MindBloom-v1.1.0.apk`, all 17
Windows runtime files under `Windows/` (including the complete data tree), and
`README.txt`. All **19** entry lengths and SHA-256 hashes match their sources;
all original source hashes were checked again after packaging. `7z t` passed.
No GUI launch or clean-machine installation was performed for the ZIP.

The first packaging invocation encountered a PowerShell 5 missing ZIP assembly
and created only a zero-byte placeholder. That placeholder was inspected and
moved to the external evidence directory as `failed-empty-archive.zip`; it was
not overwritten or distributed. Loading the required assembly resolved the
packaging-tool issue without changing any application/configuration file.

Allowlist validation excludes plaintext environment files, logs, source, Git
history, backups, databases and caches. Pattern checks on proposed commit files,
Windows binaries and relevant APK dex/AOT/text assets found no Stripe secret
keys, webhook secrets or private-key blocks. This is a scoped content check,
not a general security audit; public client configuration belongs to binaries.
The archive README contains prerequisites, API URLs, signing and QA limitations,
and directs backend installation to the reviewed source documentation. It
contains no passwords or backend connection strings.

The unchanged encrypted `MindBloom-Environment.zip` has one `.env` entry,
AES-256 encryption, size 1,626 bytes and SHA-256
`35ABE4EDDA7CA4423BE0A8B91836EEA814F13C1EE5B5AB99C55875D774640BB9`.
No password was supplied or decrypted content read. Successful decryption,
integrity and configuration freshness therefore remain **unverified** and
require the owner's local password-prompt check described above.

Read-only GitHub verification confirms unchanged v1.0.0 release ID 392214266,
body/update time and asset ID 575491073, size 51,959,707 bytes, digest
`E46D8B98D9C47CD9BFE337FD9A6698A12776C42373FBB1A1E8C5E6624675FA2F`.
The local v1.0.0 tag still resolves to
`54826247f0e8a0f590a8fa4b5ac96034cf32cf42`.

Proposed commit: **`build: prepare reviewed final submission release`**.
Include exactly these ten text/source-configuration files after approval:

1. `.env.example`
2. `README.md`
3. `build-images.ps1`
4. `docker-compose.yml`
5. `docs/demo-scenario.md`
6. `docs/system-architecture.md`
7. `frontend/mindbloom_desktop/pubspec.yaml`
8. `frontend/mindbloom_mobile/pubspec.yaml`
9. `docs/release-notes-v1.1.0.md`
10. `docs/release-preparation.md`

Do not use `git add .`: the final public ZIP is not ignored and is deliberately
untracked, intended as a GitHub Release upload rather than a Git blob. Do not
stage APK/EXE/build directories, runtime logs/defines, plaintext `.env`, backups
or the unchanged encrypted environment archive. `.gitignore` was not changed.

After explicit approval: stage the ten files, review the staged diff, commit,
push the reviewed branch, create a new `v1.1.0` tag pointing at that commit,
push that tag, and create the v1.1.0 GitHub Release using the reviewed release
notes and this ZIP. Verify the tag/source provenance before publishing.
After publishing, download the asset anonymously, compare its hash, check the
new version-specific release page and only then submit its actual URL to DLWMS.
Never update v1.0.0. Private archive validation, final review of documented QA
gaps/signing/demo/legal limitations and any desired packaged GUI smoke test
remain separate gates; the fresh-install Compose procedure is not newly tested.

Packaging evidence (source manifest, every-entry hashes, security-check summary
and zip result) is under the external Task 24 `packaging-*` directory referenced
by `%TEMP%/MindBloomTask24-20261031-181416/packaging-current.txt`.
