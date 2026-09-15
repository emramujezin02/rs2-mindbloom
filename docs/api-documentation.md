# MindBloom - REST API dokumentacija

## 1. Pregled API-ja

MindBloom backend izlaže ASP.NET Core REST API kroz controllere u `backend/src/MindBloom.API/Controllers/`. Standardni controlleri koriste prefiks `api/...`, dok host i port zavise od environmenta. Swagger/OpenAPI je konfigurisan za interaktivno testiranje API-ja, a ovaj dokument služi kao pregled modula, ruta, autorizacije i poslovne svrhe.

API koristi JWT Bearer authentication. Većina endpointa zahtijeva autentifikovanog korisnika, dok javni endpointi eksplicitno koriste `[AllowAnonymous]`. Realtime komunikacija postoji preko SignalR hubova (`/hubs/notifications`, `/hubs/chat`), ali SignalR metode nisu REST endpointi i nisu prikazane kao REST rute.

## 2. Autentikacija, autorizacija i error model

Autorizacija je definisana kroz policy konstante i role:

| Policy | Zahtjev |
| --- | --- |
| `AuthenticatedUser` | Validan JWT access token. |
| `ClientOnly` | JWT + role `Client`. |
| `TherapistOnly` | JWT + role `Therapist`. |
| `AdminOnly` | JWT + role `Admin`. |
| `ClientOrTherapist` | JWT + role `Client` ili `Therapist`. |
| `AdminOrTherapist` | JWT + role `Admin` ili `Therapist`. |

Globalni exception middleware vraća `application/problem+json` kroz `ApiErrorResponse`. Potvrđeni mapping uključuje: validation i invalid argumente na `400`, unauthorized na `401`, forbidden na `403`, not found na `404`, business/invalid operation konflikte na `409`, external provider/timeouts na `503`, i neočekivane greške na `500`. Pojedini endpointi imaju i direktne statuse iz action metode, npr. `201`, `204`, `405` ili `400` za Stripe webhook signature validation.

## 3. Auth

Base route: `/api/auth`

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/auth/register` | Anonymous | `RegisterRequestDto` | auth result | `200`; global errors | Registracija klijenta. |
| `POST` | `/api/auth/register-therapist` | Anonymous | `RegisterTherapistRequestDto` | auth/register result | `201`; global errors | Registracija terapeuta. |
| `POST` | `/api/auth/login` | Anonymous | `LoginRequestDto` | auth result | `200`; global errors | Login i izdavanje tokena. |
| `POST` | `/api/auth/refresh-token` | Anonymous | `RefreshTokenRequestDto` | auth result | `200`; global errors | Obnova access tokena refresh tokenom. |
| `POST` | `/api/auth/logout` | Authenticated | `RefreshTokenRequestDto` | message | `200`; global errors | Odjava trenutne sesije. |
| `POST` | `/api/auth/logout-all` | Authenticated | - | message | `200`; global errors | Odjava svih sesija korisnika. |
| `GET` | `/api/auth/me` | Authenticated | - | user claims object | `200`; global errors | Minimalni podaci iz JWT claimova. |
| `POST` | `/api/auth/change-password` | Authenticated | `ChangePasswordDto` | message | `200`; global errors | Promjena lozinke. |
| `DELETE` | `/api/auth/delete-account` | Authenticated | `DeleteAccountRequestDto` | message | `200`; global errors | Brisanje/deaktivacija računa kroz auth servis. |
| `POST` | `/api/auth/forgot-password` | Anonymous | `ForgotPasswordDto` | message | `200`; global errors | Slanje password reset instrukcija. |
| `POST` | `/api/auth/reset-password` | Anonymous | `ResetPasswordDto` | message | `200`; global errors | Reset lozinke. |
| `POST` | `/api/auth/send-verification-email` | Anonymous | `ForgotPasswordDto` | message | `200`; global errors | Slanje email verification linka. |
| `GET` | `/api/auth/verify-email` | Anonymous | `VerifyEmailDto` query | message | `200`; global errors | Verifikacija emaila preko query tokena. |
| `POST` | `/api/auth/send-verification-code` | Anonymous | `SendEmailVerificationCodeDto` | message | `200`; global errors | Slanje email verifikacijskog koda. |
| `POST` | `/api/auth/verify-email-code` | Anonymous | `VerifyEmailCodeDto` | message | `200`; global errors | Potvrda email koda. |
| `POST` | `/api/auth/login-2fa` | Anonymous | `LoginRequestDto` | 2FA login result | `200`; global errors | Login tok za korisnika sa 2FA. |
| `POST` | `/api/auth/verify-2fa` | Anonymous | `Verify2FADto` | auth result | `200`; global errors | Potvrda 2FA koda. |
| `POST` | `/api/auth/enable-2fa` | Authenticated | `ChangeTwoFactorSettingDto` | message | `200`; global errors | Uključivanje 2FA. |
| `POST` | `/api/auth/disable-2fa` | Authenticated | `ChangeTwoFactorSettingDto` | message | `200`; global errors | Isključivanje 2FA. |
| `GET` | `/api/auth/2fa-status` | Authenticated | - | `{ isEnabled }` | `200`; global errors | Status 2FA za trenutnog korisnika. |

## 4. Users, settings i onboarding

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/users/me` | Authenticated | - | current user profile DTO | `200`; global errors | Profil trenutnog korisnika. |
| `PUT` | `/api/users/me` | Authenticated | `UpdateUserProfileDto` | updated profile DTO | `200`; global errors | Ažuriranje profila. |
| `POST` | `/api/users/me/profile-image` | Authenticated | multipart `UploadProfileImageDto` | upload result | `200`; global errors | Upload profilne slike korisnika. |
| `GET` | `/api/user-settings/me` | Authenticated | - | user settings DTO | `200`; global errors | Postavke trenutnog korisnika. |
| `PUT` | `/api/user-settings/me` | Authenticated | `UpdateUserSettingsDto` | user settings DTO | `200`; global errors | Ažuriranje korisničkih postavki. |
| `GET` | `/api/client-onboarding` | Client | - | onboarding DTO | `200`; global errors | Dohvat onboarding preference podataka klijenta. |
| `PUT` | `/api/client-onboarding` | Client | `SaveClientOnboardingDto` | onboarding DTO | `200`; global errors | Spremanje client onboarding/preference podataka. |

