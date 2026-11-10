import 'package:flutter/material.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../engine/cinema_engine.dart';
import 'demo_game.dart';

/// Full-screen host of the engine demo ("Rehearsal") with an era switcher,
/// so each engine agent can see its piece in every era skin.
class CinemaDemoScreen extends StatefulWidget {
  const CinemaDemoScreen({
    super.key,
    this.initialEra = Era.rubberHose,
    this.autoplay = false,
    this.showEraPicker = true,
  });

  final Era initialEra;

  /// Attract mode: skips the opening and the hero jumps by itself.
  final bool autoplay;
  final bool showEraPicker;

  @override
  State<CinemaDemoScreen> createState() => _CinemaDemoScreenState();
}

class _CinemaDemoScreenState extends State<CinemaDemoScreen> {
  late Era _era = widget.initialEra;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: CinemaGameView(
              key: ValueKey(_era),
              skipOpening: widget.autoplay,
              builder: (ctx) => DemoGame(context: ctx, era: _era, autoplay: widget.autoplay),
            ),
          ),
          if (widget.showEraPicker)
            SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (final era in Era.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(era.label(l10n)),
                          selected: era == _era,
                          onSelected: (_) => setState(() => _era = era),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
