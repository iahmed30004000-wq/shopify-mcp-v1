/// The pairing sheet: two phones nearby (search, found, confirm the four
/// digits) or online (create a code with its QR, or type one), after "who is
/// playing on this phone".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/together_providers.dart';
import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../presentation/mode_picker.dart' show TogetherPrivacyNote, togetherModeIcon;
import '../presentation/together_texts.dart';
import '../presentation/widgets/together_visuals.dart';
import '../protocol/transport.dart';
import '../transport/nearby/nearby_transport.dart';
import '../transport/online/online_rooms.dart';
import '../transport/online/online_transport.dart';
import '../transport/paired_link.dart';
import '../transport/pairing_state.dart';
import '../transport/together_net_providers.dart';
import 'online_play_sheet.dart';
import 'pairing_texts.dart';
import 'pairing_visuals.dart';
import 'permission_rationale.dart';

/// Pairs this phone with the other one for [game] in [mode]
/// ([PlayMode.nearby] or [PlayMode.online]). The link, or null when the
/// sheet was dismissed (the transport is then closed: radios off, the online
/// room deleted).
Future<PairedLink?> showPairingSheet(
  BuildContext context, {
  required TogetherGameInfo game,
  required PlayMode mode,
  String? title,
}) => showInteractionSheet<PairedLink>(
  context,
  builder: (_) => PairingSheet(game: game, mode: mode, title: title),
);

enum _OnlineTab { create, join }

class PairingSheet extends ConsumerStatefulWidget {
  const PairingSheet({super.key, required this.game, required this.mode, this.title, this.onPaired});

  final TogetherGameInfo game;
  final PlayMode mode;

  /// The game's display name (default: the Together catalogue name).
  final String? title;

  /// Receives the link instead of the sheet popping with it (previews).
  final ValueChanged<PairedLink>? onPaired;

  /// How long "connected" shows before the sheet hands the link over.
  static const Duration handOverDelay = Duration(milliseconds: 900);

  /// When the "not showing up?" hint appears while searching.
  static const Duration hintDelay = Duration(seconds: 12);

  @override
  ConsumerState<PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends ConsumerState<PairingSheet> {
  PairableTransport? _transport;
  bool _unavailable = false;
  PlayerSlot? _slot;
  bool _handedOver = false;
  Timer? _handOverTimer;
  Timer? _hintTimer;
  bool _hint = false;
  _OnlineTab _tab = _OnlineTab.create;
  final TextEditingController _code = TextEditingController();
  bool _copied = false;
  PairingPhase? _lastPhase;

  // Watched in build and read by the phase builders (which run later, inside
  // the pairing's ValueListenableBuilder).
  TogetherProfiles _profiles = TogetherProfiles.defaults();
  PlayerSlot? _storedSlot;
  bool _onlineReadyValue = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    unawaited(_open());
  }

  Future<void> _open() async {
    final factory = ref.read(togetherTransportFactoriesProvider)[widget.mode];
    if (factory == null) {
      setState(() => _unavailable = true);
      return;
    }
    try {
      // The pairing decides which phone hosts; `host` is only a hint here.
      final t = await factory(TransportRequest(mode: widget.mode, host: true, gameId: widget.game.id));
      if (!mounted) {
        unawaited(t.close());
        return;
      }
      if (t is! PairableTransport) {
        unawaited(t.close());
        setState(() => _unavailable = true);
        return;
      }
      t.pairing.addListener(_onPairing);
      setState(() => _transport = t);
    } on Object catch (e) {
      debugPrint('Together pairing: $e');
      if (mounted) setState(() => _unavailable = true);
    }
  }

  @override
  void dispose() {
    _handOverTimer?.cancel();
    _hintTimer?.cancel();
    _transport?.pairing.removeListener(_onPairing);
    if (!_handedOver) unawaited(_transport?.close());
    _code.dispose();
    super.dispose();
  }

