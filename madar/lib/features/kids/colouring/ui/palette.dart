// The colours a child paints with. From the approved palette plus a few
// friendly extras; there is deliberately no red.
import 'package:flutter/material.dart';

import '../../learn/ui/kids_tokens.dart';

const List<Color> kColouringColours = [
  KidsColors.rose500,
  KidsColors.sun500,
  KidsColors.teal500,
  KidsColors.night500,
  KidsColors.rose300,
  KidsColors.sun300,
  KidsColors.teal200,
  KidsColors.night300,
  Color(0xFF6FBF73), // leaf green
  Color(0xFF6EC1E4), // sky
  Color(0xFF9A6B3D), // earth
  KidsColors.night800,
];

/// ARGB int of a palette colour (what is stored on the device).
int argbOf(Color c) => c.toARGB32();