## 5. Therapists

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/therapists` | Anonymous | - | therapist list | `200`; global errors | Javni listing terapeuta. |
| `GET` | `/api/therapists/search` | Anonymous | `SearchTherapistsDto` query | search result | `200`; global errors | Pretraga terapeuta. |
| `POST` | `/api/therapists/filter` | Anonymous | `TherapistFilterDto` | filtered result | `200`; global errors | Napredno filtriranje terapeuta. |
| `GET` | `/api/therapists/{id}` | Anonymous | route id | therapist details | `200`; global errors | Detalji terapeuta. |
| `POST` | `/api/therapists` | Therapist | `CreateTherapistDto` | therapist DTO | `201`; global errors | Kreiranje terapeutskog profila. |
| `GET` | `/api/therapists/profile` | Therapist | - | `TherapistProfileDto` | `200`; global errors | Vlastiti terapeutski profil. |
| `PUT` | `/api/therapists/profile` | Therapist | `UpdateTherapistProfileDto` | `204 No Content` | `204`; global errors | Ažuriranje terapeutskog profila. |
| `POST` | `/api/therapists/profile/image` | Therapist | multipart `UploadTherapistProfileImageDto` | `TherapistProfileImageDto` | `200`; global errors | Upload profilne slike terapeuta. |
| `DELETE` | `/api/therapists/profile/image` | Therapist | - | `204 No Content` | `204`; global errors | Brisanje profilne slike terapeuta. |
| `POST` | `/api/therapists/availability` | Therapist | `CreateAvailabilityDto` | `204 No Content` | `204`; global errors | Dodavanje availability termina. |
| `GET` | `/api/therapists/{therapistId}/availability` | Anonymous | route id | availability list | `200`; global errors | Javni availability terapeuta. |
| `DELETE` | `/api/therapists/availability/{availabilityId}` | Therapist | route id | `204 No Content` | `204`; global errors | Brisanje availability zapisa. |
| `POST` | `/api/therapists/unavailable-dates` | Therapist | `CreateUnavailableDateDto` | `204 No Content` | `204`; global errors | Dodavanje nedostupnog perioda. |
| `GET` | `/api/therapists/{therapistId}/unavailable-dates` | Anonymous | route id | unavailable dates list | `200`; global errors | Javni nedostupni periodi terapeuta. |
| `DELETE` | `/api/therapists/unavailable-dates/{id}` | Therapist | route id | `204 No Content` | `204`; global errors | Brisanje nedostupnog perioda. |
| `GET` | `/api/therapists/dashboard` | Therapist | - | dashboard DTO | `200`; global errors | Terapeutski dashboard. |
| `POST` | `/api/therapists/documents` | Therapist | multipart `UploadTherapistDocumentDto` | message | `200`; global errors | Upload verifikacijskog dokumenta. |
| `GET` | `/api/therapists/{therapistId}/documents` | Admin | route id | document list | `200`; global errors | Admin pregled dokumenata terapeuta. |
| `GET` | `/api/therapists/documents/{documentId}/download` | Admin | route id | file response | `200`; global errors | Download terapeutskog dokumenta. |
| `DELETE` | `/api/therapists/documents/{id}` | Therapist | route id | `204 No Content` | `204`; global errors | Brisanje vlastitog dokumenta. |
| `GET` | `/api/therapists/clients` | Therapist | `search` query | client list | `200`; global errors | Klijenti povezani sa terapeutom. |
| `GET` | `/api/therapists/clients/{clientId}` | Therapist | route id | client details | `200`; global errors | Detalji klijenta za terapeuta. |

## 6. Appointments

Base route: `/api/appointments`

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/appointments` | Client | `CreateAppointmentDto` + idempotency | appointment result | `200`; global errors | Rezervacija termina. |
| `GET` | `/api/appointments/mine` | Client | - | appointment list | `200`; global errors | Termini trenutnog klijenta. |
| `GET` | `/api/appointments/{appointmentId}` | Client | route id | appointment details | `200`; global errors | Detalji termina za klijenta. |
| `GET` | `/api/appointments/therapist` | Therapist | - | appointment list | `200`; global errors | Termini trenutnog terapeuta. |
| `PUT` | `/api/appointments/status` | Therapist | `UpdateAppointmentStatusDto` | `204 No Content` | `204`; global errors | Promjena statusa termina od terapeuta. |
| `PUT` | `/api/appointments/{appointmentId}/cancel` | Client | `CancelAppointmentDto` | `204 No Content` | `204`; global errors | Otkazivanje termina od klijenta. |
| `GET` | `/api/appointments/therapist/stats` | Therapist | - | stats DTO | `200`; global errors | Statistika terapeuta. |
| `POST` | `/api/appointments/notes` | Therapist | `CreateAppointmentNoteDto` | message | `200`; global errors | Dodavanje bilješki termina. |
| `GET` | `/api/appointments/{appointmentId}/notes` | Therapist | route id | `AppointmentNoteResponseDto` | `200`; global errors | Dohvat bilješki termina. |
| `GET` | `/api/appointments/client-dashboard` | Client | - | `ClientDashboardDto` | `200`; global errors | Dashboard za klijenta. |
| `PUT` | `/api/appointments/{appointmentId}/meeting-link` | Therapist | `UpdateMeetingLinkDto` | `204 No Content` | `204`; global errors | Ažuriranje meeting linka. |
| `GET` | `/api/appointments/therapist/{therapistId}/occupied-slots` | Client | `date` query | occupied slot list | `200`; global errors | Zauzeti termini terapeuta za datum. |

