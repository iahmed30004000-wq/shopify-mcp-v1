import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// «Are you the parent?»: a section (recording a story, adding or deleting a
/// picture) asks the shell to show the PIN / fingerprint gate as an overlay and
/// gets a plain yes or no. Unlike the exit gate it leaves kids mode exactly as
/// it was. The question is held here, not pushed as a route, so it always sits
/// above whatever the child is doing, in the shell's own frame.
class KidsParentCheck extends Notifier<Completer<bool>?> {
  @override
  Completer<bool>? build() => null;

  /// Opens the question (or joins the one already open) and waits for the answer.
  Future<bool> ask() {
    final open = state;
    if (open != null && !open.isCompleted) return open.future;
    final question = Completer<bool>();
    state = question;
    return question.future;
  }

  /// The parent passed (true) or went back (false).
  void answer({required bool passed}) {
    final open = state;
    if (open == null) return;
    state = null;
    if (!open.isCompleted) open.complete(passed);
  }
}

final kidsParentCheckProvider = NotifierProvider<KidsParentCheck, Completer<bool>?>(KidsParentCheck.new);
