// A phone-sized MaterialApp for the kids screens: Arabic, RTL, the app's own
// localisations, a chosen text scale and size.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

Widget kidsApp(
  Widget home, {
  double textScale = 1.0,
  Locale locale = const Locale('ar'),
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildMadarTheme(MadarThemeId.lapis, arabic: locale.languageCode == 'ar'),
    locale: locale,
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: L10n.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: SafeArea(child: home)),
  ),
);

void setPhone(WidgetTester tester, {double width = 360, double height = 780}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