## 7. Payments i Stripe

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/payments/create-intent` | Client | `CreatePaymentIntentDto` + idempotency | payment intent DTO | `200`; global errors | Kreiranje Stripe PaymentIntent-a za appointment. |
| `POST` | `/api/payments/confirm` | Client | `ConfirmPaymentDto` | `204 No Content` | `204`; global errors | Potvrda plaćanja appointmenta. |
| `GET` | `/api/payments/mine` | Client | - | payment list | `200`; global errors | Plaćanja trenutnog klijenta. |
| `GET` | `/api/payments/{paymentId}/receipt` | Client | route id | receipt DTO | `200`; global errors | Račun/potvrda za payment. |
| `POST` | `/api/stripe/webhook` | Anonymous, Stripe signature | raw body + `Stripe-Signature` header | `{ received: true }` | `200`, `400`; global errors | Stripe webhook processing sa validacijom potpisa. |

Stripe webhook ne koristi JWT policy; zaštita je kriptografska validacija `Stripe-Signature` headera preko Stripe webhook secreta u infrastrukturi. Secret vrijednosti se ne prikazuju u dokumentaciji.

## 8. Memberships

Base route: `/api/memberships`

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/memberships/therapist/{therapistId}/plans` | Anonymous | route id | membership plan list | `200`; global errors | Planovi članarine za terapeuta. |
| `POST` | `/api/memberships/create-payment-intent` | Client | `CreateMembershipPaymentIntentDto` + idempotency | payment intent DTO | `200`; global errors | Kreiranje Stripe PaymentIntent-a za membership. |
| `POST` | `/api/memberships/confirm-payment` | Client | `ConfirmMembershipPaymentDto` + idempotency | membership/payment result | `200`; global errors | Potvrda membership plaćanja. |
| `GET` | `/api/memberships/mine` | Client | - | membership list | `200`; global errors | Članarine trenutnog klijenta. |
| `GET` | `/api/memberships/{membershipId}/receipt` | Client | route id | receipt DTO | `200`; global errors | Račun za membership. |
| `POST` | `/api/memberships/use` | Client | `UseMembershipDto` | `204 No Content` | `204`; global errors | Korištenje membership sesije za appointment. |

