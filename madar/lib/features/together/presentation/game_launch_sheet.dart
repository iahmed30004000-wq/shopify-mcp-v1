import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/together_providers.dart';
import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import 'mode_picker.dart';
import 'together_texts.dart';
import 'widgets/together_visuals.dart';

/// What the players chose at the start of a game.
@immutable
final class GameLaunchChoice {
  const GameLaunchChoice({required this.mode, required this.firstPlayer, this.splitLayout = SplitLayout.faceToFace});

  final PlayMode mode;

  /// Who plays first (seat 0).
  final PlayerSlot firstPlayer;
  final SplitLayout splitLayout;

  /// Participant → player for `TogetherSession(seating: …)`: the first
  /// player is participant 0.
  List<PlayerSlot> get seating => [firstPlayer, firstPlayer.other];

  @override
  bool operator ==(Object other) =>
      other is GameLaunchChoice &&
      other.mode == mode &&
      other.firstPlayer == firstPlayer &&
      other.splitLayout == splitLayout;

  @override
  int get hashCode => Object.hash(mode, firstPlayer, splitLayout);

  @override
  String toString() => 'GameLaunchChoice(${mode.name}, first: ${firstPlayer.name}, ${splitLayout.name})';
}

/// Asks how to play [game] (its [TogetherGameInfo.modes] only; the settings'
/// default pre-selected when the game offers it) and who starts. Null when
/// dismissed.
Future<GameLaunchChoice?> showGameLaunchSheet(
  BuildContext context, {
  required TogetherGameInfo game,
  String? title,
  math.Random? random,
}) => showInteractionSheet<GameLaunchChoice>(
  context,
  builder: (_) => GameLaunchSheet(game: game, title: title, random: random),
);

enum _Starter { one, two, random }

class GameLaunchSheet extends ConsumerStatefulWidget {
  const GameLaunchSheet({super.key, required this.game, this.title, this.random});

  final TogetherGameInfo game;

  /// The game's display name (default: the Together catalogue name).
  final String? title;
  final math.Random? random;

  @override
  ConsumerState<GameLaunchSheet> createState() => _GameLaunchSheetState();
}

class _GameLaunchSheetState extends ConsumerState<GameLaunchSheet> {
  PlayMode? _mode;
  SplitLayout? _layout;
  _Starter _starter = _Starter.one;