  void _onPairing() {
    final s = _transport?.pairing.value;
    if (s == null || !mounted) return;
    final phase = s.phase;
    if (phase != _lastPhase) {
      switch (phase) {
        case PairingPhase.connected:
          Fx.fire(Sfx.complete);
          _handOverTimer ??= Timer(PairingSheet.handOverDelay, _handOver);
        case PairingPhase.confirm:
          Fx.fire(Sfx.notify);
        case PairingPhase.failed || PairingPhase.lost:
          Fx.fire(Sfx.error);
        case PairingPhase.reconnecting:
          Fx.fire(Sfx.notify, haptic: Haptic.warning);
        default:
          break;
      }
      if (phase == PairingPhase.searching) {
        _hintTimer?.cancel();
        _hint = false;
        _hintTimer = Timer(PairingSheet.hintDelay, () {
          if (mounted) setState(() => _hint = true);
        });
      } else if (phase != PairingPhase.connecting) {
        _hintTimer?.cancel();
      }
      _lastPhase = phase;
    }
  }

  PairingIdentity _identity() {
    final p = _profiles.of(_currentSlot());
    return PairingIdentity.of(p, displayName: TogetherTexts.of(context).rawName(p));
  }

  PlayerSlot _currentSlot() => _slot ?? _storedSlot ?? PlayerSlot.one;

  void _pickSlot(PlayerSlot slot) {
    setState(() => _slot = slot);
    unawaited(ref.read(togetherDeviceStoreProvider).save(slot));
  }

  void _handOver() {
    final t = _transport;
    if (t == null || !mounted || _handedOver) return;
    if (!t.pairing.value.isConnected || t.role == null || t.peer == null) {
      _handOverTimer = null;
      return;
    }
    _handedOver = true;
    final link = PairedLink(transport: t, identity: _identity());
    final cb = widget.onPaired;
    if (cb != null) {
      cb(link);
    } else {
      Navigator.of(context).pop(link);
    }
  }

  void _close() => Navigator.of(context).maybePop();

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final tx = TogetherTexts.of(context);
    final t = _transport;
    _profiles = ref.watch(togetherProfilesProvider).value ?? TogetherProfiles.defaults();
    _storedSlot = ref.watch(togetherDeviceSlotProvider).value;
    final settings = ref.watch(togetherSettingsProvider).value ?? const TogetherSettings();
    _onlineReadyValue = settings.onlineEnabled && ref.watch(onlineConfigProvider).value != null;
    return InteractionSheetFrame(
      title: tx.mode(widget.mode),
      subtitle: widget.title ?? tx.game(widget.game.id),
      icon: togetherModeIcon(widget.mode),
      body: t == null
          ? _Loading(unavailable: _unavailable)
          : ValueListenableBuilder<PairingState>(
              valueListenable: t.pairing,
              builder: (context, s, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WhoIsHere(
                    slot: _currentSlot(),
                    // Announced once the search / the code starts: fixed from then on.
                    locked: !_identityOpen(s),
                    onPick: _pickSlot,
                  ),
                  const SizedBox(height: Space.l),
                  // Fade-through: the old stage is gone before the new one
                  // appears (they differ in height and must never overlap).
                  AnimatedSwitcher(
                    duration: context.motion(MadarMotion.medium),
                    switchInCurve: const Interval(0.45, 1, curve: MadarMotion.decelerate),
                    switchOutCurve: const Interval(0.55, 1, curve: Curves.easeIn),
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('${s.phase.name}-${_tab.name}-${s.found.length > 1}'),
                      child: switch (t) {
                        NearbyTransport() => _nearbyBody(t, s),
                        OnlineTransport() => _onlineBody(t, s),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  const TogetherPrivacyNote(),
                ],
              ),
            ),
      footer: t == null
          ? SheetButton(label: PairingTexts.of(context).l.togetherNetCancel, onPressed: _close, sfx: Sfx.sheetClose)
          : ValueListenableBuilder<PairingState>(
              valueListenable: t.pairing,
              builder: (context, s, _) =>
                  switch (t) {
                    NearbyTransport() => _nearbyFooter(t, s),
                    OnlineTransport() => _onlineFooter(t, s),
                    _ => null,
                  } ??
                  const SizedBox.shrink(),
            ),
    );
  }

