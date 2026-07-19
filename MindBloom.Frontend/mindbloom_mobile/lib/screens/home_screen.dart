import 'package:flutter/material.dart';
import '../features/landing/presentation/pages/landing_page.dart';
import '../app/router/app_router.dart';
import '../features/notification/presentation/viewmodels/notification_scope.dart';
import '../features/session/presentation/viewmodels/session_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _notificationInitializationRequested = false;

  final ScrollController _landingScrollController = ScrollController();

  final GlobalKey _homeSectionKey = GlobalKey();
  final GlobalKey _therapySectionKey = GlobalKey();
  final GlobalKey _therapistsSectionKey = GlobalKey();
  final GlobalKey _reviewsSectionKey = GlobalKey();
  final GlobalKey _articlesSectionKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final session = SessionScope.of(context);
    final notifications = NotificationScope.of(context);

    if (session.isInitialized &&
        session.isLoggedIn &&
        !_notificationInitializationRequested) {
      _notificationInitializationRequested = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifications.initialize();
      });
    }

    if (session.isInitialized && !session.isLoggedIn) {
      _notificationInitializationRequested = false;
    }
  }

  @override
  void dispose() {
    _landingScrollController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final session = SessionScope.of(context);
    final notifications = NotificationScope.of(context);

    await notifications.stop();
    await session.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  void _openNotifications() {
    Navigator.of(context).pushNamed(AppRouter.notifications);
  }

  void _openLogin() {
    Navigator.of(context).pushNamed(AppRouter.login);
  }

  void _openRegister() {
    Navigator.of(context).pushNamed(AppRouter.register);
  }

  void _openTherapists() {
    Navigator.of(context).pushNamed(AppRouter.therapists);
  }

  void _openArticles() {
    Navigator.of(context).pushNamed(AppRouter.articles);
  }

  void _openArticleDetails(int articleId) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.articleDetails, arguments: articleId);
  }

  void _openTherapistDetails(int therapistId) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.therapistDetails, arguments: therapistId);
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final targetContext = key.currentContext;

    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      alignment: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (!session.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!session.isLoggedIn) {
      return const LandingPage();
    }

    return _buildLoggedInHome();
  }

  Widget _buildLoggedInHome() {
    final notifications = NotificationScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindBloom'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Badge.count(
              count: notifications.unreadCount,
              isLabelVisible: notifications.unreadCount > 0,
              child: const Icon(Icons.notifications),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.local_florist_outlined,
                  size: 64,
                  color: Color(0xFF72559A),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to MindBloom',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the section you want to open.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 30),
                _HomeMenuCard(
                  icon: Icons.dashboard_outlined,
                  title: 'My dashboard',
                  description:
                      'View appointment statistics and recommended therapists.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.clientDashboard);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.notifications_outlined,
                  title: notifications.unreadCount == 0
                      ? 'Notifications'
                      : 'Notifications (${notifications.unreadCount} unread)',
                  description:
                      'Review your latest updates and important information.',
                  trailing: Badge.count(
                    count: notifications.unreadCount,
                    isLabelVisible: notifications.unreadCount > 0,
                    child: const Icon(Icons.arrow_forward_ios, size: 17),
                  ),
                  onTap: _openNotifications,
                ),
                _HomeMenuCard(
                  icon: Icons.people_outline,
                  title: 'Browse therapists',
                  description:
                      'Search therapists and review their profiles and services.',
                  onTap: _openTherapists,
                ),
                _HomeMenuCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Recommended therapists',
                  description:
                      'View therapists recommended according to your preferences.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.recommendations);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.favorite_outline,
                  title: 'My favorites',
                  description: 'View therapists saved to your favorites.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.myFavorites);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'My appointments',
                  description:
                      'View upcoming, completed and cancelled appointments.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.myAppointments);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.card_membership_outlined,
                  title: 'My memberships',
                  description:
                      'Review and manage your active therapy memberships.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.myMemberships);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.payments_outlined,
                  title: 'Payment history',
                  description:
                      'View completed payments and transaction history.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.myPayments);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.person_outline,
                  title: 'My profile',
                  description:
                      'Review and update your personal profile information.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.profile);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Journal',
                  description:
                      'Track your mood, emotions and personal reflections.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.journal);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.article_outlined,
                  title: 'Articles',
                  description:
                      'Read educational content about mental health and therapy.',
                  onTap: _openArticles,
                ),
                _HomeMenuCard(
                  icon: Icons.chat_outlined,
                  title: 'Messages',
                  description:
                      'Open conversations connected with your appointments.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.chats);
                  },
                ),
                _HomeMenuCard(
                  icon: Icons.groups_outlined,
                  title: 'Workshops',
                  description:
                      'Discover available educational workshops and activities.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.workshops);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPublicLandingPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      drawer: _LandingDrawer(
        onHome: () {
          Navigator.of(context).pop();
          _scrollToSection(_homeSectionKey);
        },
        onTherapy: () {
          Navigator.of(context).pop();
          _scrollToSection(_therapySectionKey);
        },
        onTherapists: () {
          Navigator.of(context).pop();
          _scrollToSection(_therapistsSectionKey);
        },
        onReviews: () {
          Navigator.of(context).pop();
          _scrollToSection(_reviewsSectionKey);
        },
        onArticles: () {
          Navigator.of(context).pop();
          _scrollToSection(_articlesSectionKey);
        },
        onLogin: () {
          Navigator.of(context).pop();
          _openLogin();
        },
        onRegister: () {
          Navigator.of(context).pop();
          _openRegister();
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _LandingNavigation(
              onHome: () => _scrollToSection(_homeSectionKey),
              onTherapy: () => _scrollToSection(_therapySectionKey),
              onTherapists: () => _scrollToSection(_therapistsSectionKey),
              onReviews: () => _scrollToSection(_reviewsSectionKey),
              onArticles: () => _scrollToSection(_articlesSectionKey),
              onLogin: _openLogin,
              onRegister: _openRegister,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _landingScrollController,
                child: Column(
                  children: [
                    Container(
                      key: _homeSectionKey,
                      child: _HeroSection(
                        onFindTherapist: _openTherapists,
                        onExploreTherapy: () {
                          _scrollToSection(_therapySectionKey);
                        },
                      ),
                    ),
                    Container(
                      key: _therapySectionKey,
                      child: _TherapyDirectionsSection(
                        onReadArticles: _openArticles,
                      ),
                    ),
                    Container(
                      key: _therapistsSectionKey,
                      child: _FeaturedTherapistsSection(
                        onViewAll: _openTherapists,
                        onTherapistSelected: _openTherapistDetails,
                      ),
                    ),
                    Container(
                      key: _reviewsSectionKey,
                      child: const _ReviewsSection(),
                    ),
                    Container(
                      key: _articlesSectionKey,
                      child: _ArticlesSection(
                        onViewAll: _openArticles,
                        onArticleSelected: _openArticleDetails,
                      ),
                    ),
                    _LandingCallToAction(
                      onRegister: _openRegister,
                      onFindTherapist: _openTherapists,
                    ),
                    const _LandingFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;
  final VoidCallback onTap;

  const _HomeMenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE5FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF72559A)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(description),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 17),
        onTap: onTap,
      ),
    );
  }
}