  PlayMode? _defaultMode(TogetherSettings settings) {
    final availability = ref.read(togetherModeAvailabilityProvider);
    bool ok(PlayMode m) => availability(m, gameModes: widget.game.modes) == ModeAvailability.available;
    if (ok(settings.defaultMode)) return settings.defaultMode;
    return PlayMode.values.where(ok).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(togetherSettingsProvider).value ?? const TogetherSettings();
    final profiles = ref.watch(togetherProfilesProvider).value ?? TogetherProfiles.defaults();
    final availability = ref.watch(togetherModeAvailabilityProvider);
    final mode = _mode ?? _defaultMode(settings);
    final layout = _layout ?? settings.splitLayout;
    final canStart = mode != null && availability(mode, gameModes: widget.game.modes) == ModeAvailability.available;
    final twoPhones = widget.game.modes.any((m) => !m.sameDevice);

    return InteractionSheetFrame(
      title: widget.title ?? tx.game(widget.game.id),
      subtitle: l.togetherLaunchSubtitle,
      icon: TogetherLook.gameIcon(widget.game.id),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TogetherVersusRow(
            profiles: profiles,
            highlight: switch (_starter) {
              _Starter.one => PlayerSlot.one,
              _Starter.two => PlayerSlot.two,
              _Starter.random => null,
            },
          ),
          const SizedBox(height: Space.xl),
          PlayModePicker(
            selected: mode,
            gameModes: widget.game.modes,
            onChanged: (m) => setState(() => _mode = m),
          ),
          if (mode == PlayMode.splitScreen) ...[
            const SizedBox(height: Space.l),
            FieldShell(
              label: l.togetherSplitLayout,
              icon: Icons.screen_rotation_alt_rounded,
              child: ChoicePills<SplitLayout>.single(
                dense: true,
                options: [for (final s in SplitLayout.values) ChoiceOption(value: s, label: tx.layout(s))],
                selected: layout,
                onChanged: (s) {
                  if (s != null) setState(() => _layout = s);
                },
              ),
            ),
          ],
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.togetherWhoStarts,
            icon: Icons.flag_rounded,
            child: ChoicePills<_Starter>.single(
              dense: true,
              options: [
                ChoiceOption(
                  value: _Starter.one,
                  label: tx.rawName(profiles.one),
                  color: TogetherLook.colorOf(profiles.one),
                ),
                ChoiceOption(
                  value: _Starter.two,
                  label: tx.rawName(profiles.two),
                  color: TogetherLook.colorOf(profiles.two),
                ),
                ChoiceOption(value: _Starter.random, label: l.togetherRandomStart, icon: Icons.casino_rounded),
              ],
              selected: _starter,
              onChanged: (s) {
                if (s != null) setState(() => _starter = s);
              },
            ),
          ),
          if (twoPhones) ...[
            const SizedBox(height: Space.l),
            const TogetherPrivacyNote(),
          ],
          if (!canStart && mode != null) ...[
            const SizedBox(height: Space.s),
            Text(
              tx.availability(availability(mode, gameModes: widget.game.modes)) ?? '',
              style: text.bodySmall?.copyWith(color: t.warning),
            ),
          ],
        ],
      ),
      footer: SheetButton(
        key: const ValueKey('together-launch-start'),
        label: l.togetherStartGame,
        icon: Icons.play_arrow_rounded,
        primary: true,
        enabled: canStart,
        sfx: Sfx.navigate,
        onDisabledTap: () => Fx.fire(Sfx.error),
        onPressed: () {
          final first = switch (_starter) {
            _Starter.one => PlayerSlot.one,
            _Starter.two => PlayerSlot.two,
            _Starter.random => (widget.random ?? math.Random()).nextBool() ? PlayerSlot.one : PlayerSlot.two,
          };
          Navigator.of(context).pop(GameLaunchChoice(mode: mode!, firstPlayer: first, splitLayout: layout));
        },
      ),
    );
  }
}

/// The two players facing each other: avatar, name and title, with the
/// astrolabe-gold "vs" between them. [highlight] lights one player.
class TogetherVersusRow extends StatelessWidget {
  const TogetherVersusRow({super.key, required this.profiles, this.highlight, this.onTap, this.avatarSize = 64});

  final TogetherProfiles profiles;
  final PlayerSlot? highlight;
  final ValueChanged<PlayerSlot>? onTap;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    Widget player(TogetherProfile p) {
      final lit = highlight == null || highlight == p.slot;
      final title = tx.title(p);
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TogetherAvatarView(
            profile: p,
            displayName: tx.rawName(p),
            size: avatarSize,
            glow: highlight == p.slot,
            dim: !lit,
          ),
          const SizedBox(height: Space.s),
          Text(
            tx.rawName(p),
            style: text.titleSmall?.copyWith(color: lit ? t.textPrimary : t.textTertiary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (title != null)
            Text(
              title,
              style: text.labelSmall?.copyWith(color: t.gold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
        ],
      );
      final tap = onTap;
      return Expanded(
        child: tap == null
            ? column
            : MadarPressable(
                onTap: () => tap(p.slot),
                semanticLabel: tx.l.togetherEditProfile(tx.name(p)),
                child: column,
              ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        player(profiles.one),
        Padding(
          padding: EdgeInsets.only(top: avatarSize / 2 - 14),
          child: Text(
            tx.l.togetherVs,
            style: text.titleMedium?.copyWith(color: t.gold, fontWeight: FontWeight.w700),
          ),
        ),
        player(profiles.two),
      ],
    );
  }
}
