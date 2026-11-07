# MindBloom v1.1.2 - November Submission

Backend: SQL-verified session logout/revocation and refresh transaction corrections;
idempotent Development demo accounts and modest synthetic data. Desktop: corrected
administrator report endpoint paths, preserving approved UTC and Unicode PDF corrections.

Binary asset: `MindBloom-Release-v1.1.2.zip` containing one Android APK (reused 1.1.1+3)
and the complete corrected Windows runtime (1.1.2+4). No Docker images, credentials,
environment files, databases or source are included in that binary ZIP.

Source supplies a newly generated AES-256 encrypted `MindBloom-Environment.zip` containing
only `.env`. Obtain its unique password separately through DLWMS. Follow README's fresh-host
core-demo quick start with `docker-compose.evaluator.yml`; build API and Worker serially.
Demo seeding is opt-in only for the fresh database, then disabled. External Stripe, SMTP,
Firebase and Maps require separately provisioned authorized configuration and are not
available in the supplied core profile. Internal SQL/RabbitMQ notifications remain enabled.

Evidence already obtained: 100 focused auth tests, 5 seeder tests, 26 isolated SQL checks,
3 report-route tests, earlier UTC/PDF regressions; corrected Windows build exit 0. No tests
were repeated merely for assembly. User-confirmed manual checks passed for both corrected Windows PDF reports, Android/Windows
login, booking, therapist workflows and internal notifications. Fresh evaluator startup and
physical Android connectivity remain unverified. v1.1.1 immutable Release is untouched.

No local v1.1.2 API image was built during assembly because available host memory was low.
Use README's source build instructions. Do not infer runtime verification from ZIP hashes.
