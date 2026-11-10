// What the kids shell lists from this folder: «التلوين».
//
// The shell must also override [colouringParentGateProvider] with its real
// parent gate; until it does, adding or deleting a picture is simply refused.
import 'package:flutter/material.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../core/kids_section.dart';
import '../learn/ui/kids_tokens.dart';
import 'ui/colouring_screen.dart';

export 'ui/colouring_providers.dart'
    show ParentGate, colouringParentGateProvider, colouringStoreProvider, colouringPickerProvider;
export 'ui/colouring_screen.dart' show ColouringScreen;

/// Built-in geometric pages and the parent's own pictures.
final KidsSection colouringSection = KidsSection(
  id: 'colouring',
  title: (L10n l) => l.kidsColouringTitle,
  icon: Icons.palette_rounded,
  accent: KidsColors.rose500,
  order: 60,
  builder: (context) => const ColouringScreen(),
);
