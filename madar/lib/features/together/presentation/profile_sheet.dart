import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/together_providers.dart';
import '../domain/player_profile.dart';
import '../domain/together_bounds.dart';
import 'together_texts.dart';
import 'widgets/together_visuals.dart';

/// Opens the profile editor of [slot]; saves on "Save".
Future<void> showTogetherProfileSheet(BuildContext context, PlayerSlot slot, {math.Random? random}) =>
    showInteractionSheet<void>(context, builder: (_) => TogetherProfileSheet(slot: slot, random: random));

/// Name, avatar (generated emblem, emoji or initial), colour and title of
/// one player, with a live preview.
class TogetherProfileSheet extends ConsumerStatefulWidget {
  const TogetherProfileSheet({super.key, required this.slot, this.random});

  final PlayerSlot slot;
  final math.Random? random;

  @override
  ConsumerState<TogetherProfileSheet> createState() => _TogetherProfileSheetState();
}

class _TogetherProfileSheetState extends ConsumerState<TogetherProfileSheet> {
  late TogetherProfile _draft;
  late TogetherProfile _other;
  late final TextEditingController _name;
  late final TextEditingController _customTitle;
  late int _variantBase;
  late bool _customTitleOn;
  late final math.Random _random = widget.random ?? math.Random();

  @override
  void initState() {
    super.initState();
    final profiles = ref.read(togetherProfilesProvider).value ?? TogetherProfiles.defaults();
    _draft = profiles.of(widget.slot);
    _other = profiles.of(widget.slot.other);
    _name = TextEditingController(text: _draft.name);
    _customTitle = TextEditingController(text: _draft.customTitle);
    _customTitleOn = _draft.title == null && _draft.customTitle.isNotEmpty;
    _variantBase = _draft.avatar.seed;
  }

  @override
  void dispose() {
    _name.dispose();
    _customTitle.dispose();
    super.dispose();
  }

  TogetherProfile get _result => _draft.copyWith(
    name: _name.text,
    customTitle: _customTitleOn ? _customTitle.text : '',
    clearTitle: _customTitleOn || _draft.title == null,
    title: _customTitleOn ? null : _draft.title,
  );

  Future<void> _save() async {
    final result = _result;
    await ref.read(togetherRepositoryProvider).saveProfile(result);
    Fx.fire(Sfx.complete);
    if (mounted) Navigator.of(context).pop();
  }