## 9. Recommendations

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/recommendations/therapists` | Client | `TherapistRecommendationRequestDto` | `IReadOnlyList<TherapistRecommendationDto>` | documented `200`, `401`, `404`; global errors | Preporuka terapeuta prema preference podacima klijenta i dostupnim terapeutima. |

Ako izračun preporuka baci neočekivanu grešku, controller loguje upozorenje i vraća siguran prazan niz sa `200`, što je stvarno ponašanje controller action-a.

## 10. Reviews

Base route: `/api/reviews`

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/reviews/public` | Anonymous | `limit` query | public reviews | `200`; global errors | Javni review prikaz. |
| `POST` | `/api/reviews` | Client | `CreateReviewDto` | message | `201`; global errors | Kreiranje review-a nakon termina. |
| `GET` | `/api/reviews/therapist/{therapistId}` | Anonymous | route id + `ReviewFilterDto` query | review list/paged | `200`; global errors | Review-i za terapeuta. |
| `GET` | `/api/reviews/therapist/{therapistId}/rating` | Anonymous | route id | rating summary | `200`; global errors | Prosječna ocjena terapeuta. |
| `GET` | `/api/reviews/eligibility/{appointmentId}` | Client | route id | eligibility DTO | `200`; global errors | Provjera da li klijent može ostaviti review. |
| `GET` | `/api/reviews/mine` | Client | `pageNumber`, `pageSize` query | paged reviews | `200`; global errors | Review-i trenutnog klijenta. |
| `PUT` | `/api/reviews/{reviewId}` | Client | `UpdateReviewDto` | `204 No Content` | `204`; global errors | Ažuriranje vlastitog review-a. |
| `DELETE` | `/api/reviews/{reviewId}` | Client | route id | `204 No Content` | `204`; global errors | Brisanje vlastitog review-a. |
| `PUT` | `/api/reviews/{reviewId}/reply` | Therapist | `ReplyToReviewDto` | `204 No Content` | `204`; global errors | Odgovor terapeuta na review. |

## 11. Articles

Base route: `/api/articles`

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/articles` | Anonymous | `ArticleQueryDto` query | public article list | `200`; global errors | Javni pregled članaka. |
| `GET` | `/api/articles/{id}` | Anonymous | route id | `ArticleResponseDto` | `200`; global errors | Detalji članka. |
| `GET` | `/api/articles/categories` | Anonymous | - | category list | `200`; global errors | Javne kategorije članaka. |
| `GET` | `/api/articles/management` | Admin | `ArticleManagementQueryDto` query | management list | `200`; global errors | Admin pregled članaka. |
| `GET` | `/api/articles/management/{id}` | Admin | route id | management detail | `200`; global errors | Admin detalji članka. |
| `POST` | `/api/articles` | Admin or Therapist | `CreateArticleDto` | `ArticleResponseDto` | `200`; global errors | Kreiranje članka. |
| `PUT` | `/api/articles/{id}` | Admin or Therapist | `UpdateArticleDto` | `ArticleResponseDto` | `200`; global errors | Ažuriranje članka. |
| `PUT` | `/api/articles/{id}/publication` | Admin or Therapist | `UpdateArticlePublicationDto` | `ArticleResponseDto` | `200`; global errors | Promjena publish statusa. |
| `DELETE` | `/api/articles/{id}` | Admin or Therapist | route id | message | `200`; global errors | Brisanje članka. |
| `POST` | `/api/articles/image` | Admin or Therapist | multipart `IFormFile file` | `ArticleImageUploadDto` | `200`; global errors | Upload slike za članak. |

## 12. Workshops

Base route: `/api/workshops`

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/workshops` | Anonymous | `WorkshopQueryDto` query | public workshop list | `200`; global errors | Javni pregled radionica. |
| `GET` | `/api/workshops/{id}` | Anonymous | route id | workshop details | `200`; global errors | Detalji radionice. |
| `GET` | `/api/workshops/manage` | Admin or Therapist | `WorkshopQueryDto` query | management list | `200`; global errors | Admin/therapist pregled radionica. |
| `GET` | `/api/workshops/{id}/registrations` | Admin or Therapist | `pageNumber`, `pageSize` query | registration list | `200`; global errors | Registracije za radionicu. |
| `POST` | `/api/workshops` | Admin or Therapist | `CreateWorkshopDto` | workshop DTO | `200`; global errors | Kreiranje radionice. |
| `PUT` | `/api/workshops/{id}` | Admin or Therapist | `UpdateWorkshopDto` | workshop DTO | `200`; global errors | Ažuriranje radionice. |
| `PUT` | `/api/workshops/{id}/status` | Admin or Therapist | `UpdateWorkshopStatusDto` | workshop DTO | `200`; global errors | Promjena statusa radionice. |
| `DELETE` | `/api/workshops/{id}` | Admin or Therapist | route id | message | `200`; global errors | Brisanje radionice. |
| `POST` | `/api/workshops/{id}/register` | Client | route id + idempotency | message | `200`; global errors | Registracija klijenta na radionicu. |
| `DELETE` | `/api/workshops/{id}/registration` | Client | route id | message | `200`; global errors | Otkazivanje vlastite registracije. |
| `GET` | `/api/workshops/mine` | Client | `pageNumber`, `pageSize` query | registration list | `200`; global errors | Moje registracije na radionice. |
| `POST` | `/api/workshops/image` | Admin or Therapist | multipart `IFormFile file` | upload result | `200`; global errors | Upload slike radionice. |

