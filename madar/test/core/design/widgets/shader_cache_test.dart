import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/shader_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preload succeeds when one program is loaded and the other still pending', () async {
    // The cosmos program is ready (load() now answers synchronously) while
    // the glass program has not started loading yet.
    final cosmos = await MadarShaders.load(MadarShaders.cosmosAsset);
    expect(cosmos, isNotNull, reason: 'the test needs a loaded program');
    expect(MadarShaders.glass.value, isNull);
    await expectLater(MadarShaders.preload(), completes);
    expect(MadarShaders.glass.value, isNotNull);
    // And again, with both loaded.
    await expectLater(MadarShaders.preload(), completes);
  });
}
