import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/app/di/injection.dart';
import 'package:mindbloom_mobile/features/landing/presentation/viewmodels/landing_page_viewmodel.dart';
import '../../../../app/router/app_router.dart';
import '../../../article/data/models/article_model.dart';
import '../../../review/data/models/review_model.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../../../therapist/data/models/therapist_list_arguments.dart';
import '../../../therapy_approach/data/models/therapy_approach_model.dart';
import '../../../therapist/presentation/widgets/therapist_profile_image.dart';
import '../../../therapist/presentation/widgets/therapist_session_modes.dart';
import '../../../../core/widgets/public_footer.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';

const _landingBackground = Color(0xFFFCFAFF);
const _landingSectionLavender = Color(0xFFF6F0FC);
const _landingSurface = Color(0xFFFFFFFF);
const _landingTint = Color(0xFFFAF7FE);
const _landingBorder = Color(0xFFE8DEF3);
const _landingPrimary = Color(0xFF6D4F91);
const _landingText = Color(0xFF3E3152);
const _landingBody = Color(0xFF625B6B);
const _landingCardRadius = 20.0;

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final LandingPageViewModel viewModel;

  final ScrollController scrollController = ScrollController();

  final GlobalKey homeSectionKey = GlobalKey();
  final GlobalKey therapySectionKey = GlobalKey();
  final GlobalKey therapistsSectionKey = GlobalKey();
  final GlobalKey reviewsSectionKey = GlobalKey();
  final GlobalKey articlesSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    viewModel = AppInjection.createLandingPageViewModel();
    viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadLandingData();
    });
  }

  @override
  void dispose() {
    viewModel.removeListener(_onViewModelChanged);
    viewModel.dispose();
    scrollController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _scrollToSection(GlobalKey sectionKey) async {
    final sectionContext = sectionKey.currentContext;

    if (sectionContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      alignment: 0,
    );
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

  void _openTherapistsByApproach(TherapyApproachModel approach) {
    Navigator.of(context).pushNamed(
      AppRouter.therapists,
      arguments: TherapistListArguments(
        therapyApproachId: approach.id,
        therapyApproachName: approach.name,
      ),
    );
  }

  void _openTherapistDetails(int therapistId) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.therapistDetails, arguments: therapistId);
  }

  void _openArticles() {
    Navigator.of(context).pushNamed(AppRouter.articles);
  }

  void _openArticleDetails(int articleId) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.articleDetails, arguments: articleId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _landingBackground,
      drawer: _LandingDrawer(
        onHome: () => _handleDrawerNavigation(homeSectionKey),
        onTherapy: () => _handleDrawerNavigation(therapySectionKey),
        onTherapists: () => _handleDrawerNavigation(therapistsSectionKey),
        onReviews: () => _handleDrawerNavigation(reviewsSectionKey),
        onArticles: () => _handleDrawerNavigation(articlesSectionKey),
        onAbout: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(AppRouter.about);
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
              onHome: () => _scrollToSection(homeSectionKey),
              onTherapy: () => _scrollToSection(therapySectionKey),
              onTherapists: () => _scrollToSection(therapistsSectionKey),
              onReviews: () => _scrollToSection(reviewsSectionKey),
              onArticles: () => _scrollToSection(articlesSectionKey),
              onAbout: () {
                Navigator.of(context).pushNamed(AppRouter.about);
              },
              onLogin: _openLogin,
              onRegister: _openRegister,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: viewModel.refresh,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Container(
                        key: homeSectionKey,
                        child: _HeroSection(
                          onFindTherapist: _openTherapists,
                          onExploreTherapy: () {
                            _scrollToSection(therapySectionKey);
                          },
                        ),
                      ),
                      Container(
                        key: therapySectionKey,
                        child: _TherapySection(
                          approaches: viewModel.therapyApproaches,
                          isLoading: viewModel.isTherapyApproachesLoading,
                          errorMessage: viewModel.therapyApproachErrorMessage,
                          onRetry: viewModel.retryTherapyApproaches,
                          onApproachSelected: _openTherapistsByApproach,
                          onReadArticles: _openArticles,
                        ),
                      ),
                      if (viewModel.isLoading &&
                          viewModel.therapists.isEmpty &&
                          viewModel.articles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(),
                        ),
                      if (viewModel.errorMessage != null)
                        _LandingMainError(
                          message: viewModel.errorMessage!,
                          onRetry: viewModel.loadLandingData,
                        ),
                      Container(
                        key: therapistsSectionKey,
                        child: _TherapistsSection(
                          therapists: viewModel.therapists,
                          isLoading: viewModel.isLoading,
                          errorMessage: viewModel.therapistErrorMessage,
                          onViewAll: _openTherapists,
                          onRetry: viewModel.loadLandingData,
                          onTherapistSelected: _openTherapistDetails,
                        ),
                      ),
                      Container(
                        key: reviewsSectionKey,
                        child: _ReviewsSection(
                          reviews: viewModel.reviews,
                          isLoading: viewModel.isReviewsLoading,
                          errorMessage: viewModel.reviewErrorMessage,
                          onRetry: viewModel.retryReviews,
                        ),
                      ),
                      Container(
                        key: articlesSectionKey,
                        child: _ArticlesSection(
                          articles: viewModel.articles,
                          isLoading: viewModel.isArticlesLoading,
                          errorMessage: viewModel.articleErrorMessage,
                          onViewAll: _openArticles,
                          onRetry: viewModel.retryArticles,
                          onArticleSelected: _openArticleDetails,
                        ),
                      ),
                      _CallToActionSection(
                        onRegister: _openRegister,
                        onFindTherapist: _openTherapists,
                      ),
                      const PublicFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDrawerNavigation(GlobalKey sectionKey) {
    Navigator.of(context).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSection(sectionKey);
    });
  }
}

