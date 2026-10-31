# Završna QA verifikacija — Task 23

Datum nastavka: 2026-10-31 (Europe/Sarajevo). Testirani commit: `3e028c1`.

Rezultati prethodnih taskova nisu novi PASS rezultati.
Veliki logovi i privremeni artefakti čuvaju se izvan repozitorija.

## Izvori zahtjeva

Originalni izvor je `IB220075-oktobar.pdf`, pet stranica, profesorov pregled za
akademsku 2025/26. godinu, koji je korisnica dostavila kroz lokalnu putanju.
PDF je pročitan lokalno; original nije mijenjan niti uploadovan.
`MindBloom.docx` je zasebna seminarska prijava. Brojevi ispod preuzeti su iz
originalnog pregleda, a ne izvedeni iz redoslijeda commitova.

## Matrica profesorovih tačaka

| Broj | Dokumentovani zahtjev | Relevantni task | Status u Tasku 23 | Dokaz / ograničenje |
|---:|---|---|---|---|
| 1 | Mobilna registracija terapeuta, privatni upload dokumenata i desktop verifikacija | `d729b60` | PARTIAL | `TherapistVerificationJourneyTests`, document-access/security testovi i mobilni registration/verification widgeti prošli; novi ručni desktop tok od registracije do odobrenja nije izvršen. |
| 2 | Uskladiti mobilnu validaciju registracijske lozinke sa serverom | `a79f038`, `3d43a9c` | PASS | `TherapistPasswordValidationTests`, `TherapistPasswordApiTests`, mobilni `app_validators_password_test.dart` i `password_forms_test.dart`; dužina i sve tražene klase znakova. |
| 3 | Pravci otvaraju odgovarajuće članke; javne recenzije prikazuju dozvoljeni spol i dob | 19 | PASS | `LandingContentSqlTests`, `LandingContentApiTests`, `PublicReviewDemographicsTests`, `landing_content_test.dart`; migracija/seed na izolovanoj bazi, pristanak/privatnost/dob; četiri stvarne javne GET veze potvrđene. |
| 4 | Univerzalni footer: navigacija, društvene mreže i kontakt akcije | 20 | PARTIAL | `public_footer_test.dart` prolazi navigaciju i fake launcher. Korisnica je odobrila demo kontakte i neaktivne konfigurabilne ikone jer zvanični profili ne postoje. Stvarni službeni društveni URL-ovi nisu dostupni. |
| 5 | Numerisana paginacija bloga i povezani članci | 21 | PASS | `ArticleApiTests`, `article_browsing_test.dart`: stranice/filteri/zastarjeli odgovori/povezani članci/navigacija; stvarni GET stranica 1 i 2, po tri različita članka od ukupno osam. |
| 6 | Dropdown pravaca i lokacija, desktop CRUD lokacija, iskustvo i checkbox filteri | `95a5a30` | PASS | `TherapistAdvancedFilterTests`, `TherapistLocationApiTests`, `TherapistLocationSqlTests`, mobilni `advanced_filters_test.dart`; desktop `location_management_test.dart` je u desktop rezultatu ispod. |
| 7 | Serverska ograničena paginacija oba javna endpointa terapeuta i landing prve stranice | `3df24d8` | PASS | `TherapistPublicPaginationTests`, `TherapistPaginationApiTests`, `TherapistPaginationSqlTests`, `therapist_pagination_test.dart`; SQL paging prije materijalizacije. |
| 8 | Jednaka javna vidljivost terapeuta i samo odobrene recenzije u svim javnim upitima | `2b99dd1` | PASS | `PublicTherapistVisibilityTests` i `PublicTherapistVisibilityApiTests`: list/search/filter/detail/recommendations i approved-only rating. |
| 9 | Rezervacija u tri koraka, ugrađeni kalendar, vidljivi zauzeti slotovi i DA/NE potvrda | 16 | PASS | `booking_flow_test.dart`, `AppointmentBookingRuleSqlTests`: tri stvarna koraka, kalendar, disabled busy slotovi, DA/NE, dupli klik/409, tip/napomena/članarina. Nije nov ručni booking na 220075. |
| 10 | Europe/Sarajevo raspoloživost i granice lokalnog dana uz UTC pohranu | 10 / `832f0d9` | PASS | `AppointmentTimeZoneTests`, `AppointmentTimeZoneApiTests`, `AppointmentTimeZoneSqlTests`, `appointment_time_zone_test.dart`; UTC, lokalni dan i DST granice. |
| 11 | Podobnost terapeuta i zabrana preklapanja klijentovih termina na backendu | 11 / `86bd32a` | PASS | `AppointmentBookingRulesTests`, `AppointmentBookingRuleSqlTests`, security concurrency: podobnost, klijentski overlap i konkurentna rezervacija u izolovanom SQL-u. |
| 12 | Terapeutski kalendar, dnevni slobodni/zauzeti termini i dozvoljeni profil klijenta | 17 | PASS | `therapist_daily_overview_test.dart`, `TherapistDailyOverviewSqlTests`, `TherapistClientAccessSecurityTests`: zajednička slot logika, historija, statusi, stale odgovori, ograničen profil i IDOR. |
| 13 | Automatski završiti samo Accepted; istekli Pending odbiti sa sistemskim auditom | 12 / `20659ea` | PASS | `AutomaticAppointmentStatusTests`, `AutomaticAppointmentStatusSqlTests`, `AppointmentSystemAuditMigrationSqlTests`; sistemski akter, bez duple potrošnje/audita/događaja. Zastarjelo očekivanje ukupno jednog događaja popravljeno samo u testu (vidi nalaz). |
| 14 | Zabrana ručnog završavanja prije EndUtc | 13 | PASS | `ManualAppointmentCompletionTests`, `ManualAppointmentCompletionApiTests`, `ManualAppointmentCompletionSqlTests`: budući termin odbijen, granica EndUtc, rezervacija/recenzija/outbox netaknuti. |
| 15 | Razlog odbijanja i transakcijska konzistentnost statusa, članarine, audita i outboxa | 14 | PASS | `AppointmentRejectionReasonTests`, `AppointmentRejectionAuthorizationApiTests`, `TransactionalAppointmentStatusSqlTests`, `appointment_rejection_test.dart`: trimmed razlog, HTTP greške, SQL rollback/retry i konkurentnost. |
| 16 | Automatsko osvježavanje notifikacija | 18 | PARTIAL | Stvarni SQL booking→outbox→Worker handler→notification API prošao; izvezeni payload se prikazao automatskim pollingom u otvorenom Flutter widgetu. RabbitMQ workflow 6/6 zasebno. Nije izvršen jedan neprekinuti live Docker/RabbitMQ/Worker/emulator scenario; SignalR je fake u widgetu. |
| 17 | Uskladiti pohranu/čitanje jezika, dana i područja fokusa, uključujući seed | `43ec827` | PASS | `ClientPreferenceFormatTests`, `StoredPreferenceFlowTests`, `PreferenceFormatApiTests`, `RecommendationPreferenceSqlTests`: normalizacija, pohrana i čitanje/preporuke. |
| 18 | Sačuvane klijentske specijalizacije i terapeutski dropdown/FK koriste se u preporukama | `1635527` | PASS | `SpecializationPreferenceTests`, `TherapistSpecializationTests`, `SpecializationPreferenceApiTests`, `SpecializationPreferenceSqlTests`, `specialization_preferences_test.dart`: dictionary/FK, sačuvani izbor i fallback. |
| 19 | Statistike iz stvarnih termina i plaćanja | 15 | PASS | `DashboardStatisticsTests`, `DashboardFinancialSqlTests`, `dashboard_statistics_test.dart`: decimal, Paid/RefundPending/RefundFailed, članarina jednom, bez satnice/×50, Completed i UTC filteri, izolacija korisnika. |
| 20 | Tipizirane poslovne greške i bez lažnog HTTP 200/prazne liste pri tehničkoj grešci preporuka | `99b7826`, `2794d2e` | PASS | `GlobalExceptionMiddlewareTests`, `AppointmentBusinessErrorApiTests`, `RecommendationApiTests`, membership/admin-report error testovi: odgovarajući status, problem+json i sanitizacija. |
| 21 | Javni terapijski pravci kroz servis i DTO, bez DbContexta/anonimnog odgovora u kontroleru | `6ea3616` | PASS | Pregled `TherapyApproachesController` → `IReferenceDataService` → `TherapyApproachResponseDto`; `ReferenceDataServiceTests`, `TherapyApproachApiTests`, `therapy_approach_api_service_test.dart` i javni GET. |

