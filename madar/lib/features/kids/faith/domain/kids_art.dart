// The ONLY things a kids story or step may be illustrated with.
//
// The owner's rule: no prophet and no companion is ever drawn, not even as a
// silhouette. So the illustration widgets take a [KidsArt] and the enum below
// is a closed allow-list of places, light and objects: there is simply no
// value for a person, and a content file naming anything else fails to parse.
// A test pins the exact list, so adding a value is a visible, reviewed change.

/// A place, a light or an object. Never a person, a face or a figure.
enum KidsArt {
  dunes,
  palm,
  lantern,
  lightColumn,
  water,
  drops,
  stars,
  path,
  moon,
  sun,
  mountain,
  cave,
  tent,
  well,
  tree,
  sea,
  ship,
  rain,
  cloud,
  stone,
  khatam;

  /// The name used in content files (`"art": ["dunes", "palm"]`).
  static KidsArt? byName(String name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// The exact allow-list, written out so the ArtRule test compares the enum to
/// it. Keep in step with [KidsArt].
const Set<String> kidsArtAllowList = {
  'dunes', 'palm', 'lantern', 'lightColumn', 'water', 'drops', 'stars', 'path', 'moon', 'sun', 'mountain', //
  'cave', 'tent', 'well', 'tree', 'sea', 'ship', 'rain', 'cloud', 'stone', 'khatam',
};
