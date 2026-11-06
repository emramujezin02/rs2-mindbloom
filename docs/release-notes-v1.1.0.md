> Historical v1.1.0 notes only. This Release and its tag were removed during security remediation; its download links and installation statements are obsolete. Use [v1.1.1 notes](release-notes-v1.1.1.md) and [current setup](release-preparation.md). No historical private configuration archive is distributed or recommended.

# MindBloom v1.1.0 — reviewed resubmission

**Unpublished release description draft. Android and Windows 1.1.0+2 builds
have succeeded. Publication still requires final review and explicit approval.**

This version brings the changes prepared after the faculty review of the
original submission. The existing v1.0.0 release remains unchanged.

- Therapist registration validation, private verification documents and
  administrator verification workflows.
- UTC/Europe-Sarajevo appointment handling, booking eligibility and concurrency
  protection; automatic statuses and prevention of premature completion.
- Required rejection reasons and transactional appointment, membership, audit
  and outbox updates.
- Dashboard statistics based on actual payments and completed appointments.
- Three-step mobile booking and a therapist daily calendar with restricted
  client-profile access.
- Automatic notification polling, including when SignalR is connected.
- Explicit therapy-approach/article links and four educational seed articles.
- Consent-controlled public review age/gender, privacy and minor protection.
- Shared footer navigation/contact actions, numbered blog pagination and
  related articles.
- Android Release connectivity to the Docker API at `http://10.0.2.2:8080`,
  with narrowly scoped HTTP policy. Windows uses `http://localhost:8080`.

## Running the application

Follow the repository's `docs/release-preparation.md`. Build both Docker
application images from the reviewed release source. First-time seeding is
an explicit opt-in for a new empty evaluator database; later startups disable
the full seed. Never apply fresh-install instructions to an existing database.
Obtain encrypted environment configuration and its password separately through
private channels. Extract the complete Windows directory before launching EXE;
Microsoft Visual C++ 2015–2022 Redistributable x64 is required.
Android emulator installation is supported by the supplied API configuration;
physical devices require an appropriate separately configured API endpoint.

## Verification and limitations

Task 23 recorded 1,178 unique passing automated tests: 748 backend, 308 mobile,
121 desktop and one Android Release connectivity integration test. These are
prior QA results, not a claim that new release packaging tests have passed.
Eighteen professor requirements were PASS and three remained PARTIAL.
Full registration/admin and live notification GUI journeys remain incomplete
because of preparation-host RAM limits. New Android and Windows Release builds
passed; this does not establish a new packaged-binary GUI smoke test or a
clean-machine installation test.

Official social profiles are unconfigured; footer contacts are demonstration
data and legal pages are drafts. A KM/USD registration label inconsistency
and an isolated Worker shutdown exception remain documented. Release still
uses the existing Android Debug signing certificate, not a production key.
Mobile payments require
the existing sandbox publishable-key configuration; no real payment was made
for release verification.

## Verified public asset — not yet published

- `MindBloom-Release-v1.1.0.zip`: new Android APK, complete Windows runtime and
  startup README. Layout: `Android/MindBloom-v1.1.0.apk`, `Windows/`, `README.txt`.
  Size: **52,543,818 bytes**. All 19 archive entries passed integrity and
  per-file SHA-256 checks against the original builds.

```text
F4E70E2FB4B5D729CDE1605279698A39A9D66964B1D63E4C989677295019D364  MindBloom-Release-v1.1.0.zip
```

This is archive/binary verification, not a packaged GUI smoke-test result.

The protected environment package and its password must not be public assets.
