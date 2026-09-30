import '../core/rig.dart';
import 'toon_rig.dart';

// Rig agent entry point – the ONLY symbol the standard kit imports from
// engine/rig/. Richer builders (the cast, bosses, props) are exported from
// engine/rig/rig_kit.dart for games to use directly; they still implement
// RigCharacter.

/// Builds the procedural rubber-hose character described by [spec].
RigCharacter createRig(RigSpec spec) => ToonRig(spec);
