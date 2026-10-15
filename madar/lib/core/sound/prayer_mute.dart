import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'sound_api.dart';

/// Shared, reference-counted prayer mute (additive to [SoundService]).
///
/// Several things may want game music and the ambient bed silent at once –
/// the adhan sounding, the adhan screen being open, the minutes of prayer
/// after an adhan, a prayer mode – and one of them ending must not unmute
/// the others. Each holder [acquire]s a lease and releases it; the service's
/// `setPrayerMute` is on while any lease is held. The prayer bus itself is
/// never muted (see `PrayerMutePolicy`).
class PrayerMuteController extends ChangeNotifier {
  PrayerMuteController(this._sound);

  final SoundService _sound;
  final Map<int, String> _leases = {};
  int _next = 0;
  bool _disposed = false;

  bool get muted => _leases.isNotEmpty;

  /// Why it is muted (for diagnostics).
  List<String> get reasons => List.unmodifiable(_leases.values);

  PrayerMuteLease acquire(String reason) {
    final id = _next++;
    _leases[id] = reason;
    _apply();
    return PrayerMuteLease._(this, id);
  }

  void _release(int id) {
    if (_leases.remove(id) != null) _apply();
  }

  void _apply() {
    // A holder may release its lease while the app scope is being torn
    // down, after this controller (e.g. the adhan's quiet guard).
    if (_disposed) return;
    _sound.setPrayerMute(muted);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Never leave the (longer-lived) sound service muted behind us.
    if (_leases.isNotEmpty) {
      _leases.clear();
      _sound.setPrayerMute(false);
    }
    super.dispose();
  }
}

/// A held prayer mute; [release] is idempotent.
class PrayerMuteLease {
  PrayerMuteLease._(this._owner, this._id);

  final PrayerMuteController _owner;
  final int _id;
  bool _released = false;

  bool get isActive => !_released;

  void release() {
    if (_released) return;
    _released = true;
    _owner._release(_id);
  }
}

/// The app-wide [PrayerMuteController].
final prayerMuteProvider = Provider<PrayerMuteController>((ref) {
  final controller = PrayerMuteController(ref.watch(soundServiceProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
