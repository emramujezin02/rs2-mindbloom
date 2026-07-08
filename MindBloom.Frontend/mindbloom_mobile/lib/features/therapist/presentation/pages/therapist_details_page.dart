import 'package:flutter/material.dart';

import '../../data/models/therapist_model.dart';

class TherapistDetailsPage extends StatelessWidget {
  final TherapistModel therapist;

  const TherapistDetailsPage({super.key, required this.therapist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(therapist.fullName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 45,
              child: Text(
                therapist.fullName.isNotEmpty ? therapist.fullName[0] : '?',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              therapist.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              therapist.specialization,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.star,
                      label: 'Rating',
                      value: therapist.averageRating.toStringAsFixed(1),
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.work,
                      label: 'Experience',
                      value: '${therapist.experienceYears} years',
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.payments,
                      label: 'Price',
                      value: '${therapist.hourlyRate.toStringAsFixed(2)} KM',
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: therapist.email,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Biography',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              therapist.biography.isEmpty
                  ? 'No biography added.'
                  : therapist.biography,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appointment booking will be added next.'),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Book appointment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