## 13. Notifications

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/notifications` | Authenticated | `NotificationQueryDto` query | notification list/paged | `200`; global errors | Notifikacije trenutnog korisnika. |
| `GET` | `/api/notifications/unread-count` | Authenticated | - | `{ unreadCount }` | `200`; global errors | Broj nepročitanih notifikacija. |
| `PUT` | `/api/notifications/{notificationId}/read` | Authenticated | route id | message | `200`; global errors | Označavanje notifikacije kao pročitane. |
| `PUT` | `/api/notifications/read-all` | Authenticated | - | message | `200`; global errors | Označavanje svih notifikacija kao pročitanih. |
| `POST` | `/api/fcm-tokens` | Authenticated | `RegisterFcmTokenDto` | `204 No Content` | `204`; global errors | Registracija FCM tokena uređaja. |
| `DELETE` | `/api/fcm-tokens` | Authenticated | `UnregisterFcmTokenDto` | `204 No Content` | `204`; global errors | Deaktivacija/uklanjanje FCM tokena. |

## 14. Chat

REST chat endpointi služe za conversation i historiju poruka. SignalR hub `/hubs/chat` je odvojen realtime kanal i nije REST API.

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/chat/appointments/{appointmentId}/conversation` | Client or Therapist | route id | conversation DTO | `200`; global errors | Dohvat ili kreiranje conversation-a za appointment. |
| `GET` | `/api/chat/conversations/{conversationId}/messages` | Client or Therapist | `ChatPagingQueryDto` query | paged messages | `200`; global errors | Historija poruka. |
| `POST` | `/api/chat/messages` | Client or Therapist | `SendChatMessageDto` | message DTO | `200`; global errors | Slanje chat poruke preko REST-a. |
| `PUT` | `/api/chat/conversations/{conversationId}/read` | Client or Therapist | route id | message | `200`; global errors | Označavanje conversation-a kao pročitanog. |
| `GET` | `/api/chat/conversations` | Client or Therapist | - | conversation list | `200`; global errors | Razgovori trenutnog korisnika. |

## 15. Admin

Base route: `/api/admin`, policy `AdminOnly`. Admin sekcija obuhvata upravljanje korisnicima, terapeutskom verifikacijom, review moderacijom, appointmentima, paymentima i membership planovima.

