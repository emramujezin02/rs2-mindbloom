import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../constants/public_contact_links.dart';
import '../navigation/external_link_launcher.dart';

class PublicFooter extends StatelessWidget {
  final PublicContactLinks links;
  const PublicFooter({super.key, this.links = PublicContactLinks.current});

  static const Color _backgroundColor = Color(0xFF3D314A);
  static const Color _primaryTextColor = Colors.white;
  static const Color _secondaryTextColor = Color(0xFFCFC4D7);
  static const Color _accentColor = Color(0xFFDCCCEF);
  static const Color _dividerColor = Color(0xFF665A70);

  void _openPage(BuildContext context, String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute == routeName) {
      return;
    }

    Navigator.of(context).pushNamed(routeName);
  }

  void _openHome(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute == AppRouter.home) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Material(
      color: _backgroundColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth >= 760;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isWideScreen)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(flex: 2, child: _FooterAbout()),
                          const SizedBox(width: 42),
                          Expanded(
                            child: _FooterNavigation(
                              onHome: () => _openHome(context),
                              onTherapists: () =>
                                  _openPage(context, AppRouter.therapists),
                              onArticles: () =>
                                  _openPage(context, AppRouter.articles),
                              onAbout: () =>
                                  _openPage(context, AppRouter.about),
                              onTerms: () =>
                                  _openPage(context, AppRouter.terms),
                              onPrivacy: () =>
                                  _openPage(context, AppRouter.privacyPolicy),
                            ),
                          ),
                          const SizedBox(width: 42),
                          Expanded(child: _FooterContact(links: links)),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FooterAbout(),
                          const SizedBox(height: 32),
                          _FooterNavigation(
                            onHome: () => _openHome(context),
                            onTherapists: () =>
                                _openPage(context, AppRouter.therapists),
                            onArticles: () =>
                                _openPage(context, AppRouter.articles),
                            onAbout: () => _openPage(context, AppRouter.about),
                            onTerms: () => _openPage(context, AppRouter.terms),
                            onPrivacy: () =>
                                _openPage(context, AppRouter.privacyPolicy),
                          ),
                          const SizedBox(height: 32),
                          _FooterContact(links: links),
                        ],
                      ),
                    const SizedBox(height: 32),
                    const Divider(color: _dividerColor),
                    const SizedBox(height: 18),
                    Text(
                      '© $currentYear MindBloom. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterAbout extends StatelessWidget {
  const _FooterAbout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: PublicFooter._accentColor,
              child: Icon(
                Icons.local_florist_outlined,
                color: Color(0xFF72559A),
              ),
            ),
            SizedBox(width: 11),
            Flexible(
              child: Text(
                'MindBloom',
                style: TextStyle(
                  color: PublicFooter._primaryTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          'A digital space for emotional support, personal growth and '
          'easier access to professional mental health support.',
          style: TextStyle(
            color: PublicFooter._secondaryTextColor,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _FooterNavigation extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onTherapists;
  final VoidCallback onArticles;
  final VoidCallback onAbout;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  const _FooterNavigation({
    required this.onHome,
    required this.onTherapists,
    required this.onArticles,
    required this.onAbout,
    required this.onTerms,
    required this.onPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FooterTitle(title: 'Useful links'),
        const SizedBox(height: 12),
        _FooterLink(label: 'Home', icon: Icons.home_outlined, onTap: onHome),
        _FooterLink(
          label: 'Therapists',
          icon: Icons.people_outline,
          onTap: onTherapists,
        ),
        _FooterLink(
          label: 'Articles',
          icon: Icons.article_outlined,
          onTap: onArticles,
        ),
        _FooterLink(label: 'O nama', icon: Icons.info_outline, onTap: onAbout),
        _FooterLink(
          label: 'Uslovi korištenja',
          icon: Icons.description_outlined,
          onTap: onTerms,
        ),
        _FooterLink(
          label: 'Politika privatnosti',
          icon: Icons.shield_outlined,
          onTap: onPrivacy,
        ),
      ],
    );
  }
}

class _FooterContact extends StatelessWidget {
  final PublicContactLinks links;
  const _FooterContact({required this.links});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FooterTitle(title: 'Contact'),
        const SizedBox(height: 12),
        if (links.isDemonstration)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Demonstracijski podaci fakultetskog projekta. '
              'Ovo nisu potvrđeni službeni kontakti.',
              style: TextStyle(
                color: PublicFooter._secondaryTextColor,
                height: 1.4,
              ),
            ),
          ),
        _ContactItem(
          icon: Icons.email_outlined,
          value: links.email.isEmpty ? 'Email nije dostupan' : links.email,
          onTap: links.emailUri == null
              ? null
              : () => ExternalLinkLauncher.open(
                  context,
                  links.emailUri,
                  failureMessage:
                      'Email aplikaciju nije moguće otvoriti. Provjerite imate li instaliranu email aplikaciju.',
                ),
        ),
        _ContactItem(
          icon: Icons.phone_outlined,
          value: links.phone.isEmpty ? 'Telefon nije dostupan' : links.phone,
          onTap: links.phoneUri == null
              ? null
              : () => ExternalLinkLauncher.open(
                  context,
                  links.phoneUri,
                  failureMessage:
                      'Aplikaciju za pozivanje nije moguće otvoriti na ovom uređaju.',
                ),
        ),
        const _ContactItem(
          icon: Icons.location_on_outlined,
          value: 'Bosnia and Herzegovina',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SocialLink(
              label: 'Instagram',
              uri: links.instagramUri,
              icon: const _BrandIcon(instagram: true),
            ),
            _SocialLink(
              label: 'Facebook',
              uri: links.facebookUri,
              icon: const Icon(Icons.facebook),
            ),
            _SocialLink(
              label: 'YouTube',
              uri: links.youtubeUri,
              icon: const _BrandIcon(instagram: false),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialLink extends StatelessWidget {
  final String label;
  final Uri? uri;
  final Widget icon;
  const _SocialLink({
    required this.label,
    required this.uri,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('footer-social-$label'),
    tooltip: uri == null ? '$label nije dostupan' : label,
    color: PublicFooter._accentColor,
    disabledColor: PublicFooter._secondaryTextColor.withValues(alpha: 0.55),
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: uri == null
        ? null
        : () => ExternalLinkLauncher.open(
            context,
            uri,
            failureMessage: '$label nije moguće otvoriti. Pokušajte ponovo.',
          ),
    icon: icon,
  );
}

/// Small vector marks keep the existing icon system and add no dependency.
class _BrandIcon extends StatelessWidget {
  final bool instagram;
  const _BrandIcon({required this.instagram});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(24, 24),
    painter: _BrandPainter(
      instagram,
      IconTheme.of(context).color ?? Colors.white,
    ),
  );
}

class _BrandPainter extends CustomPainter {
  final bool instagram;
  final Color color;
  _BrandPainter(this.instagram, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (instagram) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 2, 20, 20),
          const Radius.circular(6),
        ),
        paint,
      );
      canvas.drawCircle(const Offset(12, 12), 5, paint);
      canvas.drawCircle(
        const Offset(18, 6),
        1.3,
        paint..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, 4, 22, 16),
          const Radius.circular(5),
        ),
        paint,
      );
      final triangle = Path()
        ..moveTo(10, 8)
        ..lineTo(16, 12)
        ..lineTo(10, 16)
        ..close();
      canvas.drawPath(triangle, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_BrandPainter oldDelegate) =>
      oldDelegate.instagram != instagram || oldDelegate.color != color;
}

class _FooterTitle extends StatelessWidget {
  final String title;

  const _FooterTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: PublicFooter._primaryTextColor,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FooterLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: PublicFooter._accentColor),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: PublicFooter._secondaryTextColor,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  const _ContactItem({required this.icon, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: PublicFooter._accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: PublicFooter._secondaryTextColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }
}
