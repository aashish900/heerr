import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:heerr/screens/settings/about_footer.dart';
import 'package:heerr/theme.dart';

Widget _wrap({VoidCallback? onGithubTap}) {
  return ProviderScope(
    child: MaterialApp(
      theme: heerrDarkTheme(),
      home: Scaffold(body: AboutFooter(onGithubTap: onGithubTap)),
    ),
  );
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'heerr',
      packageName: 'com.aashish.heerr',
      version: '4.13.0',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  testWidgets('renders version, licenses row, GitHub row, tagline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-app-version')), findsOneWidget);
    expect(find.text('v4.13.0+42'), findsOneWidget);
    expect(find.text('Open source licenses'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Made for self-hosted music lovers'), findsOneWidget);
  });

  testWidgets('tapping "Open source licenses" opens the license page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open source licenses'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('tapping "GitHub" fires the injected callback', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(_wrap(onGithubTap: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