## Android Release — zasebna provjera

### Relevantni implementacijski fajlovi po tački

Prefiksi: **M** = `frontend/mindbloom_mobile/lib/`, **D** =
`frontend/mindbloom_desktop/lib/`, **S** =
`backend/src/MindBloom.Infrastructure/Services/`, **C** =
`backend/src/MindBloom.API/Controllers/`. Testovi imenovani u matrici nalaze se
u `backend/src/MindBloom.UnitTests`, `MindBloom.IntegrationTests`,
`MindBloom.SecurityTests`, odnosno mobilnom/desktop `test/` direktoriju.

| Tačka | Relevantni fajlovi implementacije (nisu mijenjani u QA) |
|---:|---|
| 1 | M `features/auth/presentation/pages/register_page.dart`, M `features/therapist/presentation/pages/therapist_verification_page.dart`, D `features/therapist_verification/presentation/pages/therapist_verification_page.dart`, S `TherapistService.cs` |
| 2 | M i D `core/validation/app_validators.dart`, backend Auth DTO validatori |
| 3 | M `features/landing/presentation/pages/landing_page.dart`, S `ReviewService.cs`, S `ReferenceDataService.cs`, `Persistence/Seed/TherapyApproachArticleSeeder.cs`, Task 19 migracija |
| 4 | M `core/widgets/public_footer.dart`, `core/constants/public_contact_links.dart`, `core/navigation/external_link_launcher.dart` |
| 5 | M `features/article/presentation/pages/article_list_page.dart`, `article_details_page.dart`, `../widgets/article_pagination.dart`, S `ArticleService.cs` |
| 6 | M `features/therapist/presentation/pages/therapist_list_page.dart`, D `features/reference_data/presentation/pages/location_management_page.dart`, S `TherapistService.cs`, `ReferenceDataService.Locations.cs` |
| 7–8 | S `TherapistService.cs`, M `features/landing/presentation/viewmodels/landing_page_viewmodel.dart` |
| 9 | M `features/appointment/presentation/pages/appointment_create_page.dart`, `../viewmodels/appointment_create_viewmodel.dart`, `../widgets/booking_calendar.dart`, `features/appointment/data/models/booking_slot_generator.dart` |
| 10–11 | S `AppointmentService.cs`, `TherapistService.cs`, M `features/appointment/data/models/booking_slot_generator.dart` |
| 12 | M `features/appointment/presentation/pages/therapist_appointments_page.dart`, S `TherapistService.cs`, C `TherapistsController.cs` |
| 13 | S `AppointmentService.AutomaticStatus.cs`, `AppointmentStatusLock.cs` |
| 14–15 | S `AppointmentService.cs`, `MembershipService.cs`, `AppointmentStatusLock.cs`, backend API outbox |
| 16 | M `features/notification/presentation/viewmodels/notification_viewmodel.dart`, C `NotificationsController.cs`, Worker `Services/WorkerNotificationService.cs` i appointment handleri |
| 17 | `backend/src/MindBloom.Infrastructure/Serialization/ClientPreferenceFormat.cs`, S `RecommendationService.cs` |
| 18 | S `RecommendationService.cs`, `TherapistService.cs`, M `features/therapist/presentation/widgets/therapist_specialization_dropdown.dart` |
| 19 | S `AppointmentService.cs`, M dashboard komponente |
| 20 | `backend/src/MindBloom.API/Middlewares/GlobalExceptionMiddleware.cs`, S `RecommendationService.cs` |
| 21 | C `TherapyApproachesController.cs`, S `ReferenceDataService.cs` |

Android izvor: `frontend/mindbloom_mobile/android/app/src/main/AndroidManifest.xml`,
release manifest/network security overlay i M `core/constants/api_constants.dart`.

Task 22 je prethodno potvrdio stvarnu prijavu na emulatoru. Nova prijava u Tasku
23 je zasebna provjera: korisnica je naknadno izričito odobrila samo normalni
login i njegove autentifikacijske zapise, zatim i nastavak uz očuvanje dva
prethodno prijavljena security audita. Ostali poslovni UI upisi na 220075 ostaju
zabranjeni; za njih je potrebno izolovano okruženje.

Standardni APK je sačuvan izvan repozitorija prije gradnje posebnog integration
APK-a: 75.330.095 bajtova, SHA-256
`7B7260DBAC60422AB19FF06A05BB9D362DDBDA9C84F64C61072C14AE3D9C2B1D`.
Nova analiza samog binarnog fajla potvrđuje `http://10.0.2.2:8080` i odsustvo
`http://10.0.2.2:5110` u x86_64 AOT kodu, INTERNET dozvolu, minSdk 24,
targetSdk 36 i compileSdk 36. Kompajlirani network policy (`res/8G.xml`) ima
globalni cleartext=false, jedini izuzetak 10.0.2.2 i includeSubdomains=false.
Standardni APK nije ponovno građen samo radi testnih izmjena; produkcijski
izvori od njegovog Task 22 builda nisu mijenjani.

Posebni Release integration APK je izgrađen u Tasku 23 (426,1 s,
54.029.907 bajtova), SHA-256
`2AA69AE7E869F3556E8ACCC9E1523F82CF071C180B9272E04F470DB0D6D82BDC`.
Na API 34 emulatoru je instaliran i pokrenut direktno preko ADB-a, bez mock API-ja.
`resume-release-integration-logcat.txt` bilježi
`mobile ApiClient reaches MindBloom API` i `All tests passed!`.
To je **1 integration test**, uz stvarni ApiClient GET
`/api/privacy/current-versions` prema Docker API-ju; teardown nije dodatni test.
Provjereni su Release default 8080, ispravan `/api` prefiks i odgovor s obje
verzije dokumenata. Lokalni Flutter Driver odbija Android Release režim; zato
ovo nije predstavljeno kao uspješan `flutter drive --release` rezultat.
Standardni `test_driver/integration_test.dart` je analiziran i omogućava
uobičajeni Debug/Profile driver put, ali nije korišten za ovaj Release rezultat.

Zatim je instaliran sačuvani standardni APK i izvršena **jedna** normalna UI
prijava postojećim demo klijentom. Novi Task 23 dokaz, odvojen od Taska 22:

