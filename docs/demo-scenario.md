# MindBloom - Demo scenario za odbranu

## 1. Cilj demonstracije

Cilj je kontrolisana demonstracija stvarne MindBloom aplikacije: klijent pronalazi terapeuta, vidi objašnjenje preporuke, zakazuje termin, prati plaćanja/notifikacije/chat/dnevnik/recenzije; terapeut upravlja terminima i klijentima; administrator prati sistem, verifikacije, moderaciju, plaćanja, izvještaje, PDF, audit logove i šifarnike.

Ovaj scenario je prilagođen stvarnom kodu. Ne mijenjati aplikaciju radi scenarija.

## 2. Demo okruženje

- API: `http://localhost:8080`
- Swagger: `http://localhost:8080/swagger` kada je API pokrenut u Development okruženju.
- Health: `http://localhost:8080/health/live` i `http://localhost:8080/health/ready`
- RabbitMQ Management: `http://localhost:15672`
- Docker servisi iz `docker-compose.yml`: `sql-server`, `rabbitmq`, `api`, `notifications-worker`
- Mobile aplikacija: `frontend/mindbloom_mobile`
- Desktop admin portal: `frontend/mindbloom_desktop`

## 3. Demo korisnici

Svi demo korisnici su seedovani u `ApplicationDbSeeder.cs`. Demo password je isti za sve navedene korisnike.

| Uloga | Email | Password | Namjena u demonstraciji |
| --- | --- | --- | --- |
| Administrator | `desktop@mindbloom.com` | `MindBloom123!` | Desktop admin portal, izvještaji, moderacija, verifikacija, audit |
| Klijent | `mobile@mindbloom.com` | `MindBloom123!` | Mobile client flow, preporuke, termini, plaćanja, dnevnik, chat, recenzije |
| Approved terapeut | `amina@mindbloom.com` | `MindBloom123!` | Mobile therapist flow, pending/accepted/completed termini, klijenti, chat |
| Pending terapeut | `haris@mindbloom.com` | `MindBloom123!` | Admin verifikacija terapeuta |
| Approved terapeut 2 | `nejra@mindbloom.com` | `MindBloom123!` | Dodatni approved kandidat za recommender/rangiranje |

## 4. Početno stanje podataka

Seed klijent je Lejla Hadžić, lokacija Sarajevo, preferira female terapeuta, online sesije, budžet 30-80 KM, jezike Bosnian/English i fokus Anxiety/stress/sleep.

Seed terapeuti:

- Amina Kovačević: approved, Anxiety Disorders, Sarajevo, online i in-person, 55 KM, 9 godina iskustva, Bosnian/English.
- Haris Selimović: pending, koristi se za admin therapist verification.
- Nejra Kovač: approved, dodatni terapeut za recommender.

Seed termini za Aminu i Lejlu:

- Completed: prije 14 dana, online, plaćen, ima approved review.
- Accepted: za 3 dana, online, plaćen.
- Pending: za 5 dana, online, neplaćen, namijenjen therapist approve demo-u.
- Cancelled: prije 7 dana, in-person, ima refunded payment.
- Rejected: prije 5 dana, online, ima failed payment.
- Second completed: prije 30 dana, plaćen, ima pending review za admin moderation demo.

Seed dodatno uključuje: active membership `MindBloom 10 Sessions`, paid/refunded/failed payments, notifikacije, otvoren conversation za completed appointment, tri chat poruke, tri mood entry-ja, dva journal entry-ja, favorite terapeuta Amina, therapy approaches i šifarnike.

## 5. Pre-demo checklist

- [ ] Docker Desktop pokrenut.
- [ ] `docker compose ps` pokazuje healthy `sql-server`, `rabbitmq`, `api`, `notifications-worker`.
- [ ] `/health/live` vraća `Healthy`.
- [ ] `/health/ready` vraća `Healthy`.
- [ ] Swagger se otvara na `/swagger`.
- [ ] Mobile login radi za `mobile@mindbloom.com` i `amina@mindbloom.com`.
- [ ] Desktop login radi za `desktop@mindbloom.com`.
- [ ] U mobile klijentu postoje `Recommended therapists`, `Payment history`, `Notifications`, `Messages`, `Mood and emotions`, `My reviews`.
- [ ] U desktop adminu postoje `Therapist Verification`, `Reviews`, `Payments`, `Reports`, `Audit Log`, `Reference Data`.
- [ ] Ako se radi live Stripe payment: internet i Stripe sandbox konfiguracija rade.
- [ ] Ako se radi PDF demo: desktop aplikacija ima pravo pisanja u odabrani folder.