  List<int> get _variants => [
    for (var i = 0; i < 6; i++) (_variantBase + i * 7919) % TogetherAvatar.seedCount,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final preview = _result;
    final defaultName = l.togetherPlayerDefault(tx.n(widget.slot.index + 1));
    Widget gap([double h = Space.xl]) => SizedBox(height: h);

    return InteractionSheetFrame(
      title: l.togetherProfileTitle,
      subtitle: tx.rawName(preview),
      icon: Icons.person_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              child: TogetherAvatarView(
                key: ValueKey(preview.avatar.hashCode ^ preview.colorIndex ^ preview.name.hashCode),
                profile: preview,
                displayName: preview.name.isEmpty ? defaultName : preview.name,
                size: 104,
                glow: true,
              ),
            ),
          ),
          gap(Space.l),
          FieldShell(
            label: l.togetherFieldName,
            icon: Icons.badge_rounded,
            child: TextField(
              key: const ValueKey('together-name-field'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(TogetherBounds.maxNameLength)],
              decoration: kitInputDecoration(context, hint: defaultName),
              onChanged: (_) => setState(() {}),
            ),
          ),
          gap(),
          FieldShell(
            label: l.togetherFieldAvatar,
            icon: Icons.auto_awesome_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoicePills<AvatarKind>.single(
                  dense: true,
                  options: [
                    ChoiceOption(value: AvatarKind.constellation, label: l.togetherAvatarConstellation, icon: Icons.star_rounded),
                    ChoiceOption(value: AvatarKind.emoji, label: l.togetherAvatarEmoji, icon: Icons.emoji_emotions_rounded),
                    ChoiceOption(value: AvatarKind.initials, label: l.togetherAvatarInitials, icon: Icons.title_rounded),
                  ],
                  selected: _draft.avatar.kind,
                  onChanged: (k) {
                    if (k == null) return;
                    setState(() {
                      _draft = _draft.copyWith(
                        avatar: switch (k) {
                          AvatarKind.constellation => TogetherAvatar.constellation(_draft.avatar.seed),
                          AvatarKind.emoji => TogetherAvatar.emoji(
                            _draft.avatar.emoji ?? TogetherEmoji.choices[_draft.avatar.seed % TogetherEmoji.choices.length],
                            seed: _draft.avatar.seed,
                          ),
                          AvatarKind.initials => TogetherAvatar.initials(seed: _draft.avatar.seed),
                        },
                      );
                    });
                  },
                ),
                const SizedBox(height: Space.m),
                AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  alignment: AlignmentDirectional.topStart,
                  child: switch (_draft.avatar.kind) {
                    AvatarKind.constellation => _EmblemGrid(
                      profile: _draft,
                      seeds: _variants,
                      onPick: (seed) => setState(() => _draft = _draft.copyWith(avatar: TogetherAvatar.constellation(seed))),
                      onShuffle: () => setState(() => _variantBase = _random.nextInt(TogetherAvatar.seedCount)),
                    ),
                    AvatarKind.emoji => _EmojiGrid(
                      selected: _draft.avatar.emoji,
                      color: TogetherLook.colorOf(_draft),
                      onPick: (e) =>
                          setState(() => _draft = _draft.copyWith(avatar: TogetherAvatar.emoji(e, seed: _draft.avatar.seed))),
                    ),
                    AvatarKind.initials => const SizedBox(width: double.infinity),
                  },
                ),
              ],
            ),
          ),
          gap(),
          FieldShell(
            label: l.togetherFieldColor,
            icon: Icons.palette_rounded,
            child: Wrap(
              spacing: Space.m,
              runSpacing: Space.m,
              children: [
                for (var i = 0; i < TogetherPalette.colors.length; i++)
                  _Swatch(
                    color: TogetherLook.paletteColor(i),
                    selected: _draft.colorIndex == i,
                    taken: _other.colorIndex == i,
                    label: _other.colorIndex == i
                        ? l.togetherColorTaken(tx.name(_other))
                        : tx.digits(l.interactionFieldColor(i + 1)),
                    onTap: () => setState(() => _draft = _draft.copyWith(colorIndex: i)),
                  ),
              ],
            ),
          ),
          gap(),
          FieldShell(
            label: l.togetherFieldTitle,
            icon: Icons.military_tech_rounded,
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    MadarChip(
                      label: l.togetherTitleNone,
                      dense: true,
                      selected: _draft.title == null && !_customTitleOn,
                      onSelected: (_) => setState(() {
                        _customTitleOn = false;
                        _draft = _draft.copyWith(clearTitle: true);
                      }),
                    ),
                    for (final p in PlayerTitle.values)
                      MadarChip(
                        label: tx.titleOf(p),
                        dense: true,
                        selected: _draft.title == p && !_customTitleOn,
                        onSelected: (_) => setState(() {
                          _customTitleOn = false;
                          _draft = _draft.copyWith(title: p);
                        }),
                      ),
                    MadarChip(
                      label: l.togetherTitleCustom,
                      icon: Icons.edit_rounded,
                      dense: true,
                      selected: _customTitleOn,
                      onSelected: (_) => setState(() => _customTitleOn = true),
                    ),
                  ],
                ),
                if (_customTitleOn) ...[
                  const SizedBox(height: Space.m),
                  TextField(
                    key: const ValueKey('together-title-field'),
                    controller: _customTitle,
                    autofocus: true,
                    inputFormatters: [LengthLimitingTextInputFormatter(TogetherBounds.maxTitleLength)],
                    decoration: kitInputDecoration(context, hint: l.togetherTitleCustomHint),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            tx.title(preview) ?? '',
            style: text.bodySmall?.copyWith(color: t.gold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(label: l.togetherCancel, sfx: Sfx.sheetClose, onPressed: () => Navigator.of(context).pop()),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(
              key: const ValueKey('together-profile-save'),
              label: l.togetherSave,
              icon: Icons.check_rounded,
              primary: true,
              sfx: null,
              onPressed: () => unawaited(_save()),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmblemGrid extends StatelessWidget {
  const _EmblemGrid({required this.profile, required this.seeds, required this.onPick, required this.onShuffle});

  final TogetherProfile profile;
  final List<int> seeds;
  final ValueChanged<int> onPick;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    return Wrap(
      spacing: Space.m,
      runSpacing: Space.m,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, seed) in seeds.indexed)
          MadarPressable(
            key: ValueKey('together-emblem-$i'),
            onTap: () => onPick(seed),
            selected: profile.avatar.kind == AvatarKind.constellation && profile.avatar.seed == seed,
            semanticLabel: tx.digits(tx.l.togetherAvatarOption(tx.n(i + 1))),
            excludeChildSemantics: true,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: profile.avatar.seed == seed ? t.textPrimary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: TogetherAvatarView(
                profile: profile.copyWith(avatar: TogetherAvatar.constellation(seed)),
                displayName: '',
                size: 48,
                ring: false,
              ),
            ),
          ),
        MadarButton.icon(
          icon: Icons.shuffle_rounded,
          onPressed: onShuffle,
          semanticLabel: tx.l.togetherAvatarShuffle,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
        ),
      ],
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.selected, required this.color, required this.onPick});

  final String? selected;
  final Color color;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final e in TogetherEmoji.choices)
          MadarPressable(
            onTap: () => onPick(e),
            selected: e == selected,
            semanticLabel: e,
            excludeChildSemantics: true,
            child: AnimatedContainer(
              duration: context.motion(MadarMotion.short),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: e == selected ? color.withValues(alpha: 0.35) : t.glassFill,
                border: Border.all(color: e == selected ? color : t.glassBorder, width: e == selected ? 1.8 : 0.8),
              ),
              child: Text(e, style: const TextStyle(fontSize: 22, height: 1.1, fontFamilyFallback: TogetherLook.emojiFallback)),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.taken,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool taken;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MadarPressable(
      onTap: taken ? () => Fx.fire(Sfx.error) : onTap,
      sfx: taken ? null : Sfx.tap,
      selected: selected,
      enabled: true,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Color.lerp(color, Colors.white, 0.3)!, color],
          ),
          border: Border.all(color: selected ? t.textPrimary : t.glassBorder, width: selected ? 2.4 : 0.8),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14)] : null,
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 20, color: TogetherLook.inkOn(color))
            : taken
            ? Icon(Icons.person_rounded, size: 18, color: TogetherLook.inkOn(color).withValues(alpha: 0.8))
            : null,
      ),
    );
  }
}