| Method | Route | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- |
| `GET` | `/api/admin/users` | `SearchAdminUsersDto` query | paged users | `200`; global errors | Pretraga i pregled korisnika. |
| `GET` | `/api/admin/users/{userId}` | route id | user details | `200`; global errors | Detalji korisnika. |
| `PUT` | `/api/admin/users/{userId}` | `UpdateAdminUserDto` | message | `200`; global errors | Ažuriranje korisnika. |
| `PUT` | `/api/admin/users/{userId}/status` | `UpdateUserStatusDto` | message | `200`; global errors | Aktivacija/deaktivacija korisnika. |
| `POST` | `/api/admin/users/{userId}/unlock` | route id | message | `200`; global errors | Uklanjanje privremenog lockout-a. |
| `POST` | `/api/admin/users/{userId}/send-password-reset` | route id | message | `200`; global errors | Slanje password reset emaila. |
| `DELETE` | `/api/admin/users/{userId}` | route id | message | `405` | Permanentno brisanje nije dozvoljeno. |
| `GET` | `/api/admin/therapists/pending` | `SearchTherapistVerificationDto` query | pending therapists | `200`; global errors | Terapeuti koji čekaju verifikaciju. |
| `GET` | `/api/admin/therapists/{therapistId}/verification` | route id | verification details | `200`; global errors | Detalji verifikacije terapeuta. |
| `PUT` | `/api/admin/therapists/{therapistId}/verification` | `UpdateTherapistVerificationDto` | message | `200`; global errors | Odobravanje/odbijanje/promjena verifikacije. |
| `GET` | `/api/admin/dashboard` | - | dashboard DTO | `200`; global errors | Admin dashboard. |
| `GET` | `/api/admin/reviews` | `SearchAdminReviewsDto` query | paged reviews | `200`; global errors | Admin pregled review-a. |
| `GET` | `/api/admin/reviews/{reviewId}` | route id | review details | `200`; global errors | Detalji review-a. |
| `PUT` | `/api/admin/reviews/{reviewId}/approve` | route id | message | `200`; global errors | Odobravanje review-a. |
| `PUT` | `/api/admin/reviews/{reviewId}/reject` | `RejectAdminReviewDto` | message | `200`; global errors | Odbijanje review-a. |
| `PUT` | `/api/admin/reviews/{reviewId}/hide` | `HideAdminReviewDto` | message | `200`; global errors | Sakrivanje review-a. |
| `PUT` | `/api/admin/reviews/{reviewId}/delete` | `DeleteAdminReviewDto` | message | `200`; global errors | Admin uklanjanje review-a. |
| `GET` | `/api/admin/appointments` | `SearchAdminAppointmentsDto` query | paged appointments | `200`; global errors | Admin pregled termina. |
| `GET` | `/api/admin/appointments/{appointmentId}` | route id | appointment details | `200`; global errors | Admin detalji termina. |
| `PUT` | `/api/admin/appointments/{appointmentId}/cancel` | `AdminCancelAppointmentDto` | message | `200`; global errors | Admin otkazivanje termina. |
| `GET` | `/api/admin/payments` | `SearchAdminPaymentsDto` query | paged payments | `200`; global errors | Admin pregled plaćanja. |
| `GET` | `/api/admin/payments/{paymentType}/{paymentId}` | route params | payment details | `200`; global errors | Detalji appointment ili membership paymenta. |
| `GET` | `/api/admin/payments/{paymentType}/{paymentId}/receipt` | route params | receipt DTO | `200`; global errors | Admin receipt za payment. |
| `PUT` | `/api/admin/payments/{paymentType}/{paymentId}/refund` | `AdminRefundPaymentDto` + idempotency | message | `200`; global errors | Admin refund flow. |
| `GET` | `/api/admin/memberships` | `SearchAdminMembershipsDto` query | paged memberships | `200`; global errors | Admin pregled članarina. |
| `GET` | `/api/admin/memberships/{membershipId}` | route id | membership details | `200`; global errors | Detalji članarine. |
| `GET` | `/api/admin/membership-plans` | - | plan list | `200`; global errors | Pregled membership planova. |
| `GET` | `/api/admin/membership-plans/{planId}` | route id | plan details | `200`; global errors | Detalji plana. |
| `POST` | `/api/admin/membership-plans` | `CreateMembershipPlanDto` | created result | `201`; global errors | Kreiranje membership plana. |
| `PUT` | `/api/admin/membership-plans/{planId}` | `UpdateMembershipPlanDto` | message | `200`; global errors | Ažuriranje plana. |
| `PUT` | `/api/admin/membership-plans/{planId}/status` | `UpdateMembershipPlanStatusDto` | message | `200`; global errors | Aktivacija/deaktivacija plana. |
| `DELETE` | `/api/admin/membership-plans/{planId}` | route id | message | `200`; global errors | Brisanje/deaktivacija plana. |
| `GET` | `/api/admin/membership-plans/{planId}/history` | route id | audit history | `200`; global errors | Historija promjena plana. |

## 16. Reports i audit

