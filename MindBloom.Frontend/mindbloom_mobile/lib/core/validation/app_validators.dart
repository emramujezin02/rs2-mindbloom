class AppValidators {
  AppValidators._();

  static const int minimumPasswordLength = 6;

  static String? requiredText(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName je obavezno polje.';
    }

    return null;
  }

  static String? textLength(
    String? value, {
    required String fieldName,
    int? minimumLength,
    int? maximumLength,
    bool required = true,
  }) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return required ? '$fieldName je obavezno polje.' : null;
    }

    if (minimumLength != null && normalized.length < minimumLength) {
      return '$fieldName mora sadržavati najmanje '
          '$minimumLength znakova.';
    }

    if (maximumLength != null && normalized.length > maximumLength) {
      return '$fieldName može sadržavati najviše '
          '$maximumLength znakova.';
    }

    return null;
  }

  static String? email(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return 'Email je obavezno polje.';
    }

    final expression = RegExp(
      r'^[A-Za-z0-9.!#$%&'
      '*+/=?^_`{|}~-]+'
      r'@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
    );

    if (!expression.hasMatch(normalized)) {
      return 'Unesite ispravnu email adresu.';
    }

    if (normalized.length > 254) {
      return 'Email adresa može sadržavati najviše 254 znaka.';
    }

    return null;
  }

  static String? phone(String? value, {bool required = false}) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return required ? 'Broj telefona je obavezno polje.' : null;
    }

    final expression = RegExp(r'^\+?[0-9][0-9\s\-]{6,19}$');

    if (!expression.hasMatch(normalized)) {
      return 'Unesite ispravan broj telefona.';
    }

    return null;
  }

  static String? password(String? value, {String fieldName = 'Lozinka'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName je obavezno polje.';
    }

    if (value.length < minimumPasswordLength) {
      return '$fieldName mora sadržavati najmanje '
          '$minimumPasswordLength znakova.';
    }

    if (value.length > 128) {
      return '$fieldName može sadržavati najviše 128 znakova.';
    }

    return null;
  }

  static String? requiredPassword(
    String? value, {
    String fieldName = 'Lozinka',
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName je obavezno polje.';
    }

    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Potvrda lozinke je obavezno polje.';
    }

    if (value != password) {
      return 'Lozinke se ne podudaraju.';
    }

    return null;
  }

  static String? sixDigitCode(
    String? value, {
    String fieldName = 'Verifikacijski kod',
  }) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return '$fieldName je obavezno polje.';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      return '$fieldName mora sadržavati tačno 6 cifara.';
    }

    return null;
  }

  static String? dateOfBirth(DateTime? value) {
    if (value == null) {
      return 'Datum rođenja je obavezan.';
    }

    final today = DateTime.now();

    final normalizedToday = DateTime(today.year, today.month, today.day);

    final normalizedValue = DateTime(value.year, value.month, value.day);

    if (!normalizedValue.isBefore(normalizedToday)) {
      return 'Datum rođenja mora biti u prošlosti.';
    }

    final oldestAllowed = DateTime(
      normalizedToday.year - 120,
      normalizedToday.month,
      normalizedToday.day,
    );

    if (normalizedValue.isBefore(oldestAllowed)) {
      return 'Datum rođenja nije ispravan.';
    }

    return null;
  }

  static String? adultDateOfBirth(DateTime? value) {
    final basicError = dateOfBirth(value);

    if (basicError != null) {
      return basicError;
    }

    final today = DateTime.now();

    var age = today.year - value!.year;

    final birthdayPassed =
        today.month > value.month ||
        today.month == value.month && today.day >= value.day;

    if (!birthdayPassed) {
      age--;
    }

    if (age < 18) {
      return 'Za registraciju morate imati najmanje 18 godina.';
    }

    return null;
  }

  static String? optionalDecimal(
    String? value, {
    required String fieldName,
    double minimum = 0,
    double? maximum,
  }) {
    final normalized = value?.trim().replaceAll(',', '.') ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    final number = double.tryParse(normalized);

    if (number == null) {
      return 'Unesite ispravnu vrijednost za polje '
          '$fieldName.';
    }

    if (number < minimum) {
      return '$fieldName ne može biti manje od '
          '${_formatNumber(minimum)}.';
    }

    if (maximum != null && number > maximum) {
      return '$fieldName ne može biti veće od '
          '${_formatNumber(maximum)}.';
    }

    return null;
  }

  static String? price(
    String? value, {
    String fieldName = 'Cijena',
    bool required = false,
    double maximum = 100000,
  }) {
    final normalized = value?.trim().replaceAll(',', '.') ?? '';

    if (normalized.isEmpty) {
      return required ? '$fieldName je obavezno polje.' : null;
    }

    final number = double.tryParse(normalized);

    if (number == null) {
      return 'Unesite ispravnu cijenu.';
    }

    if (number < 0) {
      return '$fieldName ne može biti negativna.';
    }

    if (number > maximum) {
      return '$fieldName ne može biti veća od '
          '${_formatNumber(maximum)}.';
    }

    return null;
  }

  static String? priceRange({
    required String? minimumValue,
    required String? maximumValue,
  }) {
    final minimum = parseDecimal(minimumValue);
    final maximum = parseDecimal(maximumValue);

    if (minimum != null && maximum != null && minimum > maximum) {
      return 'Minimalna cijena ne može biti veća '
          'od maksimalne cijene.';
    }

    return null;
  }

  static double? parseDecimal(String? value) {
    final normalized = value?.trim().replaceAll(',', '.') ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  static String? reviewComment(String? value) {
    return textLength(
      value,
      fieldName: 'Komentar',
      minimumLength: 5,
      maximumLength: 1000,
    );
  }

  static String? journalNote(String? value) {
    return textLength(
      value,
      fieldName: 'Bilješka',
      maximumLength: 500,
      required: false,
    );
  }

  static String? journalTitle(String? value) {
    return textLength(
      value,
      fieldName: 'Naslov',
      minimumLength: 2,
      maximumLength: 150,
    );
  }

  static String? journalContent(String? value) {
    return textLength(
      value,
      fieldName: 'Sadržaj dnevnika',
      minimumLength: 2,
      maximumLength: 10000,
    );
  }

  static String? appointmentNotes(String? value) {
    return textLength(
      value,
      fieldName: 'Napomena',
      maximumLength: 2000,
      required: false,
    );
  }

  static String? cancellationReason(String? value) {
    return textLength(
      value,
      fieldName: 'Razlog otkazivanja',
      minimumLength: 5,
      maximumLength: 500,
    );
  }

  static String? location(String? value) {
    return textLength(
      value,
      fieldName: 'Lokacija',
      maximumLength: 200,
      required: false,
    );
  }

  static String? username(String? value) {
    final basic = textLength(
      value,
      fieldName: 'Korisničko ime',
      minimumLength: 3,
      maximumLength: 50,
    );

    if (basic != null) {
      return basic;
    }

    final normalized = value!.trim();

    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalized)) {
      return 'Korisničko ime može sadržavati samo '
          'slova, brojeve, tačku, crticu i donju crtu.';
    }

    return null;
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}