- `resume-login-api-complete.log`: POST `/api/Auth/login-2fa` **200**,
  27.916 ms; GET `/api/Appointments/client-dashboard` **200**, 1.360 ms.
- `resume-dashboard.png`: stvarna klijentska Početna i učitani dashboard.
- `resume-main-runtime-final.log`: nema AndroidRuntime fatal zapisa.
- Svježi emulator je pri prvom bootu kratko prikazao System UI ANR; nakon
  izbora Wait se oporavio. Nije potvrđen crash MindBloom aplikacije.
- Korištena je zasebna nova userdata pohrana, bez brisanja stare Task 22 sesije;
  nije izvršen drugi login, logout, booking ili plaćanje. Nakon testa je samo
  testna aplikacija force-stopovana i taj emulator uredno ugašen.
- Standardni APK je vraćen na generisane izlazne putanje; testni APK ostaje
  zasebno sačuvan u QA direktoriju. Nijedan APK nije dodat u Git.

## Testovi, integritet i ručni tokovi

### Sačuvani rezultati i brojanje

Artefakti: `%TEMP%/MindBloomTask23-20261030-193245`. Postojeći rezultati nisu
prepisivani; nastavak koristi prefiks `resume-`. TRX i Flutter JSON su dokaz
izvršavanja, a ne broj deklaracija testova u kodu. Ponavljanja su deduplicirana
po punom, case-sensitive nazivu testa (velika/mala slova u password primjerima
predstavljaju različite testne slučajeve). Loading/teardown Flutter događaji
nisu testovi. Migracije, privatnost, autorizacija, rollback i konkurentnost su
podskupovi navedenih grupa i ne dodaju se ponovo zbiru.

| Grupa | Prošlo | Palo nakon korekcije testova | Preskočeno |
|---|---:|---:|---:|
| Backend unit | 407 | 0 | 0 |
| Backend security | 38 | 0 | 0 |
| Osnovni API integration (uključuje performance) | 151 | 0 | 0 |
| Sigurnosne provjere E2E konfiguracije, uključujući dodatni GUI guard | 8 | 0 | 0 |
| SQL EndToEnd, različiti slučajevi | 138 | 0 | 0 |
| RabbitMQ/Worker workflow | 6 | 0 | 0 |
| **Backend ukupno** | **748** | **0** | **0** |
| Flutter mobile unit | 166 | 0 | 0 |
| Flutter mobile widget | 142 | 0 | 0 |
| **Mobile ukupno** | **308** | **0** | **0** |
| Android Release integration (posebno, nije u 308) | 1 | 0 | 0 |
| Flutter desktop unit | 102 | 0 | 0 |
| Flutter desktop widget | 19 | 0 | 0 |
| **Desktop ukupno** | **121** | **0** | **0** |

- Solution build: uspješan, 13 upozorenja, 0 grešaka (`backend-build.log`).
- Mobile analyze: bez nalaza (`resume-mobile-analyze.log`).
- Desktop analyze: bez nalaza (`resume-desktop-analyze.log`).
- Desktop Release build: uspješan, `build/windows/x64/runner/Release/mindbloom_desktop.exe`
  (`resume-desktop-build.log`); aplikacija nije korištena za neodobreni lokalni CRUD.
- Dodatna analiza `integration_test` i `test_driver`: bez nalaza. Šest postojećih
  connectivity/config testova prolazi i s eksplicitnim
  `API_BASE_URL=https://qa.invalid/gateway/` kroz mock transport; nema vanjskog
  zahtjeva niti dodatnog brojanja tih šest testova.
- Vanjski Stripe sandbox: pet testnih metoda NIJE POKRENUTO; posebno odobrenje
  nije dato. To nisu framework-skipped rezultati. Stripe mock/security testovi
  jesu obuhvaćeni backend skupovima.
- Standardni Testcontainers SQL put dodatno je provjeren jednim postojećim
  pagination testom; nije ponovo dodat ukupnom SQL broju.

### Prvi SQL pad i korekcija testa

Prvi SQL prolaz imao je 139/140 uspješnih rezultata, uključujući tri tadašnja
configuration guard slučaja. Pao je
`ConcurrentWriters_NeverOverwriteTerminalStatusOrDuplicateCompletion(operation: "accept")`.
Staro očekivanje je dozvoljavalo ukupno najviše jedan outbox događaj, iako
Task 14 ispravno zapisuje poseban događaj za svaku commitovanu tranziciju:
Pending → Accepted → Completed daje Accepted i Completed događaj.

Test sada poredi tačan skup routing ključeva s audit tranzicijama, zahtijeva
jedan događaj po tipu i najviše jedan Completed. Novi deterministički
`AcceptanceThenAutomaticCompletion_ProducesOneEventPerCommittedTransition`
provjerava taj redoslijed i ponovnu automatsku obradu. Ciljani skup auto-statusa
i notifikacija: 23/23 PASS. Poslovna logika nije promijenjena niti je zahtjev
nedupliranja oslabljen. Originalni log neuspjeha ostaje sačuvan.

Nakon posljednje korisničke dopune izvršen je i puni završni SQL skup nakon
korekcije: **138/138 PASS**, 0 fail, 0 skipped, 3 min 38 s.
Dokaz: `resume-sql-final/sql-final.trx` i `resume-sql-final.log`.
Sedam guard testova je ponovo prošlo nakon dodavanja neparalelne kolekcije
(`resume-guards-final/guards-final.trx`). Ova ponavljanja ne povećavaju zbir 747.

### Sigurnost SQL testne infrastrukture

`MINDBLOOM_E2E_SQL_SERVER_CONNECTION` je opcionalan. Dopušta samo eksplicitni
`master`, bez AttachDBFilename. Svaki fixture kreira svoj
`MindBloomE2E_<GUID>`; cleanup provjerava taj nepromjenjivi identitet i radi
samo ako je konkretni CREATE uspio. Nikad se ne koristi 220075 za testne upise.
Standardni zasebni Testcontainers SQL ostaje podrazumijevan. Configuration guard
testovi su neparalelna xUnit kolekcija jer privremeno mijenjaju process env.
Izvršavanja su serijska (`serial.runsettings`, `DOTNET_PROCESSOR_COUNT=2`).

### Notifikacijski dokaz i granica

`BookingOutboxWorker_NotificationVisibleOnNextAuthenticatedPoll_OnlyForRecipient`
izvršava stvarni HTTP booking, SQL commit, outbox processor, Worker dispatcher i
handler, SQL persistenciju, authenticated GET i provjeru drugog korisnika.
RabbitMQ transport i email/push su zamijenjeni u ovom testu. Payload je izvezen
u `worker-notification-current.json` i korišten kroz
`TASK18_NOTIFICATION_FIXTURE` u kompletnom mobilnom skupu. Otvoreni Flutter
notification widget se automatski promijeni nakon kontrolisanog ticka, i uz
fake aktivan SignalR, zajedno s unread countom. Šest zasebnih RabbitMQ workflow
testova koristi pravi izolovani RabbitMQ kontejner i fake email servis.
To su povezani dokazi različitih slojeva; nisu jedan live end-to-end test.

### Ručni tokovi i granice odobrenja

Lokalna baza je read-only osim naknadno izričito odobrene normalne prijave iz
standardnog Release APK-a. Dopušteni su samo očekivani autentifikacijski zapisi;
poslovni otisci ostaju zaštićeni. Migracije/seederi nisu pokretani na 220075.

