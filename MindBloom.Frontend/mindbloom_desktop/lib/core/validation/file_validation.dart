class FileValidation {
  FileValidation._();

  static const int imageMaximumBytes = 5 * 1024 * 1024;

  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static String? validateImage({
    required String? filePath,
    required String extension,
    required int sizeInBytes,
  }) {
    final normalizedPath = filePath?.trim() ?? '';

    if (normalizedPath.isEmpty) {
      return 'Odabrani fajl nije moguće pročitati.';
    }

    final normalizedExtension = extension.trim().toLowerCase().replaceFirst(
      '.',
      '',
    );

    if (!allowedImageExtensions.contains(normalizedExtension)) {
      return 'Dozvoljeni formati slike su JPG, JPEG, PNG i WEBP.';
    }

    if (sizeInBytes > imageMaximumBytes) {
      return 'Slika može imati najviše 5 MB.';
    }

    if (sizeInBytes <= 0) {
      return 'Odabrani fajl je prazan.';
    }

    return null;
  }
}