Report endpointi su Admin-only i vraćaju DTO podatke, ne PDF/file response u trenutnoj controller implementaciji.

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/admin/reports/dashboard` | Admin | `AdminDashboardReportQueryDto` query | `AdminDashboardReportDto` | `200`; global errors | Dashboard report. |
| `GET` | `/api/admin/reports/appointments-revenue` | Admin | `AppointmentRevenueReportQueryDto` query | `AppointmentRevenueReportDto` | `200`, direct `401`; global errors | Revenue report za appointment plaćanja. |
| `GET` | `/api/admin/reports/therapist-performance` | Admin | `TherapistPerformanceReportQueryDto` query | `TherapistPerformanceReportDto` | `200`; global errors | Performance report terapeuta. |
| `GET` | `/api/admin/audit-logs` | Admin | `SearchAdminAuditLogsDto` query | `PagedResponse<AdminAuditLogDto>` | `200`; global errors | Admin audit logovi. |
| `GET` | `/api/admin/audit-logs/filter-options` | Admin | - | `AdminAuditFilterOptionsDto` | `200`; global errors | Filter opcije za audit. |
| `GET` | `/api/admin/audit-logs/security` | Admin | `SearchSecurityAuditLogsDto` query | `PagedResponse<SecurityAuditLogDto>` | `200`; global errors | Security audit logovi. |
| `POST/PUT/PATCH/DELETE` | `/api/admin/audit-logs` | Admin | - | message | `405` | Audit logovi su read-only kroz API. |

## 17. Reference Data

Base route: `/api/reference-data`. Active lookup read endpointi su javni, a management CRUD endpointi su Admin-only.

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/reference-data/therapist-specializations/active` | Anonymous | - | specialization list | `200`; global errors | Javne aktivne specijalizacije. |
| `GET` | `/api/reference-data/therapist-specializations` | Admin | query DTO | paged response | `200`; global errors | Admin lista specijalizacija. |
| `GET` | `/api/reference-data/therapist-specializations/{id}` | Admin | route id | specialization DTO | `200`; global errors | Detalj specijalizacije. |
| `POST` | `/api/reference-data/therapist-specializations` | Admin | create DTO | specialization DTO | `201`; global errors | Kreiranje specijalizacije. |
| `PUT` | `/api/reference-data/therapist-specializations/{id}` | Admin | update DTO | specialization DTO | `200`; global errors | Ažuriranje specijalizacije. |
| `PUT` | `/api/reference-data/therapist-specializations/{id}/status` | Admin | status DTO | specialization DTO | `200`; global errors | Promjena statusa specijalizacije. |
| `DELETE` | `/api/reference-data/therapist-specializations/{id}` | Admin | route id | `204 No Content` | `204`; global errors | Brisanje specijalizacije. |
| `GET` | `/api/reference-data/therapy-approaches/active` | Anonymous | - | therapy approach list | `200`; global errors | Javni aktivni terapijski pristupi. |
| `GET` | `/api/reference-data/therapy-approaches` | Admin | query DTO | paged response | `200`; global errors | Admin lista pristupa. |
| `GET` | `/api/reference-data/therapy-approaches/{id}` | Admin | route id | approach DTO | `200`; global errors | Detalj pristupa. |
| `POST` | `/api/reference-data/therapy-approaches` | Admin | create DTO | approach DTO | `201`; global errors | Kreiranje pristupa. |
| `PUT` | `/api/reference-data/therapy-approaches/{id}` | Admin | update DTO | approach DTO | `200`; global errors | Ažuriranje pristupa. |
| `PUT` | `/api/reference-data/therapy-approaches/{id}/status` | Admin | status DTO | approach DTO | `200`; global errors | Promjena statusa pristupa. |
| `DELETE` | `/api/reference-data/therapy-approaches/{id}` | Admin | route id | `204 No Content` | `204`; global errors | Brisanje pristupa. |
| `GET` | `/api/reference-data/article-categories/active` | Anonymous | - | category list | `200`; global errors | Javne aktivne kategorije članaka. |
| `GET` | `/api/reference-data/article-categories` | Admin | query DTO | paged response | `200`; global errors | Admin lista kategorija. |
| `GET` | `/api/reference-data/article-categories/{id}` | Admin | route id | category DTO | `200`; global errors | Detalj kategorije. |
| `POST` | `/api/reference-data/article-categories` | Admin | create DTO | category DTO | `201`; global errors | Kreiranje kategorije. |
| `PUT` | `/api/reference-data/article-categories/{id}` | Admin | update DTO | category DTO | `200`; global errors | Ažuriranje kategorije. |
| `PUT` | `/api/reference-data/article-categories/{id}/status` | Admin | status DTO | category DTO | `200`; global errors | Promjena statusa kategorije. |
| `DELETE` | `/api/reference-data/article-categories/{id}` | Admin | route id | `204 No Content` | `204`; global errors | Brisanje kategorije. |
| `GET` | `/api/therapyapproaches/public` | Anonymous | - | anonymous projection | `200`; global errors | Legacy/javni endpoint za aktivne therapy approaches. |

## 18. Dodatni API moduli

### Favorites

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/favorites` | Client | `AddFavoriteDto` | message | `200`; global errors | Dodavanje terapeuta u favorite. |
| `DELETE` | `/api/favorites/{therapistId}` | Client | route id | message | `200`; global errors | Uklanjanje terapeuta iz favorita. |
| `GET` | `/api/favorites/mine` | Client | - | favorite list | `200`; global errors | Favoriti trenutnog klijenta. |

### Privacy / consent

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/api/privacy/current-versions` | Anonymous | - | current consent versions | `200`; global errors | Verzije privacy/terms dokumenata. |
| `GET` | `/api/privacy/my-consents` | Authenticated | - | consent list | `200`; global errors | Saglasnosti trenutnog korisnika. |

