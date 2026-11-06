# MindBloom v1.1.1 - November Submission

Android and Windows submission package; backend is supplied as clean source.

Public source: https://github.com/emramujezin02/rs2-mindbloom

## Included corrections

- Safer therapist client-profile loading with restricted-profile privacy.
- Business HTTP error responses and idempotency exception lifecycle handling.
- Payments-disabled dependency injection, reserved appointment pricing and
  complete appointment creation response mapping.
- USD presentation and separate financial dashboard totals by currency.
- Desktop appointment UTC interpretation, including timezone-less API UTC values.
- Embedded Roboto Regular/Bold PDF fonts with B/H/S Latin glyph support,
  redistribution license and notice.

## Download and run

Asset: **MindBloom-Release-v1.1.1.zip** (53,150,000 bytes).

```text
Android/app-release.apk
Windows/<complete runtime, including DLLs and data>
```

SHA-256:

```text
B0420D73AF20D402BC683D9647ECA7BA57D59CFA4FAC45E539D00B5B294E7116  MindBloom-Release-v1.1.1.zip
```

Android and Windows version: **1.1.1+3**.
The APK and all 21 Windows files were individually hash-verified inside the ZIP.
Extract the entire Windows directory; Visual C++ 2015-2022 Redistributable x64
may be required. Do not distribute only the EXE.

Android is configured for `http://10.0.2.2:8080` (Android emulator host alias);
Windows uses `http://localhost:8080`. Physical-phone API connectivity is not
established by this configuration. Android Release is not debuggable, but retains
the existing debug signing setup rather than production signing.

## Backend and private setup

The ZIP contains no Docker images, source, database, private environment archive
or credentials. Follow the public README and docs/release-preparation.md.
Build API and Worker serially from the clean source; no completed, verified
sanitized API image is offered. Compose's `1.1.1-source` tags are local build
targets, not registry downloads. Use private configuration based on .env.example.
Initialize/seed only a confirmed new empty evaluator database, then disable seed.
Never run this bootstrap against the owner's existing database.
Use Stripe sandbox only.

## Evidence and limits

Prior focused UTC tests: 23/23. Prior PDF tests: 8/8; text extraction preserved
all ten B/H/S Latin characters and seven rendered pages were inspected.
These are prior scoped checks, not newly executed suites.
The final Windows EXE has not been launched; GUI date/PDF behavior in that final
binary, fresh-machine installation, real Flutter GUI polling and full external
delivery/payment flows remain unverified. Package hashes do not establish GUI
acceptance. The sanitized API image build did not complete.

The binaries predate the clean-history commit; their corresponding application
sources match the published sanitized baseline `8fe3d20085d77c08839b857861e92af94b7829d2`.
They were not rebuilt from that new SHA. Old GitHub object/cache remediation is
still pending; do not claim complete historical erasure.

Footer contacts are demonstration values, official social accounts are
unconfigured and legal documents are drafts.
