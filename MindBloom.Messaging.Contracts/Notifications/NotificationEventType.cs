namespace MindBloom.Messaging.Contracts.Notifications;

public enum NotificationEventType
{
    Unknown = 0,

    UserRegistered = 1,
    EmailVerificationRequested = 2,
    PasswordResetRequested = 3,
    TwoFactorCodeRequested = 4,

    AppointmentCreated = 10,
    AppointmentApproved = 11,
    AppointmentRejected = 12,
    AppointmentCancelled = 13,
    AppointmentReminder = 14,
    AppointmentCompleted = 15,

    PaymentCompleted = 20,
    PaymentFailed = 21,
    RefundRequested = 22,
    RefundCompleted = 23,
    RefundFailed = 24,

    MembershipActivated = 30,
    MembershipExpiring = 31,
    MembershipExpired = 32,

    TherapistVerificationApproved = 40,
    TherapistVerificationRejected = 41,

    WorkshopRegistrationConfirmed = 50,
    WorkshopRegistrationCancelled = 51,
    WorkshopReminder = 52,

    GenericEmail = 100
}