| Uloga / tok | Status nove ručne provjere | Razlog / postojeći dokaz |
|---|---|---|
| Klijent: Release login i početni dashboard | PASS | Nova stvarna UI prijava u Tasku 23 iz jednog pokušaja; login i dashboard HTTP 200. Task 22 ostaje zaseban prethodni dokaz. |
| Klijent: ručno pregledavanje terapeuta/filtera/preporuka/bloga/povezanih članaka/footera | NOT TESTED | Novi potpuni ručni obilazak ovih ekrana nije izvršen; navedeni automatizovani widget/API/SQL dokazi nisu zamjena za taj obilazak. |
| Klijent: booking, članarina, recenzija, logout i drugi upisi | BLOCKED | Nema pripremljenog izolovanog pokrenutog GUI okruženja; lokalni poslovni upisi nisu odobreni. API/SQL/widget testovi prolaze, ali nisu ručni tok. |
| Terapeut: login, prihvatanje/odbijanje/završavanje i profil | BLOCKED | Isto ograničenje; sigurni SQL/HTTP i widget tokovi su izvršeni odvojeno. |
| Administrator: login, dokumenti, verifikacija, FeaturedArticleId i CRUD | BLOCKED | Desktop testovi i API/SQL journey nisu stvarni ručni desktop GUI tok. |

Javni API: `/health/live` i `/health/ready` vraćaju 200. Articles stranice 1/2
sa PageSize=3 imaju različite ID-ove, TotalCount=8 i TotalPages=3. Kategorija
Therapy Approaches vraća 4 članka. Četiri javna approach DTO-a vode na četiri
postojeća objavljena članka. Pogrešna ruta `/health` je inicijalno vratila 401;
ispravne rute su potvrđene iz Program.cs. Greška prvog kontrolnog PowerShell
omotača niza također je ispravljena; nije aplikacijski nalaz.

### Odstupanje pri kontroli lokalne baze

Prije novog login testa stroga kontrola otisaka ispravno je prekinula provjeru:
`dbo.SecurityAuditLogs` porastao je 61 → 63; ostalih 56 tabela je nepromijenjeno.
Read-only SQL analiza je potvrdila oba nova događaja kao
`UnauthorizedAccessAttempt`, `AuthenticationRequiredOrInvalid`:

- `GET /health` (pogrešna ruta kontrolnog alata);
- `GET /api/Articles/1005%201002%201003%201004` (pogrešno omotan PowerShell niz
  je poslao više ID-ova u jednom segmentu umjesto četiri pojedinačna GET-a).

`SecurityAuditMiddleware` namjerno zapisuje svaki 401/403 mimo auth endpointa.
Zato GET nije bezuslovno read-only na nivou ovog sistema. Ovo je nenamjerna
nuspojava QA alata i odstupanje od stroge lokalne read-only granice, a ne dokaz
poslovne regresije. Zahtjevi prema API-ju su pauzirani, zapisi nisu brisani niti
je baza vraćana. Korisnici je prijavljeno odstupanje i zatraženo posebno
odobrenje prije nastavka lokalnog login testa. Dokaz:
`resume-integrity-investigation.log`, `resume-audit-investigation.json`.
Ne smije se tvrditi da je svih 57 tabela ostalo potpuno neizmijenjeno.
Korisnica je zatim izričito odobrila nastavak login testa uz očuvanje i
evidentiranje oba audita. Odobrenje ne proširuje opseg na poslovne izmjene.

### Baza, Docker i backup

- Početni Task 23 snapshot čuva se u `database-before.json` i
  `users-before.json`; nije zamijenjen novim baselineom radi prikrivanja razlike.
- Početak nastavka je imao potpuno iste otiske svih 57 tabela; naknadna dva
  security audita navedena su iznad.
- 85 primijenjenih migracija, bez pending migracija; 8 objavljenih članaka,
  1 kategorija, 4 pravca/veze, 2 recenzije, 5 korisnika, 6 termina, 1 klijentska
  članarina i 5 direktnih payment zapisa. Nijedna migracija ili seed nije
  primijenjen na lokalnu bazu u Tasku 23.
- Read-only integritet: 0 disabled/untrusted foreign key ograničenja,
  0 orphan FeaturedArticle veza, 0 recenzija s automatski dodijeljenim pristankom.
- API, Worker, SQL Server i RabbitMQ su healthy. API/Worker imaju
  `Seed__Enabled=false`. Logovi tekućeg pokretanja ne sadrže fatal/SQLPAL,
  applying-migration ili seeder markere. RabbitMQ ready/unacked redovi su prazni.
- U Tasku 23 nijedan postojeći servis nije restartovan ili ponovo kreiran;
  izolovani Testcontainers resursi korišteni su samo za testiranje.
- Host backup:
  `%LOCALAPPDATA%/MindBloom/Backups/220075/Task19-20261030-120729-33b89f93/220075-before-task19-20261030-120729-33b89f93.bak`.
  Kopija u kontejneru:
  `/var/opt/mssql/backup/220075-before-task19-20261030-120729-33b89f93.bak`.
  Obje kopije imaju isti provjereni SHA-256:
  `3E959DD5AB2A94B63D4A2F625615221CC0DF469A76CB0E967A692F70EA998017`.
  Backup nije prepisan; restore nije ponavljan u Tasku 23.

Završni `resume-database-final.log` poredi isti originalni baseline i potvrđuje
`BusinessDataUnchanged=true`, `ExistingAuthRowsPreserved=true`. Od 57 tabela
54 imaju potpuno iste otiske. U AspNetUsers promijenjen je isključivo
`LastLoginAtUtc`; broj korisnika je isti. Postojeći tokeni i auditi nisu mijenjani
ili brisani. Novi audit događaji su potvrđeni agregatnim read-only SQL upitom.

| Podatak | Početak Taska 23 | Završetak |
|---|---:|---:|
| Primijenjene migracije / pending | 85 / 0 | 85 / 0 |
| Objavljeni članci | 8 | 8 |
| Kategorije | 1 | 1 |
| Pravci / FeaturedArticle veze | 4 / 4 | 4 / 4 |
| Recenzije / demografski pristanci | 2 / 0 | 2 / 0 |
| Korisnici | 5 | 5 |
| Termini | 6 | 6 |
| Klijentske članarine | 1 | 1 |
| Direktni payment zapisi | 5 | 5 |
| Notifikacije / outbox | 4 / 0 | 4 / 0 |
| Refresh tokeni | 2 | 3 |
| Security audit | 61 | 64 |

Audit razlika: **2 UnauthorizedAccessAttempt** iz ranijih QA GET provjera i
**1 LoginSucceeded** iz jedne odobrene prijave. Očekivane auth promjene nisu
predstavljene kao potpuno neizmijenjena baza. Završni Docker inspect potvrđuje
sva četiri servisa healthy i nepromijenjen seed override; testni emulator je ugašen.

### Nalazi i ograničenja