class _LandingNavigation extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onTherapy;
  final VoidCallback onTherapists;
  final VoidCallback onReviews;
  final VoidCallback onArticles;
  final VoidCallback onAbout;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _LandingNavigation({
    required this.onHome,
    required this.onTherapy,
    required this.onTherapists,
    required this.onReviews,
    required this.onArticles,
    required this.onAbout,
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
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 12),
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
              onTap: onHome,
              borderRadius: BorderRadius.circular(14),
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
              _NavigationButton(label: 'About', onPressed: onAbout),
              const SizedBox(width: 10),
              TextButton(onPressed: onLogin, child: const Text('Log in')),
              const SizedBox(width: 6),
            ],
            if (MediaQuery.sizeOf(context).width < 360)
              IconButton.filled(
                tooltip: 'Register',
                onPressed: onRegister,
                icon: const Icon(Icons.person_add_alt_1_outlined),
              )
            else
              FilledButton(
                onPressed: onRegister,
                child: const Text('Register'),
              ),
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
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF544B5B)),
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
  final VoidCallback onAbout;

  const _LandingDrawer({
    required this.onHome,
    required this.onTherapy,
    required this.onTherapists,
    required this.onReviews,
    required this.onArticles,
    required this.onLogin,
    required this.onRegister,
    required this.onAbout,
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
                    leading: const Icon(Icons.psychology_outlined),
                    title: const Text('Therapy'),
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
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    onTap: onAbout,
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
          radius: 20,
          backgroundColor: Color(0xFFE9DFFF),
          child: Icon(Icons.local_florist_outlined, color: _landingPrimary),
        ),
        SizedBox(width: 10),
        Text(
          'MindBloom',
          style: TextStyle(
            color: _landingPrimary,
            fontSize: 21,
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
        horizontal: isDesktop ? 70 : 20,
        vertical: isDesktop ? 85 : 42,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_landingBackground, _landingSectionLavender],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
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
                    const Expanded(child: _HeroVisual()),
                  ],
                )
              : Column(
                  children: [
                    _HeroContent(
                      isDesktop: false,
                      onFindTherapist: onFindTherapist,
                      onExploreTherapy: onExploreTherapy,
                    ),
                    const SizedBox(height: 30),
                    const _HeroVisual(),
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
            color: _landingSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _landingBorder),
          ),
          child: const Text(
            'A safe space for your mental wellbeing',
            style: TextStyle(
              color: _landingPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Your mind deserves\nspace to bloom.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: _landingText,
            fontSize: isDesktop ? 54 : 36,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Connect with trusted psychotherapists and begin your '
          'journey toward greater emotional balance.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: _landingBody,
            fontSize: 17,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onFindTherapist,
              icon: const Icon(Icons.search),
              label: const Text('Find a therapist'),
            ),
            OutlinedButton.icon(
              onPressed: onExploreTherapy,
              icon: const Icon(Icons.keyboard_arrow_down),
              label: const Text('Explore therapy'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 440),
      child: AspectRatio(
        aspectRatio: 1.08,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE8DDF4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/landing/hero_therapy.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _HeroVisualFallback(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x00FFFFFF), Color(0xBFFFFFFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: _HeroVisualCaption(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroVisualCaption extends StatelessWidget {
  const _HeroVisualCaption();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _landingBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: _landingPrimary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Trusted support, online or in person',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _landingText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroVisualFallback extends StatelessWidget {
  const _HeroVisualFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE8DDF4),
      child: Center(
        child: Icon(Icons.self_improvement, size: 112, color: _landingPrimary),
      ),
    );
  }
}

class _TherapySection extends StatelessWidget {
  final List<TherapyApproachModel> approaches;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRetry;
  final ValueChanged<TherapyApproachModel> onApproachSelected;
  final VoidCallback onReadArticles;

  const _TherapySection({
    required this.approaches,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onApproachSelected,
    required this.onReadArticles,
  });

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'THERAPY DIRECTIONS',
      title: 'Find an approach that suits your needs',
      description: 'Learn about different forms of psychotherapy.',
      backgroundColor: _landingSurface,
      child: _SectionContent(
        isLoading: isLoading,
        isEmpty: approaches.isEmpty,
        errorMessage: errorMessage,
        emptyMessage: 'No active therapy approaches are currently available.',
        onRetry: onRetry,
        footer: OutlinedButton.icon(
          onPressed: onReadArticles,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Read educational articles'),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 3
                : constraints.maxWidth >= 600
                ? 2
                : 1;

            const spacing = 18.0;

            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: approaches.map((approach) {
                return SizedBox(
                  width: itemWidth,
                  child: _TherapyCard(
                    approach: approach,
                    onTap: () {
                      onApproachSelected(approach);
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _TherapyCard extends StatelessWidget {
  final TherapyApproachModel approach;
  final VoidCallback onTap;

  const _TherapyCard({required this.approach, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: _landingTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_landingCardRadius),
        side: const BorderSide(color: _landingBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ApproachIcon(iconUrl: approach.iconUrl),
              const SizedBox(height: 16),
              Text(
                approach.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _landingText,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                approach.description.trim().isEmpty
                    ? 'Learn more about this therapeutic approach.'
                    : approach.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _landingBody, height: 1.45),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Flexible(
                    child: Text(
                      'View therapists',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _landingPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward, size: 18, color: _landingPrimary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApproachIcon extends StatelessWidget {
  final String? iconUrl;

  const _ApproachIcon({required this.iconUrl});

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = iconUrl?.trim();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFE9DFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: normalizedUrl == null || normalizedUrl.isEmpty
          ? const Icon(Icons.psychology_alt_outlined, color: _landingPrimary)
          : Image.network(
              normalizedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.psychology_alt_outlined,
                color: _landingPrimary,
              ),
            ),
    );
  }
}

class _TherapistsSection extends StatelessWidget {
  final List<TherapistModel> therapists;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final ValueChanged<int> onTherapistSelected;

  const _TherapistsSection({
    required this.therapists,
    required this.isLoading,
    required this.errorMessage,
    required this.onViewAll,
    required this.onRetry,
    required this.onTherapistSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'OUR PROFESSIONALS',
      title: 'Meet therapists who are here to listen',
      description: 'Choose a therapist whose experience and approach suit you.',
      backgroundColor: _landingSectionLavender,
      child: _SectionContent(
        isLoading: isLoading,
        isEmpty: therapists.isEmpty,
        errorMessage: errorMessage,
        emptyMessage: 'No therapists are currently available.',
        onRetry: onRetry,

        footer: FilledButton.icon(
          onPressed: onViewAll,
          icon: const Icon(Icons.people_outline),
          label: const Text('View all therapists'),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 700
                ? 300.0
                : (constraints.maxWidth * 0.78).clamp(250.0, 292.0).toDouble();

            return SizedBox(
              height: 398,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: therapists.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final therapist = therapists[index];

                  return SizedBox(
                    width: cardWidth,
                    child: _TherapistCard(
                      therapist: therapist,
                      onTap: () {
                        onTherapistSelected(therapist.id);
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final TherapistModel therapist;
  final VoidCallback onTap;

  const _TherapistCard({required this.therapist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _landingSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_landingCardRadius),
        side: const BorderSide(color: _landingBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TherapistProfileImage(
                    fullName: therapist.fullName,
                    profileImageUrl: therapist.profileImageUrl,
                    radius: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          therapist.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _landingText,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Color(0xFFF2B84B),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${therapist.averageRating.toStringAsFixed(1)}'
                                ' (${therapist.totalReviews})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _landingBody,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                therapist.specialization.trim().isEmpty
                    ? 'Specialization not specified'
                    : therapist.specialization,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _landingPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 10),

              TherapistSessionModes(
                offersOnline: therapist.offersOnline,
                offersInPerson: therapist.offersInPerson,
                compact: true,
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: _landingPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      therapist.formattedLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _landingBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),
              Text(
                '${therapist.hourlyRate.toStringAsFixed(2)} KM / session',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _landingText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_outlined, size: 18),
                  label: const Text('View profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _ReviewsSection({
    required this.reviews,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'CLIENT EXPERIENCES',
      title: 'Stories from people who took the first step',
      description: 'Read experiences shared by clients after therapy.',
      backgroundColor: _landingSurface,
      child: _SectionContent(
        isLoading: isLoading,
        isEmpty: reviews.isEmpty,
        errorMessage: errorMessage,
        emptyMessage: 'There are no approved public reviews yet.',
        onRetry: onRetry,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final cardWidth = isDesktop
                ? 360.0
                : constraints.maxWidth >= 600
                ? 330.0
                : (constraints.maxWidth * 0.88).clamp(260.0, 320.0).toDouble();

            return SizedBox(
              height: 310,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: reviews.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(width: 18);
                },
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: cardWidth,
                    child: _ReviewCard(review: reviews[index]),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final initials = _reviewInitials(review.clientName);

    final therapistName = review.therapistName.trim().isEmpty
        ? 'MindBloom therapist'
        : review.therapistName.trim();

    return Card(
      elevation: 0,
      color: _landingTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_landingCardRadius),
        side: const BorderSide(color: _landingBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE9DFFF),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: _landingPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.format_quote_rounded,
                  size: 34,
                  color: Color(0xFF9277B4),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 2,
              children: List.generate(
                5,
                (index) => Icon(
                  index < review.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: const Color(0xFFF2B84B),
                  size: 21,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                review.comment,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _landingText, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              initials,
              style: const TextStyle(
                color: _landingText,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 18,
                  color: _landingPrimary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Therapist: $therapistName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _landingBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _reviewInitials(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return 'MB';
    }

    final parts = normalized.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      final endIndex = parts.first.length == 1 ? 1 : 2;

      return parts.first.substring(0, endIndex).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _ArticlesSection extends StatelessWidget {
  final List<ArticleModel> articles;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final ValueChanged<int> onArticleSelected;

  const _ArticlesSection({
    required this.articles,
    required this.isLoading,
    required this.errorMessage,
    required this.onViewAll,
    required this.onRetry,
    required this.onArticleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      eyebrow: 'MINDBLOOM ARTICLES',
      title: 'Learn more about yourself and mental health',
      description: 'Explore educational content written by professionals.',
      backgroundColor: _landingSectionLavender,
      child: _SectionContent(
        isLoading: isLoading,
        isEmpty: articles.isEmpty,
        errorMessage: errorMessage,
        emptyMessage: 'There are no published articles yet.',
        onRetry: onRetry,

        footer: OutlinedButton.icon(
          onPressed: onViewAll,
          icon: const Icon(Icons.article_outlined),
          label: const Text('View all articles'),
        ),

        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 3
                : constraints.maxWidth >= 600
                ? 2
                : 1;

            const spacing = 18.0;

            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: articles.map((article) {
                return SizedBox(
                  width: itemWidth,
                  child: _ArticleCard(
                    article: article,
                    onTap: () {
                      onArticleSelected(article.id);
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onTap;

  const _ArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final localPublishedDate = article.publishedAtUtc.toLocal();

    final formattedPublishedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(localPublishedDate);

    final authorName = article.authorName.trim().isEmpty
        ? 'MindBloom'
        : article.authorName.trim();

    final description = article.description.trim().isEmpty
        ? 'Read this MindBloom article to learn more.'
        : article.description.trim();

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_landingCardRadius),
        side: const BorderSide(color: _landingBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _ArticleImage(imageUrl: article.imageUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _landingText,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _landingBody, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 18,
                        color: _landingPrimary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _landingPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 17,
                        color: _landingPrimary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        formattedPublishedDate,
                        style: const TextStyle(
                          color: _landingBody,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Text(
                        'Read article',
                        style: TextStyle(
                          color: _landingPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: _landingPrimary,
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

class _ArticleImage extends StatelessWidget {
  final String imageUrl;

  const _ArticleImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const _ArticleImageFallback();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return const _ArticleImageFallback();
      },
    );
  }
}

class _ArticleImageFallback extends StatelessWidget {
  const _ArticleImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFDFD1F0),
      child: const Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: 65,
          color: Color(0xFF72559A),
        ),
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  final bool isLoading;
  final bool isEmpty;
  final String? errorMessage;
  final String emptyMessage;
  final VoidCallback onRetry;
  final Widget child;
  final Widget? footer;

  const _SectionContent({
    required this.isLoading,
    required this.isEmpty,
    required this.errorMessage,
    required this.emptyMessage,
    required this.onRetry,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && isEmpty) {
      return const AppInlineLoadingIndicator(message: 'Loading section...');
    }

    if (errorMessage != null && isEmpty) {
      return _SectionError(message: errorMessage!, onRetry: onRetry);
    }

    if (isEmpty) {
      return AppInlineEmptyState(
        message: emptyMessage,
        icon: Icons.spa_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (footer != null) ...[const SizedBox(height: 30), footer!],
      ],
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SectionError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppInlineError(
      title: 'Section could not be loaded',
      error: message,
      fallbackMessage: message,
      onRetry: () async => onRetry(),
      margin: EdgeInsets.zero,
    );
  }
}

class _LandingMainError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LandingMainError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(_landingCardRadius),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: _SectionError(message: message, onRetry: onRetry),
    );
  }
}

class _CallToActionSection extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onFindTherapist;

  const _CallToActionSection({
    required this.onRegister,
    required this.onFindTherapist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _landingSurface,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 65),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_landingPrimary, Color(0xFF8A6CAD)],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.local_florist_outlined,
                color: Colors.white,
                size: 46,
              ),
              const SizedBox(height: 16),
              const Text(
                'You do not have to go through everything alone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Create an account or explore available therapists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFF1EAF8), fontSize: 16),
              ),
              const SizedBox(height: 25),
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
        horizontal: isDesktop ? 70 : 20,
        vertical: isDesktop ? 76 : 50,
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
                  color: _landingPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _landingText,
                  fontSize: isDesktop ? 35 : 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _landingBody,
                    fontSize: 16,
                    height: 1.5,
                  ),
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
