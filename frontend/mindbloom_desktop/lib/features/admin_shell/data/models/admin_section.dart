import 'package:flutter/material.dart';

enum AdminSection {
  dashboard,
  users,
  therapists,
  appointments,
  payments,
  memberships,
  reviews,
  articles,
  workshops,
  referenceData,
  auditLogs,
  appointmentRevenueReport,
  therapistPerformanceReport,
  settings,
}

extension AdminSectionExtension on AdminSection {
  String get title {
    switch (this) {
      case AdminSection.dashboard:
        return 'Dashboard';

      case AdminSection.users:
        return 'Users';

      case AdminSection.therapists:
        return 'Therapist Verification';

      case AdminSection.appointments:
        return 'Appointments';

      case AdminSection.payments:
        return 'Payments';

      case AdminSection.memberships:
        return 'Memberships';

      case AdminSection.reviews:
        return 'Reviews';

      case AdminSection.articles:
        return 'Articles';

      case AdminSection.workshops:
        return 'Workshops';

      case AdminSection.referenceData:
        return 'Reference Data';

      case AdminSection.auditLogs:
        return 'Audit Log';

      case AdminSection.appointmentRevenueReport:
        return 'Appointment Revenue Report';

      case AdminSection.therapistPerformanceReport:
        return 'Therapist Performance Report';

      case AdminSection.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.dashboard_outlined;

      case AdminSection.users:
        return Icons.people_outline;

      case AdminSection.therapists:
        return Icons.verified_user_outlined;

      case AdminSection.appointments:
        return Icons.calendar_month_outlined;

      case AdminSection.payments:
        return Icons.payments_outlined;

      case AdminSection.memberships:
        return Icons.card_membership_outlined;

      case AdminSection.reviews:
        return Icons.reviews_outlined;

      case AdminSection.articles:
        return Icons.article_outlined;

      case AdminSection.workshops:
        return Icons.groups_outlined;

      case AdminSection.referenceData:
        return Icons.list_alt_outlined;

      case AdminSection.auditLogs:
        return Icons.manage_search_outlined;

      case AdminSection.appointmentRevenueReport:
        return Icons.picture_as_pdf_outlined;

      case AdminSection.therapistPerformanceReport:
        return Icons.assessment_outlined;

      case AdminSection.settings:
        return Icons.settings_outlined;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.dashboard;

      case AdminSection.users:
        return Icons.people;

      case AdminSection.therapists:
        return Icons.verified_user;

      case AdminSection.appointments:
        return Icons.calendar_month;

      case AdminSection.payments:
        return Icons.payments;

      case AdminSection.memberships:
        return Icons.card_membership;

      case AdminSection.reviews:
        return Icons.reviews;

      case AdminSection.articles:
        return Icons.article;

      case AdminSection.workshops:
        return Icons.groups;

      case AdminSection.referenceData:
        return Icons.list_alt;

      case AdminSection.auditLogs:
        return Icons.manage_search;

      case AdminSection.appointmentRevenueReport:
        return Icons.picture_as_pdf;

      case AdminSection.therapistPerformanceReport:
        return Icons.assessment;

      case AdminSection.settings:
        return Icons.settings;
    }
  }

  bool get isReport {
    return this == AdminSection.appointmentRevenueReport ||
        this == AdminSection.therapistPerformanceReport;
  }
}