class _LandingNavigation extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onTherapy;
  final VoidCallback onTherapists;
  final VoidCallback onReviews;
  final VoidCallback onArticles;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _LandingNavigation({
    required this.onHome,
    required this.onTherapy,
    required this.onTherapists,
    required this.onReviews,
    required this.onArticles,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 950;

    return Material(
      color: Colors.white,
      elevation: 2,
      child: Container(
        height: 76,
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 14),
        child: Row(
          children: [
            if (!isDesktop)
              Builder(
                builder: (context) {
                  return IconButton(
                    tooltip: 'Menu',
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                    icon: const Icon(Icons.menu),
                  );
                },
              ),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onHome,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: _MindBloomLogo(),
              ),
            ),
            const Spacer(),
            if (isDesktop) ...[
              _NavigationButton(label: 'Home', onPressed: onHome),
              _NavigationButton(label: 'Therapy', onPressed: onTherapy),
              _NavigationButton(label: 'Therapists', onPressed: onTherapists),
              _NavigationButton(label: 'Reviews', onPressed: onReviews),
              _NavigationButton(label: 'Articles', onPressed: onArticles),
              const SizedBox(width: 12),
              TextButton(onPressed: onLogin, child: const Text('Log in')),
              const SizedBox(width: 6),
            ],
            FilledButton(onPressed: onRegister, child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _NavigationButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF544B5B),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      ),
      child: Text(label),
    );
  }
}

