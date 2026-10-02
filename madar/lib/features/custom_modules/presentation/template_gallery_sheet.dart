import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../domain/module_builder_rules.dart';
import '../domain/module_schema.dart';
import '../domain/module_templates.dart';
import 'widgets/module_visuals.dart';

/// "Start a module": a blank tracker or list, or one of the generic starter
/// templates (reading log, dhikr after prayer, daily habit …). Resolves with
/// an unsaved draft for the builder (null when dismissed). Templates only
/// pre-fill: everything stays editable.
Future<ModuleDefinition?> showTemplateGallery(BuildContext context, {String? planetKey}) =>
    showInteractionSheet<ModuleDefinition>(context, builder: (_) => TemplateGallerySheet(planetKey: planetKey));

class TemplateGallerySheet extends StatelessWidget {
  const TemplateGallerySheet({super.key, this.planetKey});

  /// Attach new modules to this planet (a planet hub's "create").
  final String? planetKey;

  static const int _blankColor = 0xFFC9A45C;

  @override
  Widget build(BuildContext context) {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    ModuleDefinition blank(CustomModuleKind kind) {
      final color = planetKey == null ? _blankColor : (ModuleTemplates.planetColors[planetKey] ?? _blankColor);
      return ModuleBuilderRules.blank(colorArgb: color, planetKey: planetKey, kind: kind);
    }

    ModuleDefinition fromTemplate(ModuleTemplateKey k) {
      final d = ModuleTemplates.build(k, tx.template);
      return planetKey == null ? d : d.copyWith(planetKey: planetKey);
    }

    var i = 0;
    return InteractionSheetFrame(
      title: l.cmodGalleryTitle,
      subtitle: l.cmodGallerySubtitle,
      icon: Icons.auto_awesome_rounded,
      body: EntranceChoreo(
        id: 'cmod-gallery',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggerItem(
              index: i++,
              child: Row(
                children: [
                  Expanded(
                    child: _BlankCard(
                      icon: Icons.insights_rounded,
                      title: l.cmodBlankTracker,
                      hint: l.cmodKindTrackerHint,
                      onTap: () => Navigator.of(context).pop(blank(CustomModuleKind.tracker)),
                    ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: _BlankCard(
                      icon: Icons.checklist_rtl_rounded,
                      title: l.cmodBlankList,
                      hint: l.cmodKindListHint,
                      onTap: () => Navigator.of(context).pop(blank(CustomModuleKind.list)),
                    ),
                  ),
                ],
              ),
            ),
            StaggerItem(index: i++, child: ModuleSectionTitle(title: l.cmodTemplatesHeader)),
            for (final k in ModuleTemplates.all)
              StaggerItem(
                index: i++,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                  child: _TemplateCard(
                    draft: fromTemplate(k),
                    title: tx.templateName(k),
                    description: tx.templateDescription(k),
                    onTap: () => Navigator.of(context).pop(fromTemplate(k)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlankCard extends StatelessWidget {
  const _BlankCard({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: () {
        Fx.fire(Sfx.tap);
        onTap();
      },
      semanticLabel: '$title. $hint',
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsets.all(Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.metalBrass.withValues(alpha: 0.7), width: 1.2),
              color: t.metalBrass.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: t.metalBrass, size: 22),
          ),
          const SizedBox(height: Space.s),
          Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(hint, style: text.bodySmall!.copyWith(color: t.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.draft, required this.title, required this.description, required this.onTap});

  final ModuleDefinition draft;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    final c = ModuleColors.of(draft.colorArgb, t);
    return GlassCard(
      onTap: () {
        Fx.fire(Sfx.tap);
        onTap();
      },
      semanticLabel: '$title. $description. ${tx.kind(draft.kind)}',
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsets.all(Space.m),
      child: Row(
        children: [
          ModuleOrb.of(draft, size: 46),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: Space.s),
                    ModuleBadge(label: tx.kind(draft.kind), color: c.ink),
                  ],
                ),
                const SizedBox(height: 2),
                Text(description, style: text.bodySmall!.copyWith(color: t.textSecondary), maxLines: 2),
                const SizedBox(height: Space.xs + 2),
                Row(
                  children: [
                    for (final f in draft.visibleFields) ...[
                      Icon(ModuleIcons.field(f.type), size: 15, color: t.textTertiary),
                      const SizedBox(width: Space.xs + 2),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: t.textTertiary),
        ],
      ),
    );
  }
}
