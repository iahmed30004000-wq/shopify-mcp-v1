import '../core/rig.dart';
import 'placeholder_rig.dart';

// Rig agent entry point – the ONLY symbol the standard kit imports from
// engine/rig/. Swap the placeholder for the real rig here. Richer builders
// (bosses, custom silhouettes) may be exported from engine/rig/rig.dart for
// games to use directly; they still implement RigCharacter.

/// Builds the procedural rubber-hose character described by [spec].
RigCharacter createRig(RigSpec spec) => PlaceholderRig(spec);
