import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../app/licenses.dart';
import '../../core/sound/sound_api.dart';
import 'widgets/settings_widgets.dart';

/// A bundled font and its licence file.
@immutable
class FontCredit {
  const FontCredit({required this.family, required this.name, required this.role, required this.licenseAsset});

  /// Flutter font family used to render the name as a specimen.
  final String family;
  final String Function(L10n l) name;
  final String Function(L10n l) role;
  final String licenseAsset;
}

/// The fonts Madar ships (all SIL OFL 1.1; texts in assets/fonts/licenses).
final List<FontCredit> madarFontCredits = [
  FontCredit(
    family: MadarTypography.uiFamily,
    name: (l) => l.settingsFontPlex,
    role: (l) => l.settingsFontRoleUi,
    licenseAsset: 'assets/fonts/licenses/ibmplexsansarabic-OFL.txt',
  ),
  FontCredit(
    family: MadarTypography.displayFamily,
    name: (l) => l.settingsFontReemKufi,
    role: (l) => l.settingsFontRoleDisplay,
    licenseAsset: 'assets/fonts/licenses/reemkufi-OFL.txt',
  ),
  FontCredit(
    family: MadarTypography.quranFamily,
    name: (l) => l.settingsFontAmiriQuran,
    role: (l) => l.settingsFontRoleQuran,
    licenseAsset: 'assets/fonts/licenses/amiriquran-OFL.txt',
  ),
  FontCredit(
    family: MadarTypography.naskhFamily,
    name: (l) => l.settingsFontAmiri,
    role: (l) => l.settingsFontRoleNaskh,
    licenseAsset: 'assets/fonts/licenses/amiri-OFL.txt',
  ),
];

/// Bundled content and the file crediting its sources and licences.
@immutable
class ContentCredit {
  const ContentCredit({required this.icon, required this.name, required this.role, required this.licenseAsset});

  final IconData icon;
  final String Function(L10n l) name;
  final String Function(L10n l) role;
  final String licenseAsset;
}

/// The openly licensed content Madar ships (texts in assets/licenses; also
/// registered with the licence page, see [MadarLicenses.content]).
final List<ContentCredit> madarContentCredits = [
  ContentCredit(
    icon: Icons.menu_book_rounded,
    name: (l) => l.settingsCreditAdhkar,
    role: (l) => l.settingsCreditAdhkarRole,
    licenseAsset: MadarLicenses.content['Adhkar – Hisn al-Muslim']!,
  ),
  ContentCredit(
    icon: Icons.public_rounded,
    name: (l) => l.settingsCreditCities,
    role: (l) => l.settingsCreditCitiesRole,
    licenseAsset: MadarLicenses.content['Madar city list']!,
  ),
  ContentCredit(
    icon: Icons.music_note_rounded,
    name: (l) => l.settingsCreditAdhan,
    role: (l) => l.settingsCreditAdhanRole,
    licenseAsset: MadarLicenses.content['Madar adhan tones']!,
  ),
];

/// Licence text of a bundled asset (overridable in tests).
final licenseTextProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, asset) => rootBundle.loadString(asset),
);

/// Fonts & sources: each font's name set in itself, its role, and its full
/// licence text on demand; then the bundled content (adhkar, city list,
/// adhan tones) with the full credits of its sources.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarScaffold(
      title: l.settingsCredits,
      extendBodyBehindAppBar: true,
      backdropSeed: 0.72,
      body: SettingsListView(
        horizontal: Space.gutter,
        top: Space.l,
        children: [
          Text(
            l.settingsFontsBody(MadarFormatter.of(context).formatVersion('1.1')),
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: Space.l),
          StaggerIn(
            id: 'licenses',
            spacing: Space.m,
            children: [
              for (final f in madarFontCredits)
                _CreditCard(
                  name: f.name(l),
                  role: f.role(l),
                  licenseAsset: f.licenseAsset,
                  nameStyle: TextStyle(fontFamily: f.family, fontSize: 20, color: t.textPrimary, height: 1.4),
                  latinName: true,
                ),
              SectionHeader(
                title: l.settingsCreditsContent,
                subtitle: l.settingsCreditsContentBody,
                padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, 0),
              ),
              for (final c in madarContentCredits)
                _CreditCard(
                  name: c.name(l),
                  role: c.role(l),
                  licenseAsset: c.licenseAsset,
                  icon: c.icon,
                  nameStyle: text.titleMedium!.copyWith(color: t.textPrimary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A credit that opens onto its full licence / credits text.
class _CreditCard extends ConsumerStatefulWidget {
  const _CreditCard({
    required this.name,
    required this.role,
    required this.licenseAsset,
    required this.nameStyle,
    this.icon,
    this.latinName = false,
  });

  final String name;
  final String role;
  final String licenseAsset;
  final TextStyle nameStyle;
  final IconData? icon;

  /// A font's own (Latin) name, set in itself left to right.
  final bool latinName;

  @override
  ConsumerState<_CreditCard> createState() => _CreditCardState();
}

class _CreditCardState extends ConsumerState<_CreditCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = widget;
    return GlassCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MadarPressable(
            onTap: () {
              Fx.fire(_open ? Sfx.sheetClose : Sfx.sheetOpen);
              setState(() => _open = !_open);
            },
            sfx: null,
            pressScale: 0.985,
            toggled: _open,
            semanticLabel: '${c.name}, ${c.role}. ${l.settingsLicense}',
            excludeChildSemantics: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(Space.l),
              child: Row(
                children: [
                  if (c.icon case final icon?) ...[SettingsIcon(icon, color: t.gold), const SizedBox(width: Space.m)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.name, textDirection: c.latinName ? TextDirection.ltr : null, style: c.nameStyle),
                        Text(c.role, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: context.motion(MadarMotion.medium),
                    curve: MadarMotion.standard,
                    child: Icon(Icons.expand_more_rounded, color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.standard,
            alignment: AlignmentDirectional.topStart,
            child: _open ? _LicenseText(asset: c.licenseAsset) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _LicenseText extends ConsumerWidget {
  const _LicenseText({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final license = ref.watch(licenseTextProvider(asset));
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.l),
      child: switch (license) {
        AsyncData(:final value) => Directionality(
          // Licence texts are English legal documents.
          textDirection: TextDirection.ltr,
          child: SelectableText(
            value.trim(),
            style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.5, fontSize: 11.5),
          ),
        ),
        AsyncError() => Text(l.settingsLicenseUnavailable, style: text.bodySmall!.copyWith(color: t.danger)),
        _ => const Padding(
          padding: EdgeInsetsDirectional.all(Space.l),
          child: Center(child: OrbitLoader(size: 24)),
        ),
      },
    );
  }
}