## 6. Klijent - demo scenario

### 6.1 Login

Početni ekran: mobile `Login`.

Kliknuti/unesi: email `mobile@mindbloom.com`, password `MindBloom123!`, zatim login dugme.

Pokazati: klijent ulazi u client shell; donja navigacija sadrži `Početna`, `Terapeuti`, `Termini`, `Dnevnik`, `Profil`; drawer sadrži `Chat`, `Notifikacije`, `Preporučeni terapeuti`, `Omiljeni terapeuti`, `Moje članstvo`, `Plaćanja`, `Moje recenzije`.

Rečenica: "Klijent koristi mobilnu aplikaciju i vidi samo client funkcionalnosti."

DB promjena: ne.

### 6.2 Recommendation

Početni ekran: client shell.

Kliknuti: drawer ili meni -> `Preporučeni terapeuti`.

Seed podatak: klijent Lejla ima onboarding preference; Amina i Nejra su approved kandidati.

Pokazati: ekran `Recommended therapists`, header `Therapists selected for you`, broj pronađenih preporuka, kartice terapeuta, `Match with your needs`, procenat i score.

Očekivani rezultat: prikazuju se samo approved/active/unblocked terapeuti koji odgovaraju preferencama.

Rečenica: "Ovo nije machine learning model nego weighted content-based scoring zasnovan na profilu klijenta i terapeuta."

DB promjena: ne.

### 6.3 Recommendation explanation

Početni ekran: `Recommended therapists`.

Kliknuti: na kartici terapeuta proširiti `Why this therapist?`.

Pokazati: razloge poput `Specialization`, `Therapy approach`, `Initial assessment`, `Preferred schedule`, `Price`, `Experience`, `Rating`, `Availability`, `Previous appointments`, `Favorite therapist`, sa bodovima `awarded/max`.

Očekivani rezultat: UI prikazuje top razloge i objašnjenja iz backend `RecommendationService`.

Rečenica: "Svaki kriterij daje normalizovane bodove, ukupno do 100, pa korisnik vidi zašto je terapeut preporučen."

DB promjena: ne.

### 6.4 Therapist details

Početni ekran: `Recommended therapists`.

Kliknuti: `Open profile` na Amini Kovačević.

Pokazati: `Therapist details`, biografiju, specijalizaciju, cijenu, dostupnost, reviews i akcije `Book appointment`, `Contact therapist`, `Buy membership package`.

Očekivani rezultat: profil approved terapeuta se otvara.

Rečenica: "Iz preporuke direktno dolazimo do profila i zakazivanja."

DB promjena: ne.

### 6.5 Booking

Početni ekran: `Therapist details`.

Kliknuti: `Book appointment`.

Izabrati: Aminu; datum koji pada na dostupnost terapeuta: Monday 09:00-13:00, Wednesday 14:00-18:00 ili Friday 10:00-14:00. Izabrati slobodan slot, session type online, unijeti kratku napomenu, pregledati `Review`, zatim `Confirm`.

Pokazati: `Book appointment`, korake `Therapist`, `Date`, `Available time`, `Session type`, `Notes`, `Review`, `Confirmation`; nakon potvrde `Appointment created`.

Očekivani rezultat: kreira se novi `Pending` appointment. Backend objavljuje `appointment.created` kroz outbox/RabbitMQ.

Rečenica: "Klijent šalje zahtjev, a terapeut ga tek treba prihvatiti."

DB promjena: da, kreira appointment i status audit.

Ovaj novi appointment je preporučeni live appointment za redoslijed `Booking -> Accept -> Payment -> Complete`, jer ne troši seeded accepted appointment koji služi kao fallback/payment-history primjer.

### 6.6 Payment

Važno: payment live flow radi samo za `Accepted` appointment. Novi appointment iz 6.5 je `Pending` i ne može se platiti dok ga terapeut ne prihvati.

Preporučeni demo: otvoriti drawer -> `Plaćanja`.

Pokazati: `Payment history`, seeded paid appointment payment, refunded cancelled appointment, failed payment i membership payment; otvoriti paid stavku i prikazati `Payment receipt`.

