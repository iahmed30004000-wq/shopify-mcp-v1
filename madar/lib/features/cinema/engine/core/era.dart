/// The film eras the Film Reel Engine can project. Every game belongs to one
/// era; its [EraSkin] (see `era_skins.dart`) decides palette, film grade,
/// ink, music style, stage dressing and title cards.
enum Era {
  /// 1920s silent pictures: sepia duotone, 18 fps projection, heavy flicker,
  /// ragtime piano, ornate intertitle cards.
  silent(1920),

  /// 1930s rubber-hose cartoons: inked black & white, halftone shading,
  /// 12 fps line boil, hot-jazz swing, art-deco titles.
  rubberHose(1930),

  /// 1940s film noir: hard contrast, crosshatched shadows, blinds, rain,
  /// muted-trumpet noir jazz.
  noir(1940),

  /// 1950s Technicolor: saturated three-strip colour, halation, big band.
  technicolor(1950),

  /// 1970s grindhouse: faded, scratched colour prints, missing reels, funk.
  grindhouse(1970),

  /// 1980s VHS: neon on black, scanlines, tracking noise, synthwave.
  vhs(1980);

  const Era(this.decade);

  /// First year of the decade (1920, 1930, …).
  final int decade;

  /// Monochrome film stock (the film grade maps luminance to ink → paper).
  bool get isMonochrome => this == silent || this == rubberHose || this == noir;
}
