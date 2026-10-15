import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts the notification taps that landed on the page already open.
///
/// `go` to the location the router is already on changes nothing, so a
/// tabbed page whose tab the user switched (Body › Fasting, then Water)
/// would stay on the other tab when "fasting goal reached" is tapped. The
/// notification router bumps this count in that case, and the tabbed route
/// pages key their screen on it: the screen opens afresh on the tab the
/// notification names.
final notificationLandingProvider = NotifierProvider<NotificationLanding, int>(NotificationLanding.new);

class NotificationLanding extends Notifier<int> {
  @override
  int build() => 0;

  /// A notification tap landed on the current location.
  void landed() => state++;
}