| Nalaz | Ozbiljnost | Reprodukcija / utjecaj | Preporuka i release utjecaj |
|---|---|---|---|
| Zastarjelo SQL očekivanje jednog ukupnog outbox događaja | Testni defekt; riješen | Accept pa auto-complete legitimno proizvodi dva različita događaja | Pojačana audit/event provjera i novi deterministički test prolaze; nije preostala prepreka. |
| Zastarjela zabrana porta 8080 u Android integration testu | Testni defekt; korigovan | Test je proturječio odobrenom Docker Release URL-u | Tačno očekivanje Release/Debug/override vrijednosti, uz stvarni GET zadržan; bez promjene aplikacijske konfiguracije. |
| Dva nenamjerna security audita kontrolnog GET alata | Nisko, operativno odstupanje; prijavljeno | Pogrešne rute vraćaju 401; middleware zapisuje audit i na GET | Sačuvati zapise, ne resetovati baseline; nastavak izričito odobren. Nema poslovnog gubitka podataka. |
| Nedostaju zvanični društveni profili i stvarni kontakti | Srednje prema izvornom punom zahtjevu | Ikone su konfigurabilne, ali neaktivne; kontakti su označeni demo | Vlasnica je izričito prihvatila ovo ponašanje. Ne tvrditi da su zvanični nalozi testirani; tačka 4 ostaje PARTIAL. |
| Nedostaje novi ručni GUI tok sve tri uloge i jedan live booking→Worker→emulator scenario | Srednje, QA praznina | SQL/API/widget dokazi nisu neprekinuti ručni UI/E2E tok | Pripremiti zasebno izolovano pokrenuto okruženje i dovršiti role scenarije prije bezuslovne konačne potvrde. |
| Build upozorenja i Kotlin plugin kompatibilnost | Nisko za sadašnji uspješni build, tehnički dug | Backend nullable/obsolete upozorenja; Flutter upozorava na buduću KGP podršku plugina | Planirati zaseban pregled kompatibilnosti; bez neodobrenog refaktora/upgradea u QA. |
| Ograničena memorija i raniji SQLPAL incident | Operativni rizik | Teški paralelni build/emulator poslovi ranije su ugrozili Docker | Serijsko izvršavanje i odvojen build/emulator; u tekućim logovima nema novog fatal markera. |
| Spor login i privremeni emulator System UI ANR | Srednje za korisnički odziv; nije funkcionalni pad testa | Jedna stvarna cold UI prijava trajala je 27,916 s; svježi emulator se oporavio nakon Wait | Potvrditi odziv u reprezentativnom okruženju s dovoljno memorije prije konačne predaje. Nije dokazano da je uzrok aplikacijski bug; prijava je uspjela bez retryja. |

Security testovi nisu potpuni penetration test. Prošli testovi potvrđuju
provjerene JWT/role/ownership/IDOR/upload/webhook/refresh scenarije; ne predstavljaju
garanciju odsustva svih sigurnosnih problema. Novi produkcijski sigurnosni kvar
nije potvrđen ovim provjerama.

### Izmijenjeni fajlovi i završna procjena

Produkcijski kod, migracije, seederi, Docker konfiguracija i connection stringovi
nisu mijenjani. Ranijih šest QA fajlova, očuvanih u dopuni:

1. `backend/src/MindBloom.IntegrationTests/EndToEnd/Infrastructure/MindBloomEndToEndTestFactory.cs`:
   opcionalni master-only server, vlastita GUID baza i zaštićen cleanup.
2. `backend/src/MindBloom.IntegrationTests/Infrastructure/EndToEndFactoryConfigurationTests.cs`:
   sedam odbijajućih konfiguracijskih slučajeva, novi guard kompatibilnosti
   GUI runnera i neparalelna kolekcija.
3. `backend/src/MindBloom.IntegrationTests/EndToEnd/AutomaticAppointmentStatusSqlTests.cs`:
   audit/event tačna provjera i deterministički Accept→Complete slučaj.
4. `frontend/mindbloom_mobile/integration_test/api_connectivity_test.dart`:
   tačan Release/Debug/override URL i zadržan stvarni HTTP GET.
5. `frontend/mindbloom_mobile/test_driver/integration_test.dart`:
   standardni integration driver adapter; analiziran, Release se izvršavao direktno.
6. `docs/final-qa-verification.md`: ovaj izvještaj, originalna matrica, dokazi i granice.

Dopuna dodaje još deset testnih fajlova/izmjena (ukupno 16):

7. `backend/tools/MindBloom.GuiQaHost/MindBloom.GuiQaHost.csproj`: samostalni
   testni Web SDK host, bez izmjene produkcijskog startup koda.
8. `backend/tools/MindBloom.GuiQaHost/EntryPoint.cs`: provjerena izolacija
   GUID baze i RabbitMQ vhosta, stvarni consumeri/handleri, blokirane vanjske
   integracije, lokalni proxy i zaštićeni QA kontrolni endpointi.
9. `frontend/mindbloom_mobile/integration_test/isolated_gui_test.dart`:
   pripremljene footer i notification GUI probe; nisu izvršene.
10. `frontend/mindbloom_mobile/integration_test/isolated_roles_gui_test.dart`:
    pripremljene klijentske booking, membership i blog probe; nisu izvršene.
11. `frontend/mindbloom_mobile/integration_test/isolated_registration_gui_test.dart`:
    pripremljen registration/verification/native upload tok; nije izvršen.
12. `frontend/mindbloom_mobile/test_driver/isolated_gui.dart`: driver za vanjske
    testne dokaze, bez dodavanja tajni u Git.
13. `frontend/mindbloom_desktop/integration_test/isolated_admin_gui_test.dart`:
    pripremljen admin GUI bootstrap prema 8082 uz memorijsku testnu pohranu.
14. `frontend/mindbloom_desktop/test_driver/isolated_admin_gui.dart`:
    izolovani Windows driver i vanjski izlaz dokaza; nije izvršen.
15. `frontend/mindbloom_desktop/pubspec.yaml`: postojeći Flutter SDK
    `integration_test` dodat samo kao razvojna testna zavisnost.
16. `frontend/mindbloom_desktop/pubspec.lock`: odgovarajuće SDK testne zavisnosti.

Svih 21 tačaka je obrađeno: **18 PASS, 3 PARTIAL, 0 FAIL, 0 NOT TESTED,
0 BLOCKED na nivou matrice**. PARTIAL su 1, 4 i 16. Zasebni ručni scenariji
imaju vlastite NOT TESTED/BLOCKED statuse iz gornje tabele i nisu skriveni u tom
zbiru. Android uvodna napomena je PASS na osnovu nove Release integration
provjere i jedne nove stvarne UI prijave.

Ukupno je **1.178 različitih automatizovanih testova prošlo**:
748 backend + 308 mobile + 121 desktop + 1 Android Release integration.
U odnosu na raniji zbir 1.177, dodat je samo jedan novi GUI configuration guard.
SQL rerun, sedam guard ponavljanja i šest override ponavljanja nisu ponovo brojani.
`git diff --check` prolazi; nema build artefakata ili tajni u predloženim QA fajlovima.
Commit nije napravljen.

QA promjene su spremne za ručni pregled i commit s jasno navedenim ograničenjima.
Ovo nije bezuslovna potvrda konačne predaje: ostaju potpuni ručni tokovi tri uloge,
jedan live booking→Worker→emulator scenario i provjera sporog odziva. Prije
Taska 24 treba ih zatvoriti ili izričito prihvatiti. Task 24 nije započet.

## Dodatna end-to-end i GUI verifikacija

