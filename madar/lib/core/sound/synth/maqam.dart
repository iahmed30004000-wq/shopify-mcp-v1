import 'dart:math' as math;

/// Arabic maqamat used to colour Madar's sounds.
///
/// Each maqam is expressed as the cents of its seven degrees above the tonic
/// (the ascending form). Quarter-tone degrees (Rast's and Bayati's neutral
/// intervals) are what make these sound Arabic rather than Western – they
/// are used sparingly, as passing colour, never as a gimmick.
enum Maqam {
  /// Rast on C: C D E𝄳 F G A B𝄳 – noble, bright; neutral 3rd and 7th.
  rast([0, 200, 350, 500, 700, 900, 1050]),

  /// Bayati on D: D E𝄳 F G A B♭ C – warm, intimate; neutral 2nd.
  bayati([0, 150, 300, 500, 700, 800, 1000]),

  /// Hijaz on D: D E♭ F♯ G A B♭ C – the desert's augmented second.
  hijaz([0, 110, 390, 500, 700, 800, 1000]),

  /// Nahawand on C: C D E♭ F G A♭ B – graceful minor with a leading tone.
  nahawand([0, 200, 300, 500, 700, 800, 1100]),

  /// 'Ajam on B♭: the Arabic major – open and airy.
  ajam([0, 200, 400, 500, 700, 900, 1100]),

  /// Kurd on D: D E♭ F G A B♭ C – dark and soft.
  kurd([0, 100, 300, 500, 700, 800, 1000]);

  const Maqam(this.cents);

  /// Cents of degrees 0..6 above the tonic.
  final List<int> cents;

  /// Cents of any [degree] (negative or ≥ 7 wrap into lower/higher octaves).
  int centsOf(int degree) {
    final octave = (degree / 7).floor();
    final d = degree - octave * 7;
    return cents[d] + 1200 * octave;
  }

  /// Frequency (Hz) of [degree] above [tonicHz], optionally shifted by
  /// [octave]s and [detuneCents].
  double hz(double tonicHz, int degree, {int octave = 0, double detuneCents = 0}) =>
      tonicHz * math.pow(2.0, (centsOf(degree) + 1200 * octave + detuneCents) / 1200.0);
}

/// Equal-tempered frequency of a MIDI note number (A4 = 69 = 440 Hz).
double midiHz(num note) => 440.0 * math.pow(2.0, (note - 69) / 12.0);