Opcionalni live Stripe flow: nakon što terapeut prihvati appointment kreiran u 6.5, klijent otvara `Termini` -> taj appointment -> `Pay appointment` -> `Confirm payment` -> `Continue to payment`; aplikacija kreira PaymentIntent, otvara Stripe Payment Sheet, zatim backend potvrđuje payment.

Fallback: ako Stripe/internet ne radi, pokazati seeded `Payment history` i `Payment receipt`.

Rečenica: "Historija plaćanja je lokalno dokaziva; live Stripe dio zavisi od sandbox servisa."

DB promjena: ne za seeded prikaz; da za live Stripe payment.

### 6.7 Notifications

Početni ekran: client shell.

Kliknuti: drawer -> `Notifikacije`.

Seed podatak: `Upcoming therapy session` za accepted appointment i `Membership activated`.

Pokazati: `Notifications`, unread/read notifikacije i `Read all`.

Očekivani rezultat: vidi se appointment i membership notifikacija. Live booking/approve/payment događaji koriste integration events, ali ne obećavati da će queue imati poruku baš u trenutku prikaza.

Rečenica: "Notifikacije se čuvaju u bazi, a event-driven dio ide preko outboxa i RabbitMQ workera."

DB promjena: samo ako se klikne `Read all`.

### 6.8 Chat

Početni ekran: client shell.

Kliknuti: drawer -> `Chat`, otvoriti conversation sa Aminom.

Seed podatak: conversation za completed appointment s porukama: "Hello, I am ready for today's session.", odgovor terapeuta i dodatna klijent poruka.

Pokazati: `Messages`, historiju poruka, mogućnost slanja nove poruke.

Fallback: ako realtime demonstracija nije pouzdana bez dvije aktivne sesije, pokazati postojeću seeded conversation/history.

Rečenica: "Chat je vezan za appointment i podržan SignalR hubom; historija ostaje dostupna i bez live druge sesije."

DB promjena: da ako se pošalje nova poruka.

### 6.9 Mood i journal

Početni ekran: donja navigacija.

Kliknuti: `Dnevnik`.

Pokazati: `Mood and emotions`, filter perioda, mood history, journal entries `A positive step forward` i `Managing stress this week`; po potrebi otvoriti `My emotional patterns`.

Očekivani rezultat: vide se seeded mood timeline i journal entries.

Rečenica: "Klijent prati raspoloženje i privatne bilješke, a terapeut može vidjeti relevantnu emocionalnu analitiku kroz client details."

DB promjena: ne, osim ako se namjerno klikne `New journal entry` i `Save entry`.

### 6.10 Review

Preporučeni demo: drawer -> `Moje recenzije`.

Seed podatak: completed appointment prije 14 dana ima approved review; second completed appointment prije 30 dana ima pending review za admin moderaciju.

Pokazati: `My reviews`, status `Approved` ili `Pending moderation`, komentar i eventualni therapist reply.

Live create review koristiti samo ako postoji completed appointment bez recenzije. Nakon therapist complete demo-a može se vratiti u klijenta i otvoriti appointment details -> `Leave review`, ali to mijenja stanje i kreira pending review.

Rečenica: "Recenzija se može poslati tek poslije completed appointmenta i prolazi moderaciju."

DB promjena: ne za seeded prikaz; da za live `Leave review`.

## 7. Terapeut - demo scenario

### 7.1 Login

Početni ekran: mobile `Login`.

Unijeti: `amina@mindbloom.com` / `MindBloom123!`.

Pokazati: therapist shell s donjom navigacijom `Početna`, `Termini`, `Klijenti`, `Chat` i drawer stavkama `Kontrolna ploča`, `Notifikacije`, `Profil`, `Postavke`, `Članci`, `Radionice`.

DB promjena: ne.

### 7.2 Dashboard

Početni ekran: `Početna`.

Pokazati: `Kontrolna ploča`, današnje/nadolazeće termine, aktivne klijente, unread messages, revenue/ratings ako su prikazani.

Rečenica: "Terapeut vidi operativni pregled svog rada."

DB promjena: ne.

### 7.3 Appointments

Kliknuti: `Termini`.

Pokazati: filters `Pending`, `Accepted`, `Completed`, `All dates`, `Today`, `This week`, `All statuses`, kartice termina i dugme `Details`.

