/// Deterministic, allocation-free noise for line boil.
///
/// Every drawing re-inks on [FilmClock.boilFrame]: jitter is a pure function
/// of (frame, seed, salt), so all characters and props on screen re-draw
/// together ("on twos") and a paused frame boils identically in tests.
library;

/// Hash of three ints → [-1, 1].
double boilNoise(int frame, int seed, int salt) {
  var h = (frame * 374761393 + seed * 668265263 + salt * 2246822519 + 0x9E3779B9) & 0x7fffffff;
  h = ((h ^ (h >> 15)) * 2246822519) & 0x7fffffff;
  h = ((h ^ (h >> 13)) * 3266489917) & 0x7fffffff;
  h ^= h >> 16;
  return (h & 0xffff) / 32767.5 - 1.0;
}

/// Hash → [0, 1).
double boilHash01(int frame, int seed, int salt) => (boilNoise(frame, seed, salt) + 1) * 0.4999;

/// A stable integer seed for a string id (FNV-1a).
int seedOf(String id) {
  var h = 0x811c9dc5;
  for (final c in id.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}
