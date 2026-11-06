import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_details_model.dart';

void main() {
  for (final (amount, expected) in [
    (50.0, '50.00 USD'),
    (50.5, '50.50 USD'),
    (1234.56, '1234.56 USD'),
  ]) {
    test('Therapist detail displays $expected without converting $amount', () {
      final therapist = TherapistDetailsModel.fromJson({'hourlyRate': amount});
      expect(therapist.displayPrice, expected);
      expect(therapist.hourlyRate, amount);
    });
  }

  test('Unspecified therapist rate remains unspecified', () {
    final therapist = TherapistDetailsModel.fromJson({'hourlyRate': 0});
    expect(therapist.displayPrice, 'Not specified');
    expect(therapist.hourlyRate, 0);
  });
}
