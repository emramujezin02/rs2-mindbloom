import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/app/router/app_router.dart';
import 'package:mindbloom_mobile/core/constants/public_contact_links.dart';
import 'package:mindbloom_mobile/core/widgets/public_footer.dart';
import 'package:mindbloom_mobile/features/about/presentation/page/about_page.dart';
import 'package:mindbloom_mobile/features/legal/presentation/pages/public_legal_page.dart';

// Synthetic fixtures only; all launches are intercepted at the platform channel.
const _links = PublicContactLinks(
  email: 'footer-test@example.invalid',
  phone: '+387 61 123 456',
  instagram: 'https://www.instagram.com/footer_test_fixture/',
  facebook: 'https://www.facebook.com/footer_test_fixture/',
  youtube: 'https://www.youtube.com/@footer_test_fixture',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final launched = <Map<dynamic, dynamic>>[];
  Object? failure;
  var result = true;
  Completer<bool>? delayed;

  setUp(() {
    launched.clear();
    failure = null;
    result = true;
    delayed = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            launched.add(Map<dynamic, dynamic>.from(call.arguments as Map));
            if (failure != null) throw failure!;
            if (delayed != null) return delayed!.future;
            return result;
          }
          return false;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('contact URIs normalize only formatting and contain no user data', () {
    expect(_links.phoneUri.toString(), 'tel:+38761123456');
    expect(_links.emailUri.toString(), 'mailto:footer-test@example.invalid');
    expect(_links.emailUri!.hasQuery, false);
    expect(const PublicContactLinks().phoneUri, isNull);
    expect(const PublicContactLinks().emailUri, isNull);
    expect(const PublicContactLinks().instagramUri, isNull);
  });
  test(
    'owner-approved demo contacts stay labelled and social accounts stay empty',
    () {
      const links = PublicContactLinks.current;
      expect(links.isDemonstration, true);
      expect(links.emailUri.toString(), 'mailto:support@mindbloom.ba');
      expect(links.phoneUri.toString(), 'tel:+38761000000');
      expect([
        links.instagramUri,
        links.facebookUri,
        links.youtubeUri,
      ], everyElement(isNull));
    },
  );
  for (final bad in [
    'not an email',
    'contact@example.invalid?subject=private',
    'a@b.invalid\r\nBcc:other',
  ]) {
    test('unsafe email is unavailable: $bad', () {
      expect(PublicContactLinks(email: bad).emailUri, isNull);
    });
  }
  for (final bad in ['123', 'tel:+38761123456', '+38761123456?private', '']) {
    test('invalid phone is unavailable: $bad', () {
      expect(PublicContactLinks(phone: bad).phoneUri, isNull);
    });
  }
  for (final bad in [
    'javascript:alert(1)',
    'http://instagram.com/test',
    'https://instagram.com.evil.invalid/test',
    'https://user:password@instagram.com/test',
    'not a uri',
  ]) {
    test('invalid or wrong-platform social link is unavailable: $bad', () {
      expect(PublicContactLinks(instagram: bad).instagramUri, isNull);
    });
  }

  Widget host({PublicContactLinks links = _links, double scale = 1}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(child: PublicFooter(links: links)),
          ),
        ),
        onGenerateRoute: AppRouter.generateRoute,
      );

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'production demonstration notice is visible before contact actions',
    (tester) async {
      await tester.pumpWidget(host(links: PublicContactLinks.current));
      expect(
        find.textContaining('Demonstracijski podaci fakultetskog projekta'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text(PublicContactLinks.current.email));
      expect(launched.single['url'], 'mailto:support@mindbloom.ba');
      launched.clear();
      await tapVisible(tester, find.text(PublicContactLinks.current.phone));
      expect(launched.single['url'], 'tel:+38761000000');
    },
  );

  for (final link in [
    ('Home', AppRouter.home),
    ('Therapists', AppRouter.therapists),
    ('Articles', AppRouter.articles),
  ]) {
    testWidgets(
      'existing ${link.$1} action preserves its navigation destination',
      (tester) async {
        String? destination;
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/footer-origin',
            onGenerateRoute: (settings) {
              if (settings.name == '/footer-origin') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const Scaffold(
                    body: SingleChildScrollView(child: PublicFooter()),
                  ),
                );
              }
              destination = settings.name;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    Scaffold(appBar: AppBar(title: Text(settings.name!))),
              );
            },
          ),
        );
        destination = null;
        await tapVisible(tester, find.text(link.$1));
        expect(destination, link.$2);
        expect(find.text(link.$2), findsOneWidget);
        expect(launched, isEmpty);
      },
    );
  }

  testWidgets('Home on the current home route does not push a duplicate', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tapVisible(tester, find.text('Home'));
    expect(find.byType(PublicFooter), findsOneWidget);
    expect(launched, isEmpty);
  });

  for (final entry in [
    ('O nama', AboutPage),
    ('Uslovi korištenja', PublicLegalPage),
    ('Politika privatnosti', PublicLegalPage),
  ]) {
    testWidgets('${entry.$1} navigates to the real page and back', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tapVisible(tester, find.text(entry.$1));
      expect(find.byType(entry.$2), findsOneWidget);
      if (entry.$2 == PublicLegalPage) {
        expect(find.textContaining('RADNI NACRT'), findsOneWidget);
        expect(
          tester.widget<PublicLegalPage>(find.byType(PublicLegalPage)).document,
          entry.$1 == 'Uslovi korištenja'
              ? PublicLegalDocument.terms
              : PublicLegalDocument.privacy,
        );
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PublicLegalPage), findsNothing);
      expect(find.byType(AboutPage), findsNothing);
      expect(find.byType(PublicFooter), findsOneWidget);
      expect(launched, isEmpty);
    });
  }

  testWidgets('legal footer does not push its own route again', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Origin')),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    navigator.currentState!.pushNamed(AppRouter.terms);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Uslovi korištenja').last);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Origin'), findsOneWidget);
  });

  for (final platform in ['Instagram', 'Facebook', 'YouTube']) {
    testWidgets('$platform launches the correct URL externally on touch', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(launched, isEmpty);
      final button = find.byKey(ValueKey('footer-social-$platform'));
      expect(tester.widget<IconButton>(button).tooltip, platform);
      await tapVisible(tester, button);
      final expected = {
        'Instagram': _links.instagram,
        'Facebook': _links.facebook,
        'YouTube': _links.youtube,
      }[platform];
      expect(launched.single['url'], expected);
      expect(launched.single['useWebView'], false);
      expect(launched.single['useSafariVC'], false);
    });
  }

  for (final entry in [
    (_links.phone, 'tel:+38761123456'),
    (_links.email, 'mailto:footer-test@example.invalid'),
  ]) {
    testWidgets('${entry.$2} is launched only after touching the contact', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(launched, isEmpty);
      await tapVisible(tester, find.text(entry.$1));
      expect(launched.single['url'], entry.$2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'unconfigured or invalid links never launch a fabricated contact',
    (tester) async {
      await tester.pumpWidget(
        host(
          links: const PublicContactLinks(instagram: 'https://wrong.invalid'),
        ),
      );
      for (final platform in ['Instagram', 'Facebook', 'YouTube']) {
        final button = find.byKey(ValueKey('footer-social-$platform'));
        expect(tester.widget<IconButton>(button).onPressed, isNull);
        await tapVisible(tester, button);
      }
      expect(find.text('Telefon nije dostupan'), findsOneWidget);
      expect(find.text('Email nije dostupan'), findsOneWidget);
      expect(launched, isEmpty);
    },
  );

  for (final throws in [false, true]) {
    testWidgets('launcher failure (exception=$throws) shows a safe message', (
      tester,
    ) async {
      result = false;
      if (throws) {
        failure = PlatformException(
          code: 'unsupported',
          message: 'internal detail',
        );
      }
      await tester.pumpWidget(host());
      await tapVisible(tester, find.text(_links.phone));
      expect(
        find.text(
          'Aplikaciju za pozivanje nije moguće otvoriti na ovom uređaju.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('internal detail'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final target in ['email', 'Instagram']) {
    testWidgets('$target launch failure is handled with a readable message', (
      tester,
    ) async {
      result = false;
      await tester.pumpWidget(host());
      await tapVisible(
        tester,
        target == 'email'
            ? find.text(_links.email)
            : find.byKey(const ValueKey('footer-social-Instagram')),
      );
      expect(
        find.textContaining(
          target == 'email'
              ? 'Email aplikaciju nije moguće otvoriti'
              : 'Instagram nije moguće otvoriti',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'late platform failure after disposal does not use a dead context',
    (tester) async {
      delayed = Completer<bool>();
      await tester.pumpWidget(host());
      await tester.ensureVisible(find.text(_links.email));
      await tester.tap(find.text(_links.email));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      delayed!.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 600.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('footer fits width=$width text scale=$scale', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(scale: scale));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('footer-social-YouTube')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('footer-social-Instagram')))
              .width,
          greaterThanOrEqualTo(48),
        );
      });
    }
  }
}