  bool _identityOpen(PairingState s) =>
      s.role == null &&
      (s.phase == PairingPhase.idle || s.phase == PairingPhase.needsSetup || s.phase == PairingPhase.closed);

  Widget _avatarOfMe({double size = 56}) {
    final p = _profiles.of(_currentSlot());
    return TogetherAvatarView(profile: p, displayName: TogetherTexts.of(context).rawName(p), size: size, glow: true);
  }

  // ---------------------------------------------------------------- nearby

  Widget _nearbyBody(NearbyTransport t, PairingState s) {
    final px = PairingTexts.of(context);
    final l = px.l;
    final peerName = px.name(s.peer?.name ?? '');
    switch (s.phase) {
      case PairingPhase.needsPermission || PairingPhase.permissionDenied || PairingPhase.serviceOff:
        return NearbyPermissionPanel(state: s);
      case PairingPhase.confirm || PairingPhase.waitingForPeer:
        final token = s.token ?? '----';
        final waiting = s.phase == PairingPhase.waitingForPeer;
        return _Stage(
          visual: AnimatedOpacity(
            duration: context.motion(MadarMotion.short),
            opacity: waiting ? 0.6 : 1,
            child: DigitTiles(
              key: const ValueKey('together-pair-token'),
              digits: token,
              localized: px.digits(token),
              semanticLabel: l.togetherNetDigits(px.digits(token)),
            ),
          ),
          title: waiting ? l.togetherNetWaitingFor(peerName) : l.togetherNetConfirmTitle,
          body: waiting ? null : l.togetherNetConfirmBody(peerName),
          busy: waiting,
        );
      case PairingPhase.connected:
        return _Stage(visual: const PairedMark(), title: l.togetherNetConnected(peerName));
      case PairingPhase.lost:
        return _Stage(
          visual: _IconDisc(icon: Icons.portable_wifi_off_rounded, tone: context.tokens.warning),
          title: l.togetherNetLost(peerName),
          body: l.togetherNetLostHint,
        );
      case PairingPhase.failed:
        return _Stage(
          visual: _IconDisc(icon: Icons.bluetooth_disabled_rounded, tone: context.tokens.warning),
          title: px.failure(s.failure ?? PairingFailure.unknown),
        );
      case PairingPhase.idle || PairingPhase.closed:
        return _Stage(
          visual: PairingRadar(active: false, center: _avatarOfMe()),
          body: l.togetherNetNearbyIntro,
        );
      case PairingPhase.searching || PairingPhase.connecting || PairingPhase.reconnecting:
        final title = switch (s.phase) {
          PairingPhase.connecting => l.togetherNetConnecting(peerName),
          PairingPhase.reconnecting => l.togetherNetReconnecting(peerName),
          _ => s.found.length > 1 ? l.togetherNetPickPhone : l.togetherNetSearching,
        };
        final found = s.phase == PairingPhase.connecting && s.peer != null ? [s.peer!] : s.found;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stage(
              visual: PairingRadar(active: !s.paused, found: found, center: _avatarOfMe()),
              title: title,
              body: s.paused
                  ? l.togetherNetPaused
                  : (_hint && s.phase == PairingPhase.searching ? l.togetherNetSearchingHint : null),
            ),
            if (s.phase == PairingPhase.searching && s.found.length > 1) ...[
              const SizedBox(height: Space.m),
              for (final p in s.found)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: _FoundPhone(peer: p, onConnect: () => t.connectTo(p.id)),
                ),
            ],
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _nearbyFooter(NearbyTransport t, PairingState s) {
    final l = PairingTexts.of(context).l;
    Widget cancel() => SheetButton(label: l.togetherNetCancel, onPressed: _close, sfx: Sfx.sheetClose);
    switch (s.phase) {
      case PairingPhase.idle:
        return SheetButton(
          key: const ValueKey('together-pair-play'),
          label: l.togetherNetPlayTogether,
          icon: Icons.bluetooth_searching_rounded,
          primary: true,
          sfx: Sfx.navigate,
          onPressed: () => unawaited(t.playTogether(_identity())),
        );
      case PairingPhase.needsPermission:
        return _TwoButtons(
          secondary: SheetButton(label: l.togetherNetNotNow, onPressed: _close, sfx: Sfx.sheetClose),
          primary: SheetButton(
            key: const ValueKey('together-pair-allow'),
            label: l.togetherNetContinue,
            primary: true,
            onPressed: () => unawaited(t.grantPermissions()),
          ),
        );
      case PairingPhase.permissionDenied:
        return _TwoButtons(
          secondary: s.permanentlyDenied
              ? SheetButton(label: l.togetherNetTryAgain, onPressed: () => unawaited(t.searchAgain()))
              : SheetButton(label: l.togetherNetNotNow, onPressed: _close, sfx: Sfx.sheetClose),
          primary: s.permanentlyDenied
              ? SheetButton(
                  key: const ValueKey('together-pair-settings'),
                  label: l.togetherNetOpenSettings,
                  icon: Icons.settings_rounded,
                  primary: true,
                  onPressed: () => unawaited(t.openSettings()),
                )
              : SheetButton(
                  key: const ValueKey('together-pair-allow'),
                  label: l.togetherNetTryAgain,
                  primary: true,
                  onPressed: () => unawaited(t.grantPermissions()),
                ),
        );
      case PairingPhase.serviceOff:
        return _TwoButtons(
          secondary: SheetButton(label: l.togetherNetSearchAnyway, onPressed: () => unawaited(t.searchAnyway())),
          primary: SheetButton(
            label: l.togetherNetOpenSettings,
            icon: Icons.settings_rounded,
            primary: true,
            onPressed: () => unawaited(t.openSettings()),
          ),
        );
      case PairingPhase.confirm:
        return _TwoButtons(
          secondary: SheetButton(
            key: const ValueKey('together-pair-nomatch'),
            label: l.togetherNetNoMatch,
            tone: context.tokens.danger,
            sfx: Sfx.back,
            onPressed: () => unawaited(t.declineToken()),
          ),
          primary: SheetButton(
            key: const ValueKey('together-pair-match'),
            label: l.togetherNetMatch,
            icon: Icons.check_rounded,
            primary: true,
            sfx: Sfx.toggleOn,
            onPressed: () => unawaited(t.confirmToken()),
          ),
        );
      case PairingPhase.lost || PairingPhase.failed:
        return _TwoButtons(
          secondary: cancel(),
          primary: SheetButton(
            key: const ValueKey('together-pair-again'),
            label: l.togetherNetSearchAgain,
            icon: Icons.refresh_rounded,
            primary: true,
            sfx: Sfx.navigate,
            onPressed: () => unawaited(t.searchAgain()),
          ),
        );
      case PairingPhase.connected:
        return null;
      default:
        return cancel();
    }
  }

  // ---------------------------------------------------------------- online

  bool _onlineReady() => _onlineReadyValue;

  Widget _onlineBody(OnlineTransport t, PairingState s) {
    final px = PairingTexts.of(context);
    final l = px.l;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final peerName = px.name(s.peer?.name ?? '');
    if (s.phase == PairingPhase.needsSetup || (s.phase == PairingPhase.idle && !_onlineReady())) {
      return _Stage(
        visual: _IconDisc(icon: Icons.cloud_off_rounded, tone: tokens.gold),
        title: l.togetherNetNeedsSetup,
        body: l.togetherNetNeedsSetupBody,
      );
    }
    switch (s.phase) {
      case PairingPhase.idle || PairingPhase.closed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChoicePills<_OnlineTab>.single(
              options: [
                ChoiceOption(value: _OnlineTab.create, label: l.togetherNetCreateCode, icon: Icons.qr_code_2_rounded),
                ChoiceOption(value: _OnlineTab.join, label: l.togetherNetEnterCode, icon: Icons.dialpad_rounded),
              ],
              selected: _tab,
              onChanged: (v) {
                if (v != null) setState(() => _tab = v);
              },
            ),
            const SizedBox(height: Space.l),
            if (_tab == _OnlineTab.create)
              _Stage(
                visual: PairingRadar(active: false, center: _avatarOfMe(), size: 150),
                body: l.togetherNetOnlineIntro,
              )
            else
              _CodeField(controller: _code, onSubmit: () => _join(t)),
          ],
        );
      case PairingPhase.signingIn || PairingPhase.joining:
        return _Stage(
          visual: const OrbitLoader(size: 56),
          title: s.phase == PairingPhase.joining ? l.togetherNetJoining : l.togetherNetSigningIn,
        );
      case PairingPhase.hosting:
        final code = s.code ?? '';
        final expires = s.expiresAt;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.togetherNetYourCode,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: Space.s),
            DigitTiles(
              key: const ValueKey('together-pair-code'),
              digits: code,
              localized: px.digits(code),
              semanticLabel: '${l.togetherNetYourCode} ${px.digits(OnlineRooms.displayCode(code))}',
              groupAfter: 3,
              tileWidth: 40,
            ),
            const SizedBox(height: Space.m),
            Center(
              child: TogetherQrView(data: code, semanticLabel: l.togetherNetQrLabel(px.digits(code))),
            ),
            const SizedBox(height: Space.m),
            Text(
              l.togetherNetCodeHint,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            if (expires != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                l.togetherNetCodeValid(px.fmt.formatTime(expires.toLocal())),
                textAlign: TextAlign.center,
                style: text.labelMedium?.copyWith(color: tokens.gold),
              ),
            ],
            const SizedBox(height: Space.s),
            Center(
              child: MadarButton(
                key: const ValueKey('together-pair-copy'),
                label: _copied ? l.togetherNetCopied : l.togetherNetCopyCode,
                icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) setState(() => _copied = true);
                },
              ),
            ),
            const SizedBox(height: Space.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const OrbitLoader(size: 20),
                const SizedBox(width: Space.s),
                Flexible(
                  child: Text(l.togetherNetWaitingJoin, style: text.bodySmall?.copyWith(color: tokens.textSecondary)),
                ),
              ],
            ),
          ],
        );
      case PairingPhase.confirm || PairingPhase.waitingForPeer:
        final peer = s.peer;
        final host = s.phase == PairingPhase.confirm;
        return _Stage(
          visual: peer == null
              ? const OrbitLoader(size: 56)
              : TogetherAvatarView(profile: peerProfile(peer), displayName: peer.name, size: 76, glow: true),
          title: host ? l.togetherNetJoinRequest(peerName) : l.togetherNetWaitingAccept(peerName),
          body: host ? l.togetherNetJoinRequestBody : null,
          busy: !host,
        );
      case PairingPhase.connected:
        return _Stage(visual: const PairedMark(), title: l.togetherNetConnected(peerName));
      case PairingPhase.failed:
        return _Stage(
          visual: _IconDisc(icon: Icons.cloud_off_rounded, tone: tokens.warning),
          title: px.failure(s.failure ?? PairingFailure.unknown),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _join(OnlineTransport t) {
    final code = OnlineRooms.normalizeCode(_code.text);
    if (!OnlineRooms.isValidCode(code)) {
      Fx.fire(Sfx.error);
      return;
    }
    FocusScope.of(context).unfocus();
    unawaited(t.join(code, _identity()));
  }

  Future<void> _setUp(OnlineTransport t) async {
    await showOnlinePlaySheet(context);
    if (!mounted) return;
    ref.invalidate(onlineConfigProvider);
    await t.reset();
  }

  Widget? _onlineFooter(OnlineTransport t, PairingState s) {
    final l = PairingTexts.of(context).l;
    Widget cancel() => SheetButton(label: l.togetherNetCancel, onPressed: _close, sfx: Sfx.sheetClose);
    final setUp = SheetButton(
      key: const ValueKey('together-pair-setup'),
      label: l.togetherNetSetUp,
      icon: Icons.settings_rounded,
      primary: true,
      onPressed: () => unawaited(_setUp(t)),
    );
    if (s.phase == PairingPhase.needsSetup || (s.phase == PairingPhase.idle && !_onlineReady())) return setUp;
    switch (s.phase) {
      case PairingPhase.idle:
        if (_tab == _OnlineTab.create) {
          return SheetButton(
            key: const ValueKey('together-pair-create'),
            label: l.togetherNetCreateCode,
            icon: Icons.qr_code_2_rounded,
            primary: true,
            sfx: Sfx.navigate,
            onPressed: () => unawaited(t.host(_identity())),
          );
        }
        final valid = OnlineRooms.isValidCode(OnlineRooms.normalizeCode(_code.text));
        return SheetButton(
          key: const ValueKey('together-pair-join'),
          label: l.togetherNetJoin,
          icon: Icons.login_rounded,
          primary: true,
          enabled: valid,
          sfx: Sfx.navigate,
          onDisabledTap: () => Fx.fire(Sfx.error),
          onPressed: () => _join(t),
        );
      case PairingPhase.confirm:
        return _TwoButtons(
          secondary: SheetButton(
            key: const ValueKey('together-pair-decline'),
            label: l.togetherNetDecline,
            tone: context.tokens.danger,
            sfx: Sfx.back,
            onPressed: () => unawaited(t.declineGuest()),
          ),
          primary: SheetButton(
            key: const ValueKey('together-pair-accept'),
            label: l.togetherNetAccept,
            icon: Icons.play_arrow_rounded,
            primary: true,
            sfx: Sfx.toggleOn,
            onPressed: () => unawaited(t.acceptGuest()),
          ),
        );
      case PairingPhase.failed:
        final setupProblem = switch (s.failure) {
          PairingFailure.setup || PairingFailure.signIn || PairingFailure.rules => true,
          _ => false,
        };
        return _TwoButtons(
          secondary: cancel(),
          primary: setupProblem
              ? setUp
              : SheetButton(
                  key: const ValueKey('together-pair-again'),
                  label: l.togetherNetTryAgain,
                  icon: Icons.refresh_rounded,
                  primary: true,
                  onPressed: () => unawaited(t.reset()),
                ),
        );
      case PairingPhase.connected:
        return null;
      default:
        return cancel();
    }
  }
}

