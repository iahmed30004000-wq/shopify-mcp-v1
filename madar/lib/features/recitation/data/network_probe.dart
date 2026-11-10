import 'dart:io';

/// Answers "is the phone on Wi-Fi?" for the Wi-Fi-only download option.
abstract class NetworkProbe {
  Future<bool> onWifi();
}

/// Heuristic without a plugin: Android names its Wi-Fi station interface
/// `wlan*` (mobile data uses `rmnet*` / `ccmni*` / `seth*`); an interface of
/// that name with an address means Wi-Fi is connected. When interfaces
/// cannot be listed at all it answers false (the safe side for Wi-Fi only).
///
/// A `ConnectivityManager.isActiveNetworkMetered` bridge would be exact; see
/// the recitation report for the optional Kotlin channel.
class InterfaceNetworkProbe implements NetworkProbe {
  const InterfaceNetworkProbe({this.list = _list});

  final Future<List<NetworkInterface>> Function() list;

  static Future<List<NetworkInterface>> _list() => NetworkInterface.list(includeLoopback: false);

  @override
  Future<bool> onWifi() async {
    try {
      final interfaces = await list();
      return interfaces.any((i) => isWifiName(i.name) && i.addresses.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  /// `wlan0`, `wlan1`, `wifi0`, `wl0` …; not the hotspot's `ap0` / `swlan0`.
  static bool isWifiName(String name) {
    final n = name.toLowerCase();
    return n.startsWith('wlan') || n.startsWith('wifi') || RegExp(r'^wl\d').hasMatch(n);
  }
}

/// Fixed answer (tests).
class FixedNetworkProbe implements NetworkProbe {
  FixedNetworkProbe({this.wifi = true});

  bool wifi;

  @override
  Future<bool> onWifi() async => wifi;
}