Seed podatak: pending appointment za 5 dana i accepted appointment za 3 dana. Ako se prije terapeutskog dijela uradio live booking iz 6.5, u listi se vidi i taj novi pending appointment.

DB promjena: ne.

### 7.4 Approve

Početni ekran: `Termini`.

Izabrati: prvenstveno appointment koji je klijent upravo kreirao u 6.5. Ako live booking nije rađen, koristiti seeded pending appointment s napomenom "Demonstration appointment awaiting therapist approval."

Kliknuti: `Accept`.

Očekivani rezultat: status prelazi `Pending -> Accepted`; backend objavljuje `appointment.accepted`. Nakon ovog koraka klijent može platiti upravo taj appointment.

Rečenica: "Terapeut prihvata zahtjev klijenta; status transition je dozvoljen samo iz Pending statusa."

DB promjena: da. Ako se koristi seeded pending appointment, taj zapis se troši; za ponavljanje treba fresh baza ili novi booking.

### 7.5 Client details

Kliknuti: `Klijenti` -> `View details` za Lejlu Hadžić.

Pokazati: appointment history, memberships, reviews i emocionalne podatke ako su dostupni.

Seed podatak: Lejla ima completed/accepted/pending/cancelled/rejected appointments, membership i journal/mood historiju.

Rečenica: "Terapeut ima pregled klijenta samo kada postoji dozvoljen odnos kroz appointment/membership."

DB promjena: ne.

### 7.6 Chat

Kliknuti: `Chat`, otvoriti conversation s Lejlom.

Pokazati: postojeće poruke i opcionalno poslati kratku live poruku.

Rečenica: "Chat radi preko appointment conversationa i SignalR realtime sloja."

DB promjena: da ako se šalje poruka.

### 7.7 Complete appointment

Početni ekran: `Termini`.

Izabrati: isti live appointment koji je prošao `Booking -> Accept -> Payment`. Ne koristiti seeded accepted appointment "Upcoming confirmed demonstration appointment." ako još treba za payment fallback ili prikaz seeded historije.

Kliknuti: `Complete`.

Očekivani rezultat: status prelazi `Accepted -> Completed`; backend objavljuje `appointment.completed`. Backend manual completion ne provjerava da li je termin u prošlosti; provjerava status transition, terapeuta vlasnika appointmenta i membership usage finalizaciju ako postoji. Payment nije backend precondition za `Complete`, ali demo redoslijed ipak plaća prije complete zbog poslovne logike i kasnijeg review toka.

Rečenica: "Completed je terminalni status i poslije njega se može kreirati review."

DB promjena: da. Nakon toga klijent može demonstrirati `Leave review` za taj completed appointment, ako želi live review; seeded `My reviews` ostaje sigurniji fallback.

## 8. Administrator - demo scenario

### 8.1 Login

Početni ekran: desktop admin `Login`.

Unijeti: `desktop@mindbloom.com` / `MindBloom123!`.

Očekivani rezultat: admin shell i `Dashboard`.

DB promjena: ne.

### 8.2 Dashboard

Pokazati: `Dashboard`, korisnike, terapeute, termine, revenue kartice i `Revenue by month`.

Rečenica: "Admin vidi sistemski pregled i agregirane poslovne metrike."

DB promjena: ne.

### 8.3 Therapist verification

Kliknuti: sidebar `Therapist Verification`.

Filter: status `Na čekanju` ili pretraga `haris`.

Seed podatak: Haris Selimović, `Pending`.

Preporuka: za glavni demo samo otvoriti detalje i objasniti `Approve/Reject/Request changes`; ne odobravati Harisa ako želite očuvati početni recommender kandidat set. Ako se odobri, Haris ulazi u approved terapeute i može uticati na kasnije liste/preporuke.

DB promjena: ne ako se samo prikazuje; da ako se klikne approval akcija.

### 8.4 Review moderation

Kliknuti: sidebar `Reviews`.

Filter: status `Pending`.

Seed podatak: pending review za second completed appointment, komentar "The session was useful and the communication was clear."

Kliknuti: detalji -> `Approve` ili samo prikazati dostupne akcije.

Očekivani rezultat: ako se odobri, review postaje public approved i objavljuje se `review.approved`.

Rečenica: "Recenzije nisu javne odmah; admin moderation kontroliše objavu."