// ------------------------------------------------------------------ pieces

class _Loading extends StatelessWidget {
  const _Loading({required this.unavailable});

  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final l = PairingTexts.of(context).l;
    return _Stage(
      visual: unavailable
          ? _IconDisc(icon: Icons.portable_wifi_off_rounded, tone: context.tokens.warning)
          : const OrbitLoader(size: 48),
      title: unavailable ? l.togetherNetFailUnknown : null,
    );
  }
}

/// A picture, a title and a line of text, centred.
class _Stage extends StatelessWidget {
  const _Stage({required this.visual, this.title, this.body, this.busy = false});

  final Widget visual;
  final String? title;
  final String? body;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: visual),
        if (title != null) ...[
          const SizedBox(height: Space.l),
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy) ...[const OrbitLoader(size: 18), const SizedBox(width: Space.s)],
                Flexible(
                  child: Text(title!, textAlign: TextAlign.center, style: text.titleMedium),
                ),
              ],
            ),
          ),
        ],
        if (body != null) ...[
          const SizedBox(height: Space.s),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45),
          ),
        ],
      ],
    );
  }
}

class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    height: 76,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [tone.withValues(alpha: 0.3), tone.withValues(alpha: 0.04)]),
      border: Border.all(color: tone.withValues(alpha: 0.7), width: 1.2),
    ),
    child: Icon(icon, size: 36, color: tone),
  );
}

