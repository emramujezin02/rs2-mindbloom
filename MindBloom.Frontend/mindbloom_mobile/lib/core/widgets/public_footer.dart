import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';

class PublicFooter extends StatelessWidget {
  const PublicFooter({super.key});

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

    return Container(
      width: double.infinity,
      color: _backgroundColor,
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
                            onAbout: () => _openPage(context, AppRouter.about),
                          ),
                        ),
                        const SizedBox(width: 42),
                        const Expanded(child: _FooterContact()),
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
                        ),
                        const SizedBox(height: 32),
                        const _FooterContact(),
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
            Text(
              'MindBloom',
              style: TextStyle(
                color: PublicFooter._primaryTextColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
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

  const _FooterNavigation({
    required this.onHome,
    required this.onTherapists,
    required this.onArticles,
    required this.onAbout,
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
        _FooterLink(
          label: 'About us',
          icon: Icons.info_outline,
          onTap: onAbout,
        ),
      ],
    );
  }
}

class _FooterContact extends StatelessWidget {
  const _FooterContact();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterTitle(title: 'Contact'),
        SizedBox(height: 16),
        _ContactItem(icon: Icons.email_outlined, value: 'support@mindbloom.ba'),
        SizedBox(height: 13),
        _ContactItem(icon: Icons.phone_outlined, value: '+387 61 000 000'),
        SizedBox(height: 13),
        _ContactItem(
          icon: Icons.location_on_outlined,
          value: 'Bosnia and Herzegovina',
        ),
      ],
    );
  }
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
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: PublicFooter._accentColor),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  color: PublicFooter._secondaryTextColor,
                  fontSize: 15,
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

  const _ContactItem({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