### Journal, mood i private journal

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `POST` | `/api/journalentries` | Client | `CreateJournalEntryDto` | journal DTO | `200`; global errors | Kreiranje mood/journal zapisa. |
| `GET` | `/api/journalentries/mine` | Client | paging/date query | paged journal entries | `200`; global errors | Vlastiti journal/mood zapisi. |
| `GET` | `/api/journalentries/{id}` | Client | route id | journal DTO | `200`; global errors | Detalj vlastitog zapisa. |
| `PUT` | `/api/journalentries/{id}` | Client | `UpdateJournalEntryDto` | journal DTO | `200`; global errors | Ažuriranje zapisa. |
| `DELETE` | `/api/journalentries/{id}` | Client | route id | message | `200`; global errors | Brisanje zapisa. |
| `GET` | `/api/journalentries/clients/{clientId}/history` | Therapist | paging query | client history | `200`; global errors | Historija klijenta vidljiva terapeutu. |
| `GET` | `/api/journalentries/clients/{clientId}/trend` | Therapist | `days` query | trend DTO | `200`; global errors | Trend emocionalnih zapisa klijenta. |
| `GET` | `/api/journalentries/clients/{clientId}/analytics` | Therapist | `days` query | analytics/trend DTO | `200`; global errors | Analitika klijenta za terapeuta. |
| `GET` | `/api/journalentries/analytics/mine` | Client | date range query | analytics DTO | `200`; global errors | Vlastita mood/journal analitika. |
| `POST` | `/api/privatejournalentries` | Client | `CreatePrivateJournalEntryDto` | private journal DTO | `200`; global errors | Kreiranje privatnog journal zapisa. |
| `GET` | `/api/privatejournalentries/mine` | Client | query DTO | list/paged result | `200`; global errors | Vlastiti privatni journal zapisi. |
| `GET` | `/api/privatejournalentries/{id}` | Client | route id | private journal DTO | `200`; global errors | Detalj privatnog zapisa. |
| `PUT` | `/api/privatejournalentries/{id}` | Client | `UpdatePrivateJournalEntryDto` | private journal DTO | `200`; global errors | Ažuriranje privatnog zapisa. |
| `DELETE` | `/api/privatejournalentries/{id}` | Client | route id | message | `200`; global errors | Brisanje privatnog zapisa. |

### Health, metrics i hubs

| Method | Route | Auth/Role | Request | Response | Status codes | Poslovna svrha |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/health/live` | Anonymous | - | health check | health status | Liveness provjera. |
| `GET` | `/health/ready` | Anonymous | - | health check | health status | Readiness provjera tagged health checkova. |
| `GET` | `/metrics` | Anonymous + `X-Metrics-Key` | header key | metrics snapshot | `200`, `401`, `503` | Zaštićeni metrics snapshot bez JWT-a. |

`/hubs/notifications` i `/hubs/chat` su SignalR endpoints sa authorization zahtjevom; nisu REST endpointi.

## 19. Status codes i Swagger/OpenAPI

Task 190 je standardizovao Swagger/OpenAPI metapodatke. Swagger je detaljni schema explorer i interaktivni alat za testiranje, dok ovaj dokument daje poslovni pregled REST površine. U endpoint tabelama su navedeni direktni success statusi potvrđeni iz action implementacije (`Ok`, `CreatedAtAction`, `NoContent`, `StatusCode(201)`, `StatusCode(405)`, `BadRequest`) i globalni error statusi preko middleware-a gdje su relevantni.

Ne treba pretpostaviti da svaki endpoint uvijek vraća svaki globalni status. `400`, `401`, `403`, `404`, `409`, `503` i `500` zavise od validacije, authorizationa, service-layer exceptiona i vanjskih integracija.

## 20. Sažetak za odbranu

REST API je organizovan po poslovnim controllerima: auth, korisnici, terapeuti, termini, plaćanja, članarine, preporuke, review-i, članci, radionice, notifikacije, chat, admin, reporti i referentni podaci.

Korisnik se autentificira kroz `/api/auth/login`, dobija JWT/refresh token tok, a endpointi se štite policy pravilima kao `ClientOnly`, `TherapistOnly` i `AdminOnly`. Appointment flow ide preko `/api/appointments`: klijent kreira termin, terapeut upravlja statusom i bilješkama, a payment flow koristi `/api/payments` ili membership payment endpoint-e. Stripe webhook je poseban anonymous endpoint koji ne koristi JWT, nego signature validation.

Admin portal koristi `/api/admin`, `/api/admin/reports` i `/api/admin/audit-logs` za upravljanje korisnicima, verifikacijom terapeuta, review moderacijom, paymentima, membership planovima, dashboardom i reportima. Chat ima REST endpoint-e za conversation i historiju, dok realtime dio ide odvojeno preko SignalR hubova. Swagger/OpenAPI ostaje glavni alat za detaljne DTO sheme i interaktivno pozivanje endpointa.