class _TwoButtons extends StatelessWidget {
  const _TwoButtons({required this.secondary, required this.primary});

  final Widget secondary;
  final Widget primary;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: secondary),
      const SizedBox(width: Space.m),
      Expanded(child: primary),
    ],
  );
}

/// "On this phone": which of the two players this phone belongs to.
class _WhoIsHere extends ConsumerWidget {
  const _WhoIsHere({required this.slot, required this.locked, required this.onPick});

  final PlayerSlot slot;
  final bool locked;
  final ValueChanged<PlayerSlot> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = TogetherTexts.of(context);
    final l = PairingTexts.of(context).l;
    final profiles = ref.watch(togetherProfilesProvider).value ?? TogetherProfiles.defaults();
    Widget chip(TogetherProfile p) {
      final on = p.slot == slot;
      final color = TogetherLook.colorOf(p);
      return Expanded(
        child: MadarPressable(
          key: ValueKey('together-pair-me-${p.slot.name}'),
          onTap: locked || on ? null : () => onPick(p.slot),
          selected: on,
          semanticLabel: l.togetherNetThisIsMe(tx.name(p)),
          excludeChildSemantics: true,
          focusRadius: BorderRadius.circular(t.radiusL),
          child: AnimatedContainer(
            duration: context.motion(MadarMotion.short),
            padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.m, Space.s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusL),
              color: on ? Color.alphaBlend(color.withValues(alpha: 0.18), t.glassFill) : t.glassFill,
              border: Border.all(color: on ? color : t.glassBorder, width: on ? 1.5 : 0.9),
            ),
            child: Opacity(
              opacity: on || !locked ? 1 : 0.5,
              child: Row(
                children: [
                  TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 34, dim: !on),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      tx.rawName(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: on ? t.textPrimary : t.textSecondary),
                    ),
                  ),
                  if (on) Icon(Icons.phone_android_rounded, size: 18, color: color),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.togetherNetOnThisPhone, style: text.titleSmall?.copyWith(color: t.textSecondary)),
        const SizedBox(height: Space.s),
        Row(
          children: [
            chip(profiles.one),
            const SizedBox(width: Space.s),
            chip(profiles.two),
          ],
        ),
      ],
    );
  }
}

class _FoundPhone extends StatelessWidget {
  const _FoundPhone({required this.peer, required this.onConnect});

  final PairingPeer peer;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = PairingTexts.of(context).l;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.s, Space.s),
      child: Row(
        children: [
          Icon(Icons.phone_android_rounded, color: t.accent),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(peer.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          MadarButton(
            key: ValueKey('together-pair-found-${peer.id}'),
            label: l.togetherNetConnect,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.secondary,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }
}

/// The six-digit code, typed (Arabic-Indic digits welcome), left to right.
class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = PairingTexts.of(context).l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.togetherNetOnlineIntro,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: Space.l),
        Text(l.togetherNetCodeField, style: text.titleSmall?.copyWith(color: t.textSecondary)),
        const SizedBox(height: Space.s),
        TextField(
          key: const ValueKey('together-pair-code-field'),
          controller: controller,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.number,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 7,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹ ]'))],
          style: text.headlineMedium?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w600),
          decoration: kitInputDecoration(context, hint: '000000'),
          onSubmitted: (_) => onSubmit(),
        ),
      ],
    );
  }
}