DB promjena: ne ako se samo prikazuje; da ako se klikne `Approve`, `Reject` ili `Hide published review`.

### 8.5 Payments

Kliknuti: `Payments`.

Pokazati: appointment/membership payments, statuse paid/refunded/failed, detalje i receipt.

Seed podatak: `pi_demo_completed_001`, `pi_demo_upcoming_001`, `pi_demo_refunded_001`, `pi_demo_failed_001`, membership payment.

Rečenica: "Admin vidi transakcije i refund status bez otvaranja Stripe dashboarda."

DB promjena: ne, osim ako postoji refund/admin akcija i namjerno se izvrši.

### 8.6 Reports

Kliknuti: `Reports` -> `Appointment Revenue Report`.

Filter period: od 35 dana prije dana demonstracije do 7 dana poslije dana demonstracije. Seed datumi su relativni na dan seedovanja, pa ovaj period pokriva completed, accepted, cancelled, rejected i second completed appointment.

Pokazati: totals, gross/net revenue, payment summary, status table, appointment rows.

Zatim `Reports` -> `Therapist Performance Report`.

Filter period: isti period; therapist `All therapists`; status `All statuses`; minimum appointments `0`.

Pokazati: rank, therapist, appointments, completed, cancelled, completion rate, clients, rating, reviews, net revenue.

DB promjena: ne.

### 8.7 PDF

PDF implementacija je u Flutter desktopu, ne u backend report endpointu.

Izvještaji:

- `AppointmentRevenuePdfService` generiše `mindbloom-appointment-revenue-<from>-<to>.pdf`.
- `TherapistPerformancePdfService` generiše `mindbloom-therapist-performance-<from>-<to>.pdf` ili therapist-specific naziv.

Kako pokrenuti:

1. Otvoriti odgovarajući report.
2. Postaviti period/filtere.
3. Kliknuti dugme za generisanje reporta.
4. Nakon što se pojavi `PDF preview`, kliknuti `Download PDF` za save dialog ili `Print` za print dialog.

Pokazati: `PDF preview`, `Download PDF`, `Print`. PDF se generiše lokalno u desktop aplikaciji pomoću `pdf` i `printing` paketa, a `Download PDF` otvara save dialog.

DB promjena: ne.

### 8.8 Audit logs

Kliknuti: `Audit Log`.

Pokazati: lista audit zapisa i filtere.

Prirodni demo redoslijed: otvoriti audit nakon therapist verification/review moderation/reference data akcije, jer te admin akcije mogu kreirati audit zapis kroz backend audit servise. Ako se tokom demo-a ne radi state-changing admin akcija, pokazati postojeću listu ako postoji.

DB promjena: ne za prikaz.

### 8.9 Reference data

Kliknuti: `Reference Data`.

Pokazati: therapist specializations, therapy approaches i article categories; search/filter; dugmad za create/edit/status gdje postoje.

Preporuka: ne mijenjati seed bez potrebe. Ako profesor traži CRUD, kreirati jasno nazvan demo zapis, pokazati ga, pa ga obrisati/deaktivirati ako UI to podržava.

DB promjena: ne za prikaz; da za CRUD.

## 9. Tehnički dio

### 9.1 Docker

Otvoriti terminal:

```powershell
docker compose ps
```

Pokazati: `sql-server`, `rabbitmq`, `api`, `notifications-worker` su healthy.

Rečenica: "Aplikacija se diže kao više servisa: baza, message broker, API i odvojeni worker."

### 9.2 Swagger

Otvoriti: `http://localhost:8080/swagger`.

Pokazati reprezentativne grupe: Auth, Therapists, Appointments, Recommendations, Payments, Admin reports.

Rečenica: "API je dokumentovan kroz Swagger i koristi JWT/role-based zaštitu."

Ne trošiti vrijeme na ručno izvršavanje mnogo endpointa.

### 9.3 Arhitektura

Otvoriti: `docs/system-architecture.md`.

Pokazati: mobile/desktop frontend, API, SQL Server, RabbitMQ, Notifications Worker, SignalR, Stripe/Firebase integracije.

Rečenica: "API je centralni application boundary, worker je izdvojen proces za async notifikacije i event handling."

### 9.4 Baza

Otvoriti: `docs/database-schema.md`.

