import 'package:flutter/material.dart';

enum AdminSection {
  dashboard,
  users,
  therapists,
  appointments,
  payments,
  memberships,
  workshops,
  articles,
  reviews,
}

extension AdminSectionExtension on AdminSection {
  String get title {
    switch (this) {
      case AdminSection.dashboard:
        return 'Dashboard';

      case AdminSection.users:
        return 'Users';

      case AdminSection.therapists:
        return 'Therapists';

      case AdminSection.appointments:
        return 'Appointments';

      case AdminSection.payments:
        return 'Payments';

      case AdminSection.memberships:
        return 'Memberships';

      case AdminSection.workshops:
        return 'Workshops';

      case AdminSection.articles:
        return 'Articles';

      case AdminSection.reviews:
        return 'Reviews';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.dashboard_outlined;

      case AdminSection.users:
        return Icons.people_outline;

      case AdminSection.therapists:
        return Icons.psychology_outlined;

      case AdminSection.appointments:
        return Icons.calendar_month_outlined;

      case AdminSection.payments:
        return Icons.payments_outlined;

      case AdminSection.memberships:
        return Icons.card_membership_outlined;

      case AdminSection.workshops:
        return Icons.groups_outlined;

      case AdminSection.articles:
        return Icons.article_outlined;

      case AdminSection.reviews:
        return Icons.reviews_outlined;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.dashboard;

      case AdminSection.users:
        return Icons.people;

      case AdminSection.therapists:
        return Icons.psychology;

      case AdminSection.appointments:
        return Icons.calendar_month;

      case AdminSection.payments:
        return Icons.payments;

      case AdminSection.memberships:
        return Icons.card_membership;

      case AdminSection.workshops:
        return Icons.groups;

      case AdminSection.articles:
        return Icons.article;

      case AdminSection.reviews:
        return Icons.reviews;
    }
  }
}
