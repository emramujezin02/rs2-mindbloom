/// Public footer destinations. Demonstration contacts must be labelled as such.
class PublicContactLinks {
  final String email;
  final String phone;
  final String instagram;
  final String facebook;
  final String youtube;
  final bool isDemonstration;

  const PublicContactLinks({
    this.email = '',
    this.phone = '',
    this.instagram = '',
    this.facebook = '',
    this.youtube = '',
    this.isDemonstration = false,
  });

  // Owner-approved faculty-project demonstration contacts, not official support.
  // No official social accounts exist yet; leave those values empty.
  static const current = PublicContactLinks(
    email: 'support@mindbloom.ba',
    phone: '+387 61 000 000',
    isDemonstration: true,
  );

  Uri? get emailUri {
    final value = email.trim();
    if (!RegExp(r'^[^\s@:?&#]+@[^\s@:?&#]+\.[^\s@:?&#]+$').hasMatch(value)) {
      return null;
    }
    return Uri(scheme: 'mailto', path: value);
  }

  Uri? get phoneUri {
    final value = phone.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(value)) return null;
    return Uri(scheme: 'tel', path: value);
  }

  Uri? get instagramUri => _socialUri(instagram, const ['instagram.com']);
  Uri? get facebookUri =>
      _socialUri(facebook, const ['facebook.com', 'fb.com']);
  Uri? get youtubeUri => _socialUri(youtube, const ['youtube.com', 'youtu.be']);

  static Uri? _socialUri(String value, List<String> domains) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return null;
    }
    if (!domains.any(
      (domain) => uri.host == domain || uri.host.endsWith('.$domain'),
    )) {
      return null;
    }
    return uri;
  }
}