Fokus: `ApplicationUser`, `Client`, `Therapist`, `Appointment`, `Payment`, `ClientMembership`, `Review`, `Conversation`, `ChatMessage`, `MoodEntry`, `PrivateJournalEntry`.

Ne objašnjavati svaku tabelu.

### 9.5 RabbitMQ

Otvoriti: RabbitMQ Management UI.

Pokazati: exchange/queues iz konfiguracije: notification exchange, email queue, integration event queue, retry queues, DLQ queues. Routing keys uključuju `appointment.created`, `appointment.accepted`, `appointment.completed`, `chat.message-created`, `payment.succeeded`, `payment.refunded`, `review.approved`, `notification.requested`.

Rečenica: "Ako queue trenutno ima 0 messages, to je normalno jer ih worker brzo potroši; bitno je pokazati topologiju i odvojen proces."

### 9.6 Notifications Worker

Pokazati: Docker servis `notifications-worker` i po potrebi logs.

Worker odgovornosti: consuming integration event queue i email queue, dispatch handlera, Firebase/no-op push, email notification, retry i dead-letter handling.

### 9.7 Recommender

Otvoriti: `RecommendationService.cs` ili `docs/recommender-dokumentacija.md`.

Objasniti: weighted content-based filtering, score do 100, filter samo active/unblocked approved terapeuta, preference klijenta, cijena, iskustvo, rating, dostupnost, prethodni appointment i favorite.

Na ekranu pokazati `Recommended therapists`, `Match with your needs`, `Recommendation score` i `Why this therapist?`.

## 10. Preporučeni redoslijed cijele odbrane

1. Kratko pokazati Docker health i Swagger.
2. Mobile client: login, recommendations, explanation, therapist details, booking, payments, notifications, chat, journal/mood, reviews.
3. Mobile therapist: login, dashboard, appointments, approve, client details, chat, complete.
4. Desktop admin: dashboard, therapist verification, review moderation, payments, reports, PDF, audit logs, reference data.
5. Tehničko objašnjenje: arhitektura, baza, RabbitMQ/Worker, recommender.

## 11. Time plan

- Client: 5-6 minuta
- Therapist: 3-4 minute
- Admin: 5-6 minuta
- Technical: 4-5 minuta

Ukupno: oko 17-21 minuta. Ako je vrijeme strogo 15 minuta, skratiti live booking/payment i prikazati seeded examples.

## 12. Fallback plan

| Rizik | Fallback |
| --- | --- |
| Stripe sandbox/internet ne radi | Pokazati seeded `Payment history` i `Payment receipt` za paid/refunded/failed payment. |
| Firebase/push ne radi | Pokazati seeded `Notifications` u bazi/UI. |
| Realtime chat treba dvije sesije | Pokazati seeded conversation i historiju poruka. |
| RabbitMQ queue je prazna | Pokazati topology, routing keys, worker service i logs. |
| PDF save dialog problem | Pokazati `PDF preview`; probati `Print` ako save nije dostupan. |
| Live admin action potroši pending record | Preći na prikaz seeded history ili pripremiti fresh bazu prije narednog pokušaja. |

## 13. Vraćanje demo stanja

Seeder je idempotentan za kreiranje nedostajućih podataka, ali ne vraća nužno izmijenjeno stanje nazad. Na primjer, ako se pending appointment prihvati, ponovno pokretanje aplikacije ga neće sigurno vratiti u `Pending`, jer seeder uglavnom provjerava da zapis postoji.

Razlika:

- Ponovno pokretanje aplikacije: pokreće migracije/seeder, ali ne garantuje rollback promijenjenih statusa.
- Fresh database: vraća čisto seeded stanje nakon migracija i seedovanja.

Priprema prije odbrane: koristiti dokumentovani project clean-start postupak ako želite potpuno svježe stanje. Potpuni reset znači namjerno kreiranje fresh baze/volumena i radi se PRIJE odbrane, nikada improvizovano tokom odbrane. Brisanje persistent DB volumena je destruktivan reset i ne treba ga tretirati kao običan demo korak.

## 14. Šta ne mijenjati neposredno prije odbrane

- Ne mijenjati `.env` i Stripe/RabbitMQ/Firebase konfiguraciju bez potrebe.
- Ne upgradeovati Flutter/.NET dependencies.
- Ne regenerisati migrations.
- Ne mijenjati demo credentials.
- Ne resetovati bazu neposredno prije odbrane ako nije jasno da će se seed završiti uspješno.
- Ne odobravati pending terapeuta ili pending review tokom probe ako isti podaci trebaju ostati za stvarnu odbranu.

