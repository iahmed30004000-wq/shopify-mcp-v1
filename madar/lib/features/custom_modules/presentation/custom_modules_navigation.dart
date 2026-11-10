import 'package:flutter/material.dart';

import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/module_schema.dart';
import 'custom_modules_screen.dart';
import 'module_builder_screen.dart';
import 'module_screen.dart';
import 'template_gallery_sheet.dart';

/// Opens a module's page (the app router may route instead).
typedef CustomOpenModule = void Function(BuildContext context, String moduleId);

/// Default navigation between the Custom Modules screens when the host
/// passes no callbacks: pushes on the nearest navigator with the
/// shared-axis transition.
abstract final class CustomModulesNavigation {
  static Route<T> _route<T>(Widget page, String name) => PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    pageBuilder: (_, _, _) => page,
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Future<void> openModules(BuildContext context) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route<void>(const CustomModulesScreen(), 'custom-modules'));
  }

  static Future<void> openModule(BuildContext context, String moduleId) {
    return Navigator.of(context).push(_route<void>(ModuleScreen(moduleId: moduleId), 'custom-modules/module'));
  }

  /// Opens the builder: editing [moduleId], or a new module from [draft]
  /// (a template) / blank (attached to [planetKey]). Resolves with the saved
  /// module's id (null when left without saving).
  static Future<String?> openBuilder(
    BuildContext context, {
    String? moduleId,
    ModuleDefinition? draft,
    String? planetKey,
  }) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push<String>(
      _route<String>(
        ModuleBuilderScreen(moduleId: moduleId, draft: draft, planetKey: planetKey),
        'custom-modules/builder',
      ),
    );
  }

  /// "New module": the template gallery, then the builder with the choice.
  /// Opens the new module's page after it is saved when [openAfter].
  static Future<String?> startNew(BuildContext context, {String? planetKey, bool openAfter = true}) async {
    final draft = await showTemplateGallery(context, planetKey: planetKey);
    if (draft == null || !context.mounted) return null;
    final id = await openBuilder(context, draft: draft, planetKey: planetKey);
    if (id != null && openAfter && context.mounted) await openModule(context, id);
    return id;
  }
}