Ova dopuna nastavlja postojeći Task 23. Rezultati 747 backend, 308 mobile,
121 desktop i 1 Android integration testa ostaju prethodni dokazi; nisu ponovo
izvršeni samo radi dopune. Sačuvano je svih šest ranijih QA fajlova; dodana je
isključivo testna infrastruktura za odobreni izolovani host i GUI runnere. Nova GUI/E2E provjera
još nema PASS rezultat i prethodna matrica 18 PASS / 3 PARTIAL nije promijenjena.

### Plan izolacije — izričito odobren

Korisnica je izričito odobrila izolovano QA okruženje prema ovom planu.
Plan je zasnovan na pregledanoj postojećoj implementaciji:

1. Postojeći `MindBloomEndToEndTestFactory` kreira isključivo vlastitu GUID
   bazu na postojećem SQL serveru. Konekcija na 220075 ne ulazi u testni host.
2. Lokalni QA HTTP host na 8082 koristi stvarni API pipeline, kontrolere i
   servise, a postojeći outbox processor i Worker consumeri/handleri koriste
   isti izolovani SQL. Drugi periodični poslovi se ne uključuju automatski.
3. Novi RabbitMQ virtual host i novi korisnik s pravima samo na taj virtual
   host odvajaju sve exchanges, queues, retry i dead-letter resurse. Postojeći
   Worker koji koristi drugi virtual host ne može preuzeti testne događaje.
4. Vlastiti JWT ključ/issuer/audience, sintetički test.local korisnici i
   testne članarine. Stripe HTTP pozivi koriste postojeći fake handler;
   native PaymentSheet se ne otvara. Email se hvata lokalnim sinkom, push je
   no-op, a geocoding koristi postojeći Testing servis. Nema vanjskih naplata,
   SMTP/Firebase poruka ili Google geocoding zahtjeva.
5. Flutter GUI buildovi imaju eksplicitni API_BASE_URL na 8082. Mobilni koristi
   novu emulator pohranu. Desktop testni bootstrap izoluje session pohranu u
   memoriji preko postojećeg SDK testnog mehanizma; ne dira postojeće desktop
   tokene. Time se ne tvrdi da je testirana diskovna session persistencija.
6. Jedan GUI cilj u datom trenutku, build prije emulatora, jedan lokalni QA
   backend proces i ograničen broj procesora. Pri problemu resursa/SQL healtha
   zaustavljaju se samo novokreirani testni procesi; postojeći servisi se ne
   restartuju i ne rekonfigurišu.
7. Za live notifikaciju terapeutov Flutter ekran ostaje otvoren dok stvarni
   autentificirani klijentski API zahtjev kreira booking. Zasebno se provjerava
   klijentski booking GUI. Ovo će biti različito označeni dokazi; API okidač se
   neće predstavljati kao klijentski GUI klik.
8. Prije/poslije se striktno porede svi otisci lokalne baze, sada uključujući
   64 audita i 3 refresh tokena. Dodatno odobrenje za stare auth zapise ne
   dozvoljava nove lokalne poslovne ili auth upise u ovoj dopuni.
9. Dokazi se čuvaju izvan repozitorija. Cleanup se ograničava na tačne GUID
   resurse kreirane u ovom dodatnom testiranju; postojeće baze, volumeni,
   kontejnere, imagee i backup kopije ne dira.

Odobreni virtual host i ograničeni QA korisnik kreirani su i nakon prve probe
uklonjeni, bez promjene postojećeg virtual hosta ili Docker konfiguracije.
Produkcijski kod se ne mijenja. Eventualni novi GUI runneri/SDK razvojna
testna zavisnost desktopa pripadaju isključivo testnoj infrastrukturi.

### Izvršena priprema i sigurnosni prekid prvog builda

- Novi `backend/tools/MindBloom.GuiQaHost` koristi stvarni API kroz TestServer,
  lokalni Kestrel proxy, stvarni outbox processor i produkcijske RabbitMQ
  consumere/handlere. Jedan proces smanjuje memoriju; to nije test odvojenih
  produkcijskih API/Worker procesa. Testing okruženje preskače migrator/seedere.
- Prvi pokušaj standalone pokretanja pronašao je pogrešan automatski content
  root. Popravljeno je samo testno razrješavanje putanje; vlastita baza tog
  pokušaja je uklonjena. Zatim host build prolazi (0 grešaka; pri ponovnom
  buildu postojećih testova 5 ranijih compiler upozorenja).
- Drugi startup je uspješan: `MindBloomE2E_bfd54cc3ee9946c1996e2af46bbbc37f`,
  virtual host/korisnik `qa-afe0480b85074717ac1933d4b7ef31f1`, port 8082.
  `GET /api/privacy/current-versions` vraća 200. Log potvrđuje stvarne
  IntegrationEventConsumer i EmailNotificationConsumer konekcije i QA redove.
  Nije poslan booking događaj i ovaj dokaz nije end-to-end notifikacijski test.
- Android GUI test je analiziran bez grešaka. Prvi debug APK build prekinut
  je sigurnosnom provjerom zbog memorijskog pritiska: postojeći API/RabbitMQ
  postali su unhealthy, a postojeći Worker se sam ponovo pokrenuo (restart
  count 3→4). Agent nije restartovao, zaustavio niti rekonfigurisao te servise.
  SQL je ostao healthy. Build je prekinut, ne označava se kao aplikacijski
  test FAIL niti kao uspješno izvršen GUI test.
- Zaustavljeni su samo provjereni vlastiti build procesi i QA host. QA baza
  je uklonjena; QA vhost i korisnik uklonjeni su management API-jem (204/204).
  Nakon oslobađanja resursa sva četiri postojeća servisa su ponovo healthy.
- Stroga dopunska usporedba svih 57 tabela `220075` prolazi:
  `ObservedChangedTables=[]`, `ChangedUserColumns=[]`, 85 migracija, 0 pending,
  8 članaka, 4 veze, 64 sigurnosna audita i 3 refresh tokena. U ovoj dopuni
  nema novih lokalnih auth ili poslovnih upisa.
- Pri shutdownu QA hosta zabilježen je produkcijski `NullReferenceException`
  u `IntegrationEventConsumer.DisposeRabbitMqResourcesAsync`, linija 901.
  Cleanup vlastite baze je ipak završen. Polja resursa koriste se preko await
  granica bez serijalizacije; konkurentni shutdown/reconnect treba posebno
  reproducirati i ispraviti uz odobrenje. Produkcijski Worker nije mijenjan.
- Statički dodatni nalaz: formular registracije terapeuta još ima oznaku
  `Cijena termina (KM)` iako je potvrđena valuta naplate USD. Nije izmijenjen.

Dokazi: vanjski `supplement-live-afe0480b85074717ac1933d4b7ef31f1/`
(`ready.json`, `seed.json`, `host-attempt2.log`, `host-attempt2-error.log`,
`broker-cleanup.json`), `supplement-host-build.log`,
`supplement-mobile-analyze.log`, `supplement-mobile-debug-build.log` i
`supplement-database-after.log`. Runtime JSON sa sintetičkim tajnama nije u Gitu.

Sljedeći pokušaj gradi samo x64 APK uz heap 768 MB, jedan Gradle worker i
in-process Kotlin; QA host i emulator ostaju ugašeni tokom builda. Ograničenja
su runtime argumenti, bez izmjene projektne Gradle konfiguracije.

