import 'package:flutter/material.dart';

class MoodOption {
  final int value;
  final String label;
  final String description;
  final IconData icon;

  const MoodOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}

const moodOptions = [
  MoodOption(
    value: 1,
    label: 'Very low',
    description: 'I am having a very difficult day.',
    icon: Icons.sentiment_very_dissatisfied,
  ),
  MoodOption(
    value: 2,
    label: 'Low',
    description: 'I am feeling below average.',
    icon: Icons.sentiment_dissatisfied,
  ),
  MoodOption(
    value: 3,
    label: 'Neutral',
    description: 'I feel balanced or neutral.',
    icon: Icons.sentiment_neutral,
  ),
  MoodOption(
    value: 4,
    label: 'Good',
    description: 'I am feeling positive.',
    icon: Icons.sentiment_satisfied,
  ),
  MoodOption(
    value: 5,
    label: 'Very good',
    description: 'I am feeling excellent.',
    icon: Icons.sentiment_very_satisfied,
  ),
];

const emotionOptions = [
  'Happy',
  'Calm',
  'Hopeful',
  'Excited',
  'Grateful',
  'Sad',
  'Anxious',
  'Angry',
  'Lonely',
  'Tired',
  'Stressed',
  'Confused',
];

MoodOption moodOptionFor(int value) {
  return moodOptions.firstWhere(
    (option) => option.value == value,
    orElse: () => moodOptions[2],
  );
}