## 15. Sažetak za brzo ponavljanje prije odbrane

Klijent: `mobile@mindbloom.com` -> `Preporučeni terapeuti` -> `Why this therapist?` -> `Open profile` -> `Book appointment` -> `Plaćanja` -> `Notifikacije` -> `Chat` -> `Dnevnik` -> `Moje recenzije`.

Terapeut: `amina@mindbloom.com` -> `Termini` -> pending appointment -> `Accept` -> `Klijenti` -> Lejla -> `Chat` -> accepted appointment -> `Complete`.

Admin: `desktop@mindbloom.com` -> `Dashboard` -> `Therapist Verification` Haris -> `Reviews` pending review -> `Payments` -> `Reports` -> PDF preview/download/print -> `Audit Log` -> `Reference Data`.

Tehnički: Docker health -> Swagger -> arhitektura -> baza -> RabbitMQ -> Worker -> recommender.

## 16. Demo gap audit

| Requirement | Verified | Evidence | Demo gap |
| --- | --- | --- | --- |
| CLIENT login | PASS | Mobile login route and seeded client credentials | Ne |
| CLIENT recommendation | PASS | `RecommendationPage`, `RecommendationsController`, `RecommendationService` | Ne |
| CLIENT explanation | PASS | UI `Why this therapist?`, reasons DTO | Ne |
| CLIENT therapist details | PASS | `TherapistDetailsPage`, `Open profile` | Ne |
| CLIENT booking | PASS | `AppointmentCreatePage`, `CreateAsync`, availability rules | Ne |
| CLIENT payment | PASS | Payment UI exists; live payment only for `Accepted`; seeded history exists | Ne |
| CLIENT notification | PASS | `NotificationPage`, seeded notifications | Ne |
| CLIENT chat | PASS | `ChatListPage`, `ChatDetailsPage`, seeded conversation, SignalR hub | Ne |
| CLIENT journal/mood | PASS | `JournalPage`, mood entries, journal entries, analytics page | Ne |
| CLIENT review | PASS | `My reviews`, `CreateReviewPage`, business rule completed-only | Ne |
| THERAPIST login | PASS | Same mobile login, therapist role shell | Ne |
| THERAPIST dashboard | PASS | `TherapistDashboardPage` | Ne |
| THERAPIST appointment | PASS | `TherapistAppointmentsPage`, details page | Ne |
| THERAPIST approve | PASS | `Accept`, status `Pending -> Accepted` | Ne |
| THERAPIST client details | PASS | `TherapistClientsPage`, `TherapistClientDetailsPage` | Ne |
| THERAPIST chat | PASS | Therapist bottom nav `Chat` | Ne |
| THERAPIST complete appointment | PASS | `Complete`, status `Accepted -> Completed` | Ne |
| ADMIN login | PASS | Desktop login and session guard | Ne |
| ADMIN dashboard | PASS | `DashboardPage` | Ne |
| ADMIN therapist verification | PASS | `Therapist Verification`, Haris pending | Ne |
| ADMIN review moderation | PASS | `Reviews`, pending review, approve/reject/hide | Ne |
| ADMIN payment | PASS | `Payments`, details/receipt | Ne |
| ADMIN reports | PASS | Appointment Revenue and Therapist Performance pages | Ne |
| ADMIN PDF | PASS | Desktop PDF services, preview, `Download PDF`, `Print` | Ne |
| ADMIN audit logs | PASS | `Audit Log` section and admin audit page | Ne |
| ADMIN reference data | PASS | `Reference Data` management page | Ne |
| TECH Swagger | PASS | `UseSwagger`, `UseSwaggerUI` in Development | Ne |
| TECH RabbitMQ | PASS | topology, queues, routing keys, retry/DLQ | Ne |
| TECH Worker | PASS | `notifications-worker`, consumers and handlers | Ne |
| TECH Docker | PASS | `docker-compose.yml` services | Ne |
| TECH recommender explanation | PASS | score reasons shown in UI | Ne |
| TECH database | PASS | EF DbContext/docs/entities | Ne |
| TECH architecture | PASS | architecture docs and source layout | Ne |