I drugi build je sigurnosno prekinut na `mergeExtDexDebug`: host je izrazito
sporo odgovarao, a jedan Docker Desktop read-only poziv vratio je engine 500.
Zaustavljeno je samo vlastito Gradle stablo (PID 1784, roditelj 18540); završni
`daemon disappeared` je posljedica tog prekida, ne dokaz greške aplikacije.
Emulator i novi QA host tada nisu bili pokrenuti. Nakon prekida sva četiri
postojeća servisa su ponovo healthy. Potvrđeno je da nema naših preostalih
Java/Dart/.NET build ili host procesa; korisnički IDE procesi nisu gašeni.
Korisnica je odgovorila da će osloboditi memoriju za nastavak. Teški buildovi
i GUI izvršavanje čekaju dovoljno raspoložive memorije (približno 2 GB).

Pripremljeni novi mobilni testovi pokrivaju footer, live Worker/polling,
klijentski booking/blog i registraciju/upload; Windows test priprema admin
login i navigaciju. **To su pripremljeni testovi, ne izvršeni GUI dokazi.**
Mobilni `integration_test` i `test_driver` prolaze ciljanu analizu. Ispravljena
je greška u novom testu (`await` nad void metodom `TestTextInput.hide`), bez
promjene produkcijskog koda ili slabljenja očekivanja.

### Planirani tokovi i način dokazivanja — GUI izvršavanje čeka resurse

Svi podaci u novom okruženju bit će sintetički; pristupni podaci se ne unose
u dokument ili Git. Sljedeća tabela je plan, ne rezultat izvršavanja.

| ID / uloga | Funkcionalnost i koraci | Očekivani rezultat | Stvarni rezultat / dokaz | Status |
|---|---|---|---|---|
| GUI-REG-01 / budući terapeut | Registracija, prazna polja, slaba lozinka, zatim validan unos | Validacija blokira nevalidan zahtjev; validan dobija Pending | Test pripremljen; nije pokrenut zbog memorijskog ograničenja GUI builda | BLOCKED |
| GUI-REG-02 / terapeut | Email verifikacija kroz uhvaćeni testni izlaz i stvarni endpoint; upload sintetičkog PDF-a kroz UI | Verifikacija i upload uspiju bez stvarnog emaila; dokument ostaje privatan | Nije pokrenuto | BLOCKED |
| GUI-ADM-01 / administrator | Desktop login, pending terapeut, pregled/download dokumenta, odobrenje | Stvarni status i javna vidljivost promijene se samo u testnoj bazi | Nije pokrenuto | BLOCKED |
| API-REG-NEG / ostale uloge | Nedozvoljen format i tuđi dokument/profil | Odgovarajuće odbijanje bez privatnih podataka | Dopunski API test bit će posebno označen, nije GUI dokaz | BLOCKED |
| GUI-FOOT-01 / javni korisnik | O nama, Uslovi, Privatnost, povratak i mali prikaz | Pravilne stranice, označen pravni nacrt, nema overflowa | Nije pokrenuto u ovoj dopuni | BLOCKED |
| GUI-FOOT-02 / javni korisnik | Tri neaktivne društvene ikone, demo email i telefon | Nema tuđih profila; odgovarajući intent/fallback, bez send/call akcije | Nije pokrenuto; zvanični nalozi i dalje ne postoje | BLOCKED |
| GUI-CLI-01 / klijent | Login/logout, nevalidan login, terapeuti, filteri, detalj i preporuke | Ispravna autorizacija, lista i prikaz | Nije pokrenuto u izolovanom okruženju | BLOCKED |
| GUI-CLI-02 / klijent | Tri booking koraka, zauzeti slot, potvrda i pregled rezervacije | Jedna rezervacija i jedna rezervisana sesija; bez preklapanja | Nije pokrenuto | BLOCKED |
| GUI-CLI-03 / klijent | Članarina, preostale sesije, historija i statistika | Brojevi odgovaraju sintetičkom SQL stanju; nema stvarne naplate | Nije pokrenuto | BLOCKED |
| GUI-THER-01 / terapeut | Kalendar, profil klijenta, accept/reject s razlogom i prerani complete | Ispravni slotovi, pristup i statusna pravila | Nije pokrenuto | BLOCKED |
| E2E-NOTIF-01 / terapeut + klijentski API | Booking → SQL/outbox → stvarni RabbitMQ/Worker → otvoreni Flutter ekran | Automatska nova stavka i badge bez refresha; read i retry bez duplikata | Nije pokrenuto kao jedan live tok | BLOCKED |
| GUI-BLOG-01 / klijent | Stranice, strelice, kategorija, pretraga, povezani članak i povratak | Tačna serverska stranica i detalj, očuvana navigacija | Nije pokrenuto u ovoj dopuni | BLOCKED |
| GUI-ADM-02 / administrator | Pravac/FeaturedArticleId, blog objava i korisničke funkcije | UI promjene imaju očekivano API/SQL stanje | Nije pokrenuto | BLOCKED |

Vrsta dokaza će se navesti uz svaki stvarni rezultat: GUI na uređaju/Windowsu,
GUI integration automatizacija, backend API, postojeći widget test ili statički
pregled. Test s mockanim backendom neće biti označen kao live GUI E2E.

## Statusi

Završni Git pregled: HEAD `3e028c1`, 5 izmijenjenih i 11 novih fajlova. Sačuvani su raniji QA fajlovi; produkcijski kod nije mijenjan. Tracked diff ne uključuje nove fajlove.

```text
 .../EndToEnd/AutomaticAppointmentStatusSqlTests.cs | 40 +++++++++++-
 .../Infrastructure/MindBloomEndToEndTestFactory.cs | 75 +++++++++++++++++-----
 frontend/mindbloom_desktop/pubspec.lock            | 39 +++++++++++
 frontend/mindbloom_desktop/pubspec.yaml            |  3 +
 .../integration_test/api_connectivity_test.dart    | 14 +++-
 5 files changed, 152 insertions(+), 19 deletions(-)
```

```text
 M backend/src/MindBloom.IntegrationTests/EndToEnd/AutomaticAppointmentStatusSqlTests.cs
 M backend/src/MindBloom.IntegrationTests/EndToEnd/Infrastructure/MindBloomEndToEndTestFactory.cs
 M frontend/mindbloom_desktop/pubspec.lock
 M frontend/mindbloom_desktop/pubspec.yaml
 M frontend/mindbloom_mobile/integration_test/api_connectivity_test.dart
?? backend/src/MindBloom.IntegrationTests/Infrastructure/EndToEndFactoryConfigurationTests.cs
?? backend/tools/MindBloom.GuiQaHost/EntryPoint.cs
?? backend/tools/MindBloom.GuiQaHost/MindBloom.GuiQaHost.csproj
?? docs/final-qa-verification.md
?? frontend/mindbloom_desktop/integration_test/isolated_admin_gui_test.dart
?? frontend/mindbloom_desktop/test_driver/isolated_admin_gui.dart
?? frontend/mindbloom_mobile/integration_test/isolated_gui_test.dart
?? frontend/mindbloom_mobile/integration_test/isolated_registration_gui_test.dart
?? frontend/mindbloom_mobile/integration_test/isolated_roles_gui_test.dart
?? frontend/mindbloom_mobile/test_driver/integration_test.dart
?? frontend/mindbloom_mobile/test_driver/isolated_gui.dart
```

