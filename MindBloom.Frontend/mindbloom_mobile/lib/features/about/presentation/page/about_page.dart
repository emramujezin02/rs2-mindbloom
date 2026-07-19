import 'package:flutter/material.dart';
import '../../../../app/router/app_router.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _openRegister(BuildContext context) {
    Navigator.of(context).pushNamed(AppRouter.register);
  }

  void _openTherapists(BuildContext context) {
    Navigator.of(context).pushNamed(AppRouter.therapists);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        titleSpacing: 8,
        title: const _MindBloomLogo(),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _AboutHeroSection(),
            const _DescriptionSection(),
            const _MissionVisionSection(),
            const _HowItWorksSection(),
            const _PrivacySection(),
            _AboutCallToAction(
              onRegister: () => _openRegister(context),
              onBrowseTherapists: () => _openTherapists(context),
            ),
            const _AboutFooter(),
          ],
        ),
      ),
    );
  }
}

class _AboutHeroSection extends StatelessWidget {
  const _AboutHeroSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 850;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 70 : 24,
        vertical: isDesktop ? 90 : 55,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFAF7FF), Color(0xFFE9DDF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFDCCCEF),
                child: Icon(
                  Icons.local_florist_outlined,
                  size: 45,
                  color: Color(0xFF72559A),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'About MindBloom',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF40334D),
                  fontSize: isDesktop ? 48 : 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'A safe digital space created to support mental wellbeing, '
                'personal growth and easier access to professional help.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF625B6B),
                  fontSize: 18,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection();

  @override
  Widget build(BuildContext context) {
    return _AboutSection(
      backgroundColor: Colors.white,
      eyebrow: 'WHO WE ARE',
      title: 'A place where your mind can breathe and grow',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 850),
        child: Text(
          'MindBloom is a digital mental health platform that connects clients '
          'with qualified psychotherapists. The platform also provides '
          'educational articles, workshops and tools for monitoring emotional '
          'wellbeing. Our goal is to make professional support simpler, safer '
          'and more accessible.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF665F6C), fontSize: 17, height: 1.7),
        ),
      ),
    );
  }
}

class _MissionVisionSection extends StatelessWidget {
  const _MissionVisionSection();

  @override
  Widget build(BuildContext context) {
    return _AboutSection(
      backgroundColor: const Color(0xFFF5EFFC),
      eyebrow: 'OUR PURPOSE',
      title: 'Mission and vision',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 700;

          final missionCard = const _InformationCard(
            icon: Icons.favorite_outline,
            title: 'Our mission',
            description:
                'Our mission is to make professional psychological support '
                'more accessible through a secure, simple and modern digital '
                'platform.',
          );

          final visionCard = const _InformationCard(
            icon: Icons.visibility_outlined,
            title: 'Our vision',
            description:
                'Our vision is a society in which every person can easily '
                'receive emotional support, understand their needs and improve '
                'their quality of life.',
          );

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: missionCard),
                SizedBox(width: 20),
                Expanded(child: visionCard),
              ],
            );
          }

          return Column(
            children: [missionCard, SizedBox(height: 18), visionCard],
          );
        },
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InformationCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE3D7EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: const Color(0xFFE9DFFF),
              child: Icon(icon, size: 30, color: const Color(0xFF72559A)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF40334D),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF68616D),
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const steps = [
    (
      Icons.person_search_outlined,
      'Choose a therapist',
      'Browse available therapists and select the professional whose experience suits your needs.',
    ),
    (
      Icons.calendar_month_outlined,
      'Book an appointment',
      'Choose an available date and send an appointment request through the application.',
    ),
    (
      Icons.video_call_outlined,
      'Attend your session',
      'Join the approved session through the agreed form of online communication.',
    ),
    (
      Icons.insights_outlined,
      'Track your progress',
      'Use journals and emotional wellbeing tools to follow your personal progress.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _AboutSection(
      backgroundColor: Colors.white,
      eyebrow: 'HOW IT WORKS',
      title: 'Support in four simple steps',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 950
              ? 4
              : constraints.maxWidth >= 600
              ? 2
              : 1;

          const spacing = 18.0;

          final itemWidth =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(steps.length, (index) {
              final step = steps[index];

              return SizedBox(
                width: itemWidth,
                child: _WorkStepCard(
                  number: index + 1,
                  icon: step.$1,
                  title: step.$2,
                  description: step.$3,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _WorkStepCard extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String description;

  const _WorkStepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DEF3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF72559A),
                child: Text(
                  number.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icon, size: 31, color: const Color(0xFF8063A4)),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF40334D),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF68616D), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    return _AboutSection(
      backgroundColor: const Color(0xFFF5EFFC),
      eyebrow: 'PRIVACY AND SECURITY',
      title: 'Your trust comes first',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE0D4EC)),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 52, color: Color(0xFF72559A)),
            SizedBox(height: 18),
            Text(
              'Your personal information remains protected',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF40334D),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 13),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 760),
              child: Text(
                'MindBloom is designed with privacy and security in mind. '
                'Personal information is available only to authorized users, '
                'while authentication and role-based access help protect '
                'sensitive data and communication.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF68616D),
                  fontSize: 16,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCallToAction extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onBrowseTherapists;

  const _AboutCallToAction({
    required this.onRegister,
    required this.onBrowseTherapists,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 65),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 46),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6E5193), Color(0xFF8C70AE)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.local_florist_outlined,
                color: Colors.white,
                size: 46,
              ),
              const SizedBox(height: 17),
              const Text(
                'Ready to begin your journey?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Create an account or explore available therapists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFF1EAF8), fontSize: 16),
              ),
              const SizedBox(height: 26),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: onRegister,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF664989),
                    ),
                    child: const Text('Create an account'),
                  ),
                  OutlinedButton(
                    onPressed: onBrowseTherapists,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text('Browse therapists'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3D314A),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 35),
      child: const Column(
        children: [
          _MindBloomLogo(
            textColor: Colors.white,
            iconBackgroundColor: Color(0xFF665A70),
            iconColor: Colors.white,
          ),
          SizedBox(height: 18),
          Text(
            'A digital space for emotional support and personal growth.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFCFC4D7), height: 1.5),
          ),
          SizedBox(height: 20),
          Divider(color: Color(0xFF665A70)),
          SizedBox(height: 16),
          Text(
            '© 2026 MindBloom. All rights reserved.',
            style: TextStyle(color: Color(0xFFCFC4D7)),
          ),
        ],
      ),
    );
  }
}

class _MindBloomLogo extends StatelessWidget {
  final Color textColor;
  final Color iconBackgroundColor;
  final Color iconColor;

  const _MindBloomLogo({
    this.textColor = const Color(0xFF5C477B),
    this.iconBackgroundColor = const Color(0xFFE9DFFF),
    this.iconColor = const Color(0xFF72559A),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: iconBackgroundColor,
          child: Icon(Icons.local_florist_outlined, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          'MindBloom',
          style: TextStyle(
            color: textColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Color backgroundColor;
  final Widget child;

  const _AboutSection({
    required this.eyebrow,
    required this.title,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 70 : 22,
        vertical: isDesktop ? 75 : 55,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            children: [
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8063A4),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF40334D),
                  fontSize: isDesktop ? 35 : 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 38),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