class _LandingDrawer extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onTherapy;
  final VoidCallback onTherapists;
  final VoidCallback onReviews;
  final VoidCallback onArticles;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _LandingDrawer({
    required this.onHome,
    required this.onTherapy,
    required this.onTherapists,
    required this.onReviews,
    required this.onArticles,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(22),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _MindBloomLogo(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('Home'),
                    onTap: onHome,
                  ),
                  ListTile(
                    leading: const Icon(Icons.psychology_alt_outlined),
                    title: const Text('Therapy directions'),
                    onTap: onTherapy,
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Therapists'),
                    onTap: onTherapists,
                  ),
                  ListTile(
                    leading: const Icon(Icons.reviews_outlined),
                    title: const Text('Reviews'),
                    onTap: onReviews,
                  ),
                  ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('Articles'),
                    onTap: onArticles,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: onLogin,
                    child: const Text('Log in'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: onRegister,
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MindBloomLogo extends StatelessWidget {
  const _MindBloomLogo();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: Color(0xFFE9DFFF),
          child: Icon(Icons.local_florist_outlined, color: Color(0xFF72559A)),
        ),
        SizedBox(width: 10),
        Text(
          'MindBloom',
          style: TextStyle(
            color: Color(0xFF5C477B),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback onFindTherapist;
  final VoidCallback onExploreTherapy;

  const _HeroSection({
    required this.onFindTherapist,
    required this.onExploreTherapy,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 70 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFAF7FF), Color(0xFFEDE3FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: _HeroContent(
                        isDesktop: true,
                        onFindTherapist: onFindTherapist,
                        onExploreTherapy: onExploreTherapy,
                      ),
                    ),
                    const SizedBox(width: 60),
                    const Expanded(child: _HeroImage()),
                  ],
                )
              : Column(
                  children: [
                    _HeroContent(
                      isDesktop: false,
                      onFindTherapist: onFindTherapist,
                      onExploreTherapy: onExploreTherapy,
                    ),
                    const SizedBox(height: 38),
                    const _HeroImage(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback onFindTherapist;
  final VoidCallback onExploreTherapy;

  const _HeroContent({
    required this.isDesktop,
    required this.onFindTherapist,
    required this.onExploreTherapy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'A safe space for your mental wellbeing',
            style: TextStyle(
              color: Color(0xFF684C8E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Your mind deserves\nspace to bloom.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF3E3152),
            fontSize: isDesktop ? 54 : 39,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'MindBloom connects you with trusted psychotherapists and gives '
          'you a simple, private and supportive way to begin your journey '
          'toward greater emotional balance.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF625B6B),
            fontSize: 17,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onFindTherapist,
              icon: const Icon(Icons.search),
              label: const Text('Find a therapist'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onExploreTherapy,
              icon: const Icon(Icons.keyboard_arrow_down),
              label: const Text('Explore therapy'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 27),
        const Wrap(
          spacing: 18,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _HeroBenefit(
              icon: Icons.verified_user_outlined,
              label: 'Verified professionals',
            ),
            _HeroBenefit(icon: Icons.lock_outline, label: 'Private and secure'),
            _HeroBenefit(
              icon: Icons.video_call_outlined,
              label: 'Online sessions',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroBenefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBenefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF72559A)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF5F5768),
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.12,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 30,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/landing/hero_therapy.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return Container(
                    color: const Color(0xFFDED0F0),
                    child: const Center(
                      child: Icon(
                        Icons.self_improvement,
                        size: 130,
                        color: Color(0xFF72559A),
                      ),
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(18),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFFEDE5FA),
                        child: Icon(
                          Icons.favorite_outline,
                          color: Color(0xFF72559A),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Take the first step toward feeling better.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF453756),
                          ),
                        ),
                      ),
                    ],
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

class _TherapyDirectionsSection extends StatelessWidget {
  final VoidCallback onReadArticles;

  const _TherapyDirectionsSection({required this.onReadArticles});

  static const List<_TherapyDirectionData> _directions = [
    _TherapyDirectionData(
      icon: Icons.psychology_alt_outlined,
      title: 'Psychodynamic therapy',
      description:
          'Explore unconscious patterns, previous experiences and relationships '
          'that influence thoughts and emotions.',
    ),
    _TherapyDirectionData(
      icon: Icons.lightbulb_outline,
      title: 'Cognitive behavioural therapy',
      description:
          'Understand the connection between thoughts, emotions and behaviour '
          'through practical therapeutic techniques.',
    ),
    _TherapyDirectionData(
      icon: Icons.self_improvement,
      title: 'Gestalt therapy',
      description:
          'Focus on the present moment, awareness, personal needs and direct '
          'experience.',
    ),
    _TherapyDirectionData(
      icon: Icons.favorite_border,
      title: 'Humanistic therapy',
      description:
          'A supportive approach focused on acceptance, self-understanding and '
          'personal growth.',
    ),
    _TherapyDirectionData(
      icon: Icons.groups_outlined,
      title: 'Systemic family therapy',
      description:
          'Explore communication and relationship patterns within couples and '
          'families.',
    ),
    _TherapyDirectionData(
      icon: Icons.hub_outlined,
      title: 'Integrative therapy',
      description:
          'Combines methods from multiple approaches according to the needs of '
          'each client.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'THERAPY DIRECTIONS',
      title: 'Find an approach that suits your needs',
      description:
          'Learn about different forms of psychotherapy and discover an '
          'approach that feels most appropriate for you.',
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 620
              ? 2
              : 1;

          const spacing = 18.0;

          final cardWidth =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

          return Column(
            children: [
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _directions.map((direction) {
                  return SizedBox(
                    width: cardWidth,
                    child: _TherapyDirectionCard(
                      direction: direction,
                      onLearnMore: onReadArticles,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: onReadArticles,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Read educational articles'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TherapyDirectionCard extends StatelessWidget {
  final _TherapyDirectionData direction;
  final VoidCallback onLearnMore;

  const _TherapyDirectionCard({
    required this.direction,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFAF7FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE8DEF3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE9DFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(direction.icon, color: const Color(0xFF72559A)),
            ),
            const SizedBox(height: 18),
            Text(
              direction.title,
              style: const TextStyle(
                color: Color(0xFF433550),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              direction.description,
              style: const TextStyle(color: Color(0xFF6D6673), height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onLearnMore,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Learn more'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedTherapistsSection extends StatelessWidget {
  final VoidCallback onViewAll;
  final ValueChanged<int> onTherapistSelected;

  const _FeaturedTherapistsSection({
    required this.onViewAll,
    required this.onTherapistSelected,
  });

  static const List<_TherapistData> _therapists = [
    _TherapistData(
      id: 1,
      name: 'Ana Kovačević',
      specialization: 'Cognitive behavioural therapy',
      description: 'Support for anxiety, stress and emotional difficulties.',
      rating: 4.9,
      imagePath: 'assets/images/landing/therapist_ana.jpg',
    ),
    _TherapistData(
      id: 2,
      name: 'Marko Jurić',
      specialization: 'Psychodynamic therapy',
      description: 'Understanding deeper emotional and relationship patterns.',
      rating: 4.8,
      imagePath: 'assets/images/landing/therapist_marko.jpg',
    ),
    _TherapistData(
      id: 3,
      name: 'Lejla Simić',
      specialization: 'Humanistic therapy',
      description: 'A warm and supportive environment for personal growth.',
      rating: 4.9,
      imagePath: 'assets/images/landing/therapist_lejla.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'OUR PROFESSIONALS',
      title: 'Meet therapists who are here to listen',
      description:
          'Explore professionals and choose a therapist whose approach and '
          'experience feel right for you.',
      backgroundColor: const Color(0xFFF5EFFC),
      child: Column(
        children: [
          SizedBox(
            height: 410,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _therapists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final therapist = _therapists[index];

                return SizedBox(
                  width: 300,
                  child: _TherapistCard(
                    therapist: therapist,
                    onTap: () {
                      onTherapistSelected(therapist.id);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.people_outline),
            label: const Text('View all therapists'),
          ),
        ],
      ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final _TherapistData therapist;
  final VoidCallback onTap;

  const _TherapistCard({required this.therapist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(23),
        side: const BorderSide(color: Color(0xFFE1D5ED)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Image.asset(
                  therapist.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) {
                    return Container(
                      color: const Color(0xFFE4D8F3),
                      child: const Center(
                        child: Icon(
                          Icons.person_outline,
                          size: 105,
                          color: Color(0xFF72559A),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    therapist.name,
                    style: const TextStyle(
                      color: Color(0xFF40334D),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    therapist.specialization,
                    style: const TextStyle(
                      color: Color(0xFF765B97),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    therapist.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B6570),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF2B84B)),
                      const SizedBox(width: 4),
                      Text(
                        therapist.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Text(
                        'View profile',
                        style: TextStyle(
                          color: Color(0xFF72559A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: Color(0xFF72559A),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection();

  static const List<_ReviewData> _reviews = [
    _ReviewData(
      client: 'Female client, 23',
      text:
          'I felt heard and understood from the first session. Therapy helped '
          'me understand my emotions and face situations that previously felt '
          'overwhelming.',
    ),
    _ReviewData(
      client: 'Male client, 31',
      text:
          'Finding a therapist through MindBloom was simple and comfortable. '
          'The sessions helped me develop healthier ways of dealing with stress.',
    ),
    _ReviewData(
      client: 'Female client, 28',
      text:
          'MindBloom gave me the confidence to take the first step. I found a '
          'therapist whose approach suited me and I finally feel progress.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'CLIENT EXPERIENCES',
      title: 'Stories from people who took the first step',
      description:
          'Read experiences from clients who found professional support through '
          'therapy.',
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 620
              ? 2
              : 1;

          const spacing = 18.0;

          final width =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: _reviews.map((review) {
              return SizedBox(
                width: width,
                child: _ReviewCard(review: review),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _ReviewData review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFAF7FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE7DDF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.format_quote_rounded,
              size: 40,
              color: Color(0xFF9277B4),
            ),
            const SizedBox(height: 10),
            Text(
              review.text,
              style: const TextStyle(color: Color(0xFF5F5865), height: 1.6),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.star_rounded, color: Color(0xFFF2B84B)),
                Icon(Icons.star_rounded, color: Color(0xFFF2B84B)),
                Icon(Icons.star_rounded, color: Color(0xFFF2B84B)),
                Icon(Icons.star_rounded, color: Color(0xFFF2B84B)),
                Icon(Icons.star_rounded, color: Color(0xFFF2B84B)),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              review.client,
              style: const TextStyle(
                color: Color(0xFF44374F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticlesSection extends StatelessWidget {
  final VoidCallback onViewAll;
  final ValueChanged<int> onArticleSelected;

  const _ArticlesSection({
    required this.onViewAll,
    required this.onArticleSelected,
  });

  static const List<_ArticleData> _articles = [
    _ArticleData(
      id: 1,
      title: 'How to recognise signs of emotional exhaustion',
      description:
          'Learn how to identify early signs of emotional exhaustion and '
          'protect your mental wellbeing.',
      imagePath: 'assets/images/landing/article_exhaustion.jpg',
    ),
    _ArticleData(
      id: 2,
      title: 'Why asking for help is a sign of strength',
      description:
          'Seeking professional support can be an important step toward '
          'understanding yourself.',
      imagePath: 'assets/images/landing/article_support.jpg',
    ),
    _ArticleData(
      id: 3,
      title: 'Daily habits that support mental health',
      description:
          'Discover simple routines that may help you feel more balanced and '
          'connected to yourself.',
      imagePath: 'assets/images/landing/article_habits.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'MINDBLOOM ARTICLES',
      title: 'Learn more about yourself and mental health',
      description:
          'Explore educational content about emotions, relationships, therapy '
          'and personal wellbeing.',
      backgroundColor: const Color(0xFFF5EFFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 620
              ? 2
              : 1;

          const spacing = 18.0;

          final width =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

          return Column(
            children: [
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _articles.map((article) {
                  return SizedBox(
                    width: width,
                    child: _ArticleCard(
                      article: article,
                      onTap: () {
                        onArticleSelected(article.id);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              OutlinedButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.article_outlined),
                label: const Text('View all articles'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final _ArticleData article;
  final VoidCallback onTap;

  const _ArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE3D9EF)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                article.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return Container(
                    color: const Color(0xFFDFD1F0),
                    child: const Center(
                      child: Icon(
                        Icons.auto_stories_outlined,
                        size: 68,
                        color: Color(0xFF72559A),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MENTAL HEALTH',
                    style: TextStyle(
                      color: Color(0xFF8063A4),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    article.title,
                    style: const TextStyle(
                      color: Color(0xFF40334D),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    article.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68616D),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Text(
                        'Read article',
                        style: TextStyle(
                          color: Color(0xFF72559A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: Color(0xFF72559A),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingCallToAction extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onFindTherapist;

  const _LandingCallToAction({
    required this.onRegister,
    required this.onFindTherapist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 65),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1050),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 46),
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
                'You do not have to go through everything alone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Create an account or explore available therapists and take '
                'the first step at your own pace.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF1EAF8),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
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
                    onPressed: onFindTherapist,
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

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3D314A),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 800) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _FooterAbout()),
                        Expanded(child: _FooterLinks()),
                        Expanded(child: _FooterContact()),
                        Expanded(child: _FooterSocial()),
                      ],
                    );
                  }

                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FooterAbout(),
                      SizedBox(height: 30),
                      _FooterLinks(),
                      SizedBox(height: 30),
                      _FooterContact(),
                      SizedBox(height: 30),
                      _FooterSocial(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFF665A70)),
              const SizedBox(height: 20),
              const Text(
                '© 2026 MindBloom. All rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFCFC4D7)),
              ),
            ],
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
    return const Padding(
      padding: EdgeInsets.only(right: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MindBloomLogo(),
          SizedBox(height: 13),
          Text(
            'A digital space for emotional support, personal growth and '
            'connecting with mental health professionals.',
            style: TextStyle(color: Color(0xFFCFC4D7), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context) {
    return const _FooterColumn(
      title: 'Useful links',
      children: [
        Text('About us', style: _footerTextStyle),
        SizedBox(height: 10),
        Text('Terms of use', style: _footerTextStyle),
        SizedBox(height: 10),
        Text('Privacy policy', style: _footerTextStyle),
        SizedBox(height: 10),
        Text('Articles', style: _footerTextStyle),
      ],
    );
  }
}

class _FooterContact extends StatelessWidget {
  const _FooterContact();

  @override
  Widget build(BuildContext context) {
    return const _FooterColumn(
      title: 'Contact',
      children: [
        _FooterContactRow(
          icon: Icons.email_outlined,
          text: 'support@mindbloom.ba',
        ),
        _FooterContactRow(icon: Icons.phone_outlined, text: '+387 61 000 000'),
        _FooterContactRow(
          icon: Icons.location_on_outlined,
          text: 'Mostar, Bosnia and Herzegovina',
        ),
      ],
    );
  }
}

class _FooterSocial extends StatelessWidget {
  const _FooterSocial();

  @override
  Widget build(BuildContext context) {
    return const _FooterColumn(
      title: 'Follow us',
      children: [
        Wrap(
          spacing: 10,
          children: [
            _FooterSocialIcon(icon: Icons.camera_alt_outlined),
            _FooterSocialIcon(icon: Icons.facebook_outlined),
            _FooterSocialIcon(icon: Icons.play_circle_outline),
          ],
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FooterColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FooterContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FooterContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFFDCCFED)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _footerTextStyle)),
        ],
      ),
    );
  }
}

class _FooterSocialIcon extends StatelessWidget {
  final IconData icon;

  const _FooterSocialIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF574762),
      ),
      icon: Icon(icon),
    );
  }
}

class _LandingSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final Color backgroundColor;
  final Widget child;

  const _LandingSection({
    required this.eyebrow,
    required this.title,
    required this.description,
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
        vertical: isDesktop ? 78 : 56,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Column(
            children: [
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8063A4),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF40334D),
                  fontSize: isDesktop ? 36 : 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6A6370),
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapyDirectionData {
  final IconData icon;
  final String title;
  final String description;

  const _TherapyDirectionData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _TherapistData {
  final int id;
  final String name;
  final String specialization;
  final String description;
  final double rating;
  final String imagePath;

  const _TherapistData({
    required this.id,
    required this.name,
    required this.specialization,
    required this.description,
    required this.rating,
    required this.imagePath,
  });
}

class _ReviewData {
  final String client;
  final String text;

  const _ReviewData({required this.client, required this.text});
}

class _ArticleData {
  final int id;
  final String title;
  final String description;
  final String imagePath;

  const _ArticleData({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

const TextStyle _footerTextStyle = TextStyle(
  color: Color(0xFFCFC4D7),
  height: 1.45,
);