Pregled diff-a i novih fajlova nije našao privatne ključeve, Stripe secret
ključeve, JWT tokene ili slučajno dodane build artefakte. `git diff --check`
prolazi; Git upozorenja o budućoj LF→CRLF konverziji nisu whitespace greške.
Nije izvršen commit/push/tag/release ni promjena historije.

- PASS: stvarno provjereno u ovom tasku.
- FAIL: izvršeno i neispravno.
- PARTIAL: provjeren samo dio zahtjeva.
- NOT TESTED: provjera nije izvršena ili nedostaje tačan zahtjev.
- BLOCKED: provjeru sprečava konkretna prepreka.

### Nastavak uz odobreno preusmjeravanje samo u QA emulatoru

Korisnica je izričito odobrila korištenje neizmijenjenog standardnog Release
APK-a uz privremena mrežna pravila isključivo unutar novog QA emulatora.
Ovaj plan zamjenjuje prethodni plan novog Android builda. Host mreža,
postojeći kontejneri i baza `220075` ne smiju se mijenjati.

Prije bilo kakve prijave moraju se dokazati: preusmjeravanje emulatorovog
`10.0.2.2:8080` na izolovani QA API `8082`, zabrana pristupa stvarnom API-ju,
blokada drugih vanjskih poziva aplikacije i odgovor kontrolnog endpointa s
identitetom vlastite `MindBloomE2E_<GUID>` baze. Ako se to ne može dokazati,
aplikacija se ne prijavljuje. Odobrenje nije dokaz izvršavanja ovih koraka.

Dodatne stvarno završene provjere:

- Ciljani configuration guard skup: **8 PASS, 0 FAIL, 0 SKIP**. Sedam je
  ranije brojano; samo jedan je nov jedinstven test. Zbir ranijih 1.177
  testova s ovim dodatkom iznosi **1.178 jedinstvenih PASS** (backend 748).
- Mobilni novi integration/driver fajlovi: ciljana analiza prolazi.
- Desktop novi integration/driver fajlovi: ciljana analiza prolazi.
- Završni QA host build nakon sigurnosnih guardova: **PASS**, 0 upozorenja,
  0 grešaka, 13,75 s (`supplement-host-build-ready.log`).
- Standardni Release APK ostaje neizmijenjen; SHA-256:
  `7B7260DBAC60422AB19FF06A05BB9D362DDBDA9C84F64C61072C14AE3D9C2B1D`.

Pri posljednjoj provjeri slobodno je samo **419 MB od približno 8 GB RAM-a** (prethodna provjera 683 MB).
Novi emulator, mrežna pravila i novi QA runtime nisu pokrenuti jer bi time
ponovo nastao rizik za postojeće servise. Zatražena je potvrda nakon stvarnog
oslobađanja memorije. Sve GUI stavke iznad ostaju **BLOCKED**, a stvarni
booking/Worker/Flutter end-to-end tok još nije izvršen. Pripremljeni SDK
GUI testovi nisu kompatibilni s neizmijenjenim Release APK-om kao izvršni
test target; za odobreni novi plan koristi se stvarna ADB/native GUI proba.

### Završetak Taska 23 uz resursno ograničenje — 2026-10-31

Nakon što je korisnica zatvorila nepotrebne aplikacije, nova read-only provjera
pokazuje **1.051 MB dostupnog od 7.933 MB RAM-a**. Korisnica je izričito naložila
da se emulator/API ne forsiraju ako nema dovoljno rezerve. Najmanja prethodno
korištena QA emulator konfiguracija sama ima 1.024 MB gostujućeg RAM-a, uz
dodatnu memoriju emulator procesa, grafike i izolovanog .NET API/Worker hosta.
Ovo ne ostavlja razumnu rezervu za postojeći SQL Server i ostale servise.
To je operativna procjena za ovaj host i ranije incidente, a ne univerzalni
minimalni RAM zahtjev aplikacije.

**Odluka: ne pokretati novi emulator, QA host, Android build ili nove GUI probe.**
Emulator-only routing ostaje odobren plan koji nije izvršen. Preostale GUI
stavke u tabeli ostaju BLOCKED zbog resursa; nijedna nije proglašena PASS.
Nema razloga za novo traženje istog odobrenja, niti se zatvaraju korisnički
procesi ili postojeći Docker servisi. Task 24 nije započet.

Završna read-only provjera `supplement-closeout-database.log` potvrđuje da su
svih **57 tabela nepromijenjene u odnosu na početak ove dopune**:
`ObservedChangedTables=[]`, `ChangedTables=[]`, `ChangedUserColumns=[]`,
`BusinessDataUnchanged=true`, `ExistingAuthRowsPreserved=true`.

| Podatak | Početak dopune | Završetak dopune |
|---|---:|---:|
| Migracije / pending | 85 / 0 | 85 / 0 |
| Objavljeni članci / kategorije | 8 / 1 | 8 / 1 |
| Pravci / FeaturedArticle veze | 4 / 4 | 4 / 4 |
| Recenzije / demografski pristanci | 2 / 0 | 2 / 0 |
| Korisnici / termini | 5 / 6 | 5 / 6 |
| Klijentske članarine / direktna plaćanja | 1 / 5 | 1 / 5 |
| Notifikacije / outbox | 4 / 0 | 4 / 0 |
| Refresh tokeni / sigurnosni auditi | 3 / 64 | 3 / 64 |

Ranije odobreni auth upisi i dva prijavljena nenamjerna GET audita ostaju
izričito evidentirani u prethodnom dijelu dokumenta. Tvrdnja o nepromijenjenih
57 tabela odnosi se na ovu dopunu, ne na čitav Task 23 od originalnog baselinea.

Sva četiri postojeća kontejnera su healthy. Nijedan nije ručno zaustavljen,
restartovan ili ponovo kreiran. Raniji automatski restart Workera zbog
resursnog pritiska ostaje zabilježeno odstupanje. ADB nema priključen uređaj.
Prethodno kreirana vlastita QA baza, vhost i korisnik su uklonjeni; ne brišu se
stari QA dokazi ili Task 19 probna baza.

`supplement-closeout-artifacts.json` potvrđuje host backup od 16.900.096
bajtova sa istim ranije navedenim SHA-256 i neizmijenjen Release APK. U ovom
zatvaranju nije ponavljan restore niti je ponovo hashovana kopija u kontejneru.
Nisu pokretani migrator, seeder, autentifikacija ili poslovni zahtjevi prema
lokalnom API-ju.

**Konačna procjena:** 18 profesorovih tačaka PASS, 3 PARTIAL (1, 4, 16), bez
novog GUI dokaza koji bi opravdao promjenu tih statusa. Ukupno 1.178 različitih
automatizovanih PASS; neizvršene GUI probe i vanjski Stripe sandbox nisu
framework-skipped testovi i ne ulaze u taj zbir. Novootkriveni Worker shutdown
exception i KM oznaka registracije su prijavljeni nalazi, ne neizvršeni testovi
predstavljeni kao FAIL i nisu samostalno popravljani.

QA rad i izvještaj su završeni do dostupne granice i spremni za ručni pregled
uz ova ograničenja. **Potpuna GUI/E2E potvrda i bezuslovna spremnost za predaju
nisu postignute.** Ručni commit QA evidencije je odluka korisnice; prije Taska
24 potrebno je dovršiti preostale probe u jačem okruženju ili izričito prihvatiti
navedene praznine i nalaze. Commit, push, tag i release nisu napravljeni.
