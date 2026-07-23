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
      backgroundColor: const Color(0xFFFCFAFF),
      drawer: _LandingDrawer(
        onHome: () => _handleDrawerNavigation(homeSectionKey),
        onTherapy: () => _handleDrawerNavigation(therapySectionKey),
        onTherapists: () => _handleDrawerNavigation(therapistsSectionKey),
        onReviews: () => _handleDrawerNavigation(reviewsSectionKey),
        onArticles: () => _handleDrawerNavigation(articlesSectionKey),
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
                          isLoading: viewModel.isLoading,
                          errorMessage: viewModel.articleErrorMessage,
                          onViewAll: _openArticles,
                          onRetry: viewModel.loadLandingData,
                          onArticleSelected: _openArticleDetails,
                        ),
                      ),
                      _CallToActionSection(
                        onRegister: _openRegister,
                        onFindTherapist: _openTherapists,
                      ),
                      const _LandingFooter(),
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
              const SizedBox(width: 10),
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
          child: Icon(Icons.local_florist_outlined, color: Color(0xFF72559A)),
        ),
        SizedBox(width: 10),
        Text(
          'MindBloom',
          style: TextStyle(
            color: Color(0xFF5C477B),
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
        horizontal: isDesktop ? 70 : 24,
        vertical: isDesktop ? 85 : 52,
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
                    const SizedBox(height: 40),
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
          'Connect with trusted psychotherapists and begin your '
          'journey toward greater emotional balance.',
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
    return AspectRatio(
      aspectRatio: 1.15,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFDED0F0),
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.self_improvement,
            size: 135,
            color: Color(0xFF72559A),
          ),
        ),
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
      backgroundColor: Colors.white,
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
      color: const Color(0xFFFAF7FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE8DEF3)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFFE9DFFF),
                child: Icon(
                  Icons.psychology_alt_outlined,
                  color: Color(0xFF72559A),
                ),
              ),
              const SizedBox(height: 17),
              Text(
                approach.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                approach.description.trim().isEmpty
                    ? 'Learn more about this therapeutic approach.'
                    : approach.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6D6673), height: 1.5),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text(
                    'View therapists',
                    style: TextStyle(
                      color: Color(0xFF72559A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward, size: 18, color: Color(0xFF72559A)),
                ],
              ),
            ],
          ),
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
      backgroundColor: const Color(0xFFF5EFFC),
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
        child: SizedBox(
          height: 430,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: therapists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final therapist = therapists[index];

              return SizedBox(
                width: 290,
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
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE1D5ED)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: TherapistProfileImage(
                  fullName: therapist.fullName,
                  profileImageUrl: therapist.profileImageUrl,
                  radius: 42,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                therapist.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                therapist.specialization,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF72559A),
                  fontWeight: FontWeight.w600,
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
                  const Icon(Icons.star, size: 18, color: Color(0xFFF2B84B)),
                  const SizedBox(width: 4),
                  Text(
                    therapist.averageRating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                '${therapist.hourlyRate.toStringAsFixed(2)} KM / session',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  child: const Text('View profile'),
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
      backgroundColor: Colors.white,
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
                : constraints.maxWidth * 0.88;

            return SizedBox(
              height: 330,
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
    final initials = review.clientName.trim().isEmpty
        ? 'MB'
        : review.clientName.trim();

    final therapistName = review.therapistName.trim().isEmpty
        ? 'MindBloom therapist'
        : review.therapistName.trim();

    return Card(
      elevation: 0,
      color: const Color(0xFFFAF7FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE7DDF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
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
                      color: Color(0xFF684C8E),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.format_quote_rounded,
                  size: 38,
                  color: Color(0xFF9277B4),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 14),
            Expanded(
              child: Text(
                review.comment,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF5F5865), height: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF3E3152),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 18,
                  color: Color(0xFF9277B4),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Therapist: $therapistName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B6272),
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
      backgroundColor: const Color(0xFFF5EFFC),
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
                  const SizedBox(height: 14),
                  Text(
                    article.authorName.isEmpty
                        ? 'MindBloom'
                        : article.authorName,
                    style: const TextStyle(
                      color: Color(0xFF8063A4),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 13),
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
      return const Padding(
        padding: EdgeInsets.all(35),
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null && isEmpty) {
      return _SectionError(message: errorMessage!, onRetry: onRetry);
    }

    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6A6370), fontSize: 16),
        ),
      );
    }

    return Column(
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
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
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
      margin: const EdgeInsets.all(22),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 65),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 45),
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
              const SizedBox(height: 16),
              const Text(
                'You do not have to go through everything alone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
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

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3D314A),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 46),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 750) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _FooterAbout()),
                        Expanded(child: _FooterLinks()),
                        Expanded(child: _FooterContact()),
                      ],
                    );
                  }

                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FooterAbout(),
                      SizedBox(height: 28),
                      _FooterLinks(),
                      SizedBox(height: 28),
                      _FooterContact(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
              const Divider(color: Color(0xFF665A70)),
              const SizedBox(height: 18),
              const Text(
                '© 2026 MindBloom. All rights reserved.',
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
            'A digital space for emotional support and personal growth.',
            style: _footerTextStyle,
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
    return _FooterColumn(
      title: 'Useful links',
      children: [
        InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(AppRouter.about);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('About us', style: _footerTextStyle),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Terms of use', style: _footerTextStyle),
        const SizedBox(height: 10),
        const Text('Privacy policy', style: _footerTextStyle),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(AppRouter.articles);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Articles', style: _footerTextStyle),
          ),
        ),
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
        Text('support@mindbloom.ba', style: _footerTextStyle),
        SizedBox(height: 10),
        Text('Mostar, Bosnia and Herzegovina', style: _footerTextStyle),
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
        vertical: isDesktop ? 76 : 55,
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
              const SizedBox(height: 13),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6A6370),
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

const TextStyle _footerTextStyle = TextStyle(
  color: Color(0xFFCFC4D7),
  height: 1.5,
);
