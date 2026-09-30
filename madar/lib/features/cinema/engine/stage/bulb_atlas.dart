import 'dart:typed_data';
import 'dart:ui' as ui;

/// Marquee bulbs and their halos in two draw calls per frame.
///
/// One small sprite sheet is rendered once (a soft halo and a bulb with its
/// socket); every frame the stage [begin]s, [add]s each bulb with its
/// brightness, and [flush]es: all halos go down in one additive
/// `drawRawAtlas`, all bulbs in a second one, tinted per bulb with
/// `BlendMode.modulate`. The buffers are preallocated for [capacity] bulbs,
/// so steady state allocates nothing.
class BulbAtlas {
  BulbAtlas({this.capacity = 128})
    : _glowXf = Float32List(capacity * 4),
      _glowRect = Float32List(capacity * 4),
      _glowColor = Int32List(capacity),
      _bulbXf = Float32List(capacity * 4),
      _bulbRect = Float32List(capacity * 4),
      _bulbColor = Int32List(capacity);

  final int capacity;

  static const double _glowSize = 96;
  static const double _bulbSize = 48;

  ui.Image? _sprite;
  final Float32List _glowXf;
  final Float32List _glowRect;
  final Int32List _glowColor;
  final Float32List _bulbXf;
  final Float32List _bulbRect;
  final Int32List _bulbColor;
  int _n = 0;
  int _g = 0;
  int _bulbViewN = -1, _glowViewN = -1;
  Float32List? _bulbXfView, _bulbRectView, _glowXfView, _glowRectView;
  Int32List? _bulbColorView, _glowColorView;
  final ui.Paint _glowPaint = ui.Paint()..blendMode = ui.BlendMode.plus;
  final ui.Paint _bulbPaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  /// Whether the sprite sheet exists (it is made on the first [flush]).
  bool get isReady => _sprite != null;

  ui.Image _ensureSprite() {
    final existing = _sprite;
    if (existing != null) return existing;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    // Halo: a soft falloff (brighter core, long tail).
    const g = _glowSize / 2;
    c.drawCircle(
      const ui.Offset(g, g),
      g,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(g, g),
          g,
          const [ui.Color(0xFFFFFFFF), ui.Color(0x88FFFFFF), ui.Color(0x26FFFFFF), ui.Color(0x00FFFFFF)],
          const [0, 0.18, 0.5, 1],
        ),
    );
    // Bulb: dark socket ring, glass with a hot centre, a specular dot.
    const bx = _glowSize + _bulbSize / 2, by = _bulbSize / 2, r = _bulbSize / 2;
    c.drawCircle(const ui.Offset(bx, by), r, ui.Paint()..color = const ui.Color(0xFF2A2622));
    c.drawCircle(
      const ui.Offset(bx, by),
      r * 0.78,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(bx - r * 0.12, by - r * 0.12),
          r * 0.8,
          const [ui.Color(0xFFFFFFFF), ui.Color(0xFFF2F2F2), ui.Color(0xFFB8B8B8)],
          const [0, 0.55, 1],
        ),
    );
    c.drawCircle(const ui.Offset(bx - r * 0.3, by - r * 0.32), r * 0.16, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    final pic = rec.endRecording();
    final img = pic.toImageSync((_glowSize + _bulbSize).toInt(), _glowSize.toInt());
    pic.dispose();
    return _sprite = img;
  }

  /// Starts a new batch.
  void begin() {
    _n = 0;
    _g = 0;
  }

  /// Adds a bulb at [c] with core radius [radius]; [lit] 0..1 blends
  /// [off] → [on] and scales the halo ([haloRadius], tinted [halo]).
  void add(ui.Offset c, double radius, double lit, ui.Color on, ui.Color off, {ui.Color? halo, double? haloRadius}) {
    final l = lit.clamp(0.0, 1.0);
    if (_n < capacity) {
      final s = radius / (_bulbSize / 2);
      final i = _n * 4;
      _bulbXf[i] = s;
      _bulbXf[i + 1] = 0;
      _bulbXf[i + 2] = c.dx - s * _bulbSize / 2;
      _bulbXf[i + 3] = c.dy - s * _bulbSize / 2;
      _bulbRect[i] = _glowSize;
      _bulbRect[i + 1] = 0;
      _bulbRect[i + 2] = _glowSize + _bulbSize;
      _bulbRect[i + 3] = _bulbSize;
      _bulbColor[_n] = ui.Color.lerp(off, on, l)!.toARGB32();
      _n++;
    }
    if (l > 0.02) addHalo(c, haloRadius ?? radius * 4.2, (halo ?? on).withValues(alpha: 0.9 * l));
  }

  /// Adds only a halo (footlight wash, sconce, neon spark).
  void addHalo(ui.Offset c, double radius, ui.Color color) {
    if (_g >= capacity || color.a <= 0.004) return;
    final s = radius / (_glowSize / 2);
    final i = _g * 4;
    _glowXf[i] = s;
    _glowXf[i + 1] = 0;
    _glowXf[i + 2] = c.dx - s * _glowSize / 2;
    _glowXf[i + 3] = c.dy - s * _glowSize / 2;
    _glowRect[i] = 0;
    _glowRect[i + 1] = 0;
    _glowRect[i + 2] = _glowSize;
    _glowRect[i + 3] = _glowSize;
    _glowColor[_g] = color.toARGB32();
    _g++;
  }

  /// Draws the batch: halos (additive) under the bulbs.
  void flush(ui.Canvas canvas, {bool halosOnTop = false}) {
    if (_n == 0 && _g == 0) return;
    final sprite = _ensureSprite();
    if (!halosOnTop) _halos(canvas, sprite);
    if (_n > 0) {
      if (_n != _bulbViewN) {
        _bulbViewN = _n;
        _bulbXfView = Float32List.sublistView(_bulbXf, 0, _n * 4);
        _bulbRectView = Float32List.sublistView(_bulbRect, 0, _n * 4);
        _bulbColorView = Int32List.sublistView(_bulbColor, 0, _n);
      }
      canvas.drawRawAtlas(sprite, _bulbXfView!, _bulbRectView!, _bulbColorView, ui.BlendMode.modulate, null, _bulbPaint);
    }
    if (halosOnTop) _halos(canvas, sprite);
    _n = 0;
    _g = 0;
  }

  void _halos(ui.Canvas canvas, ui.Image sprite) {
    if (_g == 0) return;
    // Views are re-made only when the count changes (steady state: never).
    if (_g != _glowViewN) {
      _glowViewN = _g;
      _glowXfView = Float32List.sublistView(_glowXf, 0, _g * 4);
      _glowRectView = Float32List.sublistView(_glowRect, 0, _g * 4);
      _glowColorView = Int32List.sublistView(_glowColor, 0, _g);
    }
    canvas.drawRawAtlas(sprite, _glowXfView!, _glowRectView!, _glowColorView, ui.BlendMode.modulate, null, _glowPaint);
  }

  void dispose() {
    _sprite?.dispose();
    _sprite = null;
  }
}
