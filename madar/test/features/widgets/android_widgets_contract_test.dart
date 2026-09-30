// The Android half of the home-screen widgets is built only in CI (no
// Android SDK on the development machine): these checks keep the Kotlin,
// the resources, the manifest and the Dart side in step without it.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/widgets/widgets.dart';

const _main = 'android/app/src/main';
const _res = '$_main/res';
const _kotlinDir = '$_main/kotlin/app/madar/orbit/widgets';

String _read(String path) => File(path).readAsStringSync();

String get _kotlin =>
    Directory(_kotlinDir).listSync().whereType<File>().where((f) => f.path.endsWith('.kt')).map((f) => f.readAsStringSync()).join('\n');

/// Every resource name of [type] defined under res/ (files and values).
Set<String> _defined(String type) {
  final out = <String>{};
  for (final dir in Directory(_res).listSync().whereType<Directory>()) {
    final base = dir.uri.pathSegments.where((s) => s.isNotEmpty).last.split('-').first;
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last.split('.').first;
      if (base == type) out.add(name);
      if (!f.path.endsWith('.xml')) continue;
      final text = f.readAsStringSync();
      if (base == 'values') {
        for (final m in RegExp('<$type name="([\\w.]+)"').allMatches(text)) {
          out.add(m.group(1)!);
        }
      }
      if (type == 'id') {
        for (final m in RegExp(r'@\+id/(\w+)').allMatches(text)) {
          out.add(m.group(1)!);
        }
      }
    }
  }
  return out;
}

Iterable<File> get _widgetXml => Directory(_res)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.uri.pathSegments.last.startsWith('widget_') && f.path.endsWith('.xml'));

void main() {
  test('Kotlin uses only resources that exist', () {
    final kotlin = _kotlin;
    for (final type in ['id', 'layout', 'string', 'drawable', 'color', 'style', 'xml']) {
      final defined = _defined(type);
      for (final m in RegExp('(?<!android\\.)R\\.$type\\.(\\w+)').allMatches(kotlin)) {
        expect(defined, contains(m.group(1)), reason: 'R.$type.${m.group(1)}');
      }
    }
  });

  test('widget XML is well-formed enough and every reference resolves', () {
    for (final f in _widgetXml) {
      final text = f.readAsStringSync();
      expect(text.trimLeft(), startsWith('<?xml'), reason: f.path);
      for (final m in RegExp(r'"@(?!android:)(?!\+)(\w+)/([\w.]+)"').allMatches(text)) {
        final type = m.group(1)!;
        if (type == 'null') continue;
        expect(_defined(type), contains(m.group(2)), reason: '${f.path}: @$type/${m.group(2)}');
      }
      if (f.path.contains('/layout/')) {
        // RemoteViews inflate only a fixed set of framework views.
        const allowed = {'FrameLayout', 'LinearLayout', 'TextView', 'ImageView', 'ProgressBar', 'Chronometer'};
        for (final m in RegExp(r'<([A-Za-z.]+)[\s>]').allMatches(text)) {
          expect(allowed, contains(m.group(1)), reason: '${f.path}: <${m.group(1)}>');
        }
      }
    }
  });

  test('Arabic strings match the default ones', () {
    Set<String> names(String path) => {for (final m in RegExp(r'<string name="(\w+)"').allMatches(_read(path))) m.group(1)!};
    expect(names('$_res/values-ar/widget_strings.xml'), names('$_res/values/widget_strings.xml'));
    Set<String> colors(String path) => {for (final m in RegExp(r'<color name="(\w+)"').allMatches(_read(path))) m.group(1)!};
    expect(colors('$_res/values-night/widget_colors.xml'), colors('$_res/values/widget_colors.xml'));
  });

  group('colours', () {
    Map<String, Color> xmlColors(String path) => {
      for (final m in RegExp(r'<color name="(\w+)">#([0-9A-Fa-f]{8})</color>').allMatches(_read(path)))
        m.group(1)!: Color(int.parse(m.group(2)!, radix: 16)),
    };
    final light = xmlColors('$_res/values/widget_colors.xml');
    final dark = xmlColors('$_res/values-night/widget_colors.xml');

    test('the settings preview uses exactly the home screen\'s colours', () {
      for (final (xml, preview) in [(light, WidgetPreviewColors.light), (dark, WidgetPreviewColors.dark)]) {
        expect(xml, hasLength(9));
        expect(preview.surface, xml['widget_surface']);
        expect(preview.stroke, xml['widget_stroke']);
        expect(preview.primary, xml['widget_text_primary']);
        expect(preview.secondary, xml['widget_text_secondary']);
        expect(preview.muted, xml['widget_text_muted']);
        expect(preview.accent, xml['widget_accent']);
        expect(preview.warn, xml['widget_warn']);
        expect(preview.track, xml['widget_bar_track']);
        expect(preview.fill, xml['widget_bar_fill']);
      }
    });

    test('text is readable in light and dark (WCAG AA, 4.5:1; the bar 3:1)', () {
      /// [fg] (maybe translucent) over the opaque [bg].
      double contrast(Color fg, Color bg) {
        final a = Color.alphaBlend(fg, bg).computeLuminance();
        final b = bg.computeLuminance();
        return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
      }

      for (final (name, c) in [('light', light), ('dark', dark)]) {
        // The card is nearly opaque: judged on the card's own colour.
        final surface = c['widget_surface']!.withValues(alpha: 1);
        for (final text in ['widget_text_primary', 'widget_text_secondary', 'widget_text_muted', 'widget_accent', 'widget_warn']) {
          expect(contrast(c[text]!, surface), greaterThanOrEqualTo(4.5), reason: '$name $text');
        }
        expect(contrast(c['widget_bar_fill']!, surface), greaterThanOrEqualTo(3), reason: '$name bar');
      }
    });
  });

  test('the manifest declares the four providers, private, home screen only', () {
    final manifest = _read('$_main/AndroidManifest.xml');
    for (final (cls, kind) in [
      ('PrayerWidgetProvider', 'prayer'),
      ('MedsWidgetProvider', 'meds'),
      ('TasksWidgetProvider', 'tasks'),
      ('BudgetWidgetProvider', 'budget'),
    ]) {
      final block = RegExp('<receiver[^>]*\\.widgets\\.$cls"[\\s\\S]*?</receiver>').firstMatch(manifest)?.group(0);
      expect(block, isNotNull, reason: cls);
      expect(block, contains('android:exported="false"'));
      expect(block, contains('android.appwidget.action.APPWIDGET_UPDATE'));
      expect(block, contains('@xml/widget_info_$kind'));
      expect(_kotlin, contains('class $cls : MadarWidgetProvider()'));
      final info = _read('$_res/xml/widget_info_$kind.xml');
      expect(info, contains('android:widgetCategory="home_screen"'));
      expect(info, isNot(contains('keyguard')), reason: 'never on the lock screen');
      expect(info, contains('android:previewLayout="@layout/widget_preview_'));
      // Android 8–11 pickers show previewImage (previewLayout is 12+) at its
      // own size: a widget-sized picture, never the 24 dp mark.
      final image = RegExp(r'android:previewImage="@drawable/(\w+)"').firstMatch(info)!.group(1)!;
      expect(image, isNot('widget_mark'), reason: kind);
      final vector = _read('$_res/drawable/$image.xml');
      final width = double.parse(RegExp(r'android:width="([\d.]+)dp"').firstMatch(vector)!.group(1)!);
      expect(width, greaterThanOrEqualTo(96), reason: '$kind preview width');
      expect(info, contains('android:updatePeriodMillis='));
    }
  });

  test('both sides agree on the channel, the kinds and the snapshot keys', () {
    final kotlin = _kotlin;
    expect(kotlin, contains('const val CHANNEL = "${MethodChannelWidgetPlatform.channelName}"'));
    for (final k in MadarWidgetKind.values) {
      expect(kotlin, contains('${k.name.toUpperCase()}("${k.wire}"'), reason: k.wire);
    }
    // Every key Kotlin reads is one Dart writes.
    final full = WidgetSnapshot(
      kind: MadarWidgetKind.meds,
      languageCode: 'ar',
      private: false,
      title: 't',
      until: DateTime(2026, 10, 2),
      stale: 's',
      link: '/meds',
      pages: [
        WidgetPage(
          from: DateTime(2026, 10, 1),
          headline: 'h',
          detail: 'd',
          note: 'n',
          countdownTo: DateTime(2026, 10, 1, 5),
          countdownFormat: '%s',
          image: 'astro_fajr',
          rows: const [WidgetRow(text: 'r', time: '1', state: WidgetRowState.skipped, link: '/meds')],
          more: const ['+1'],
          empty: 'e',
          bar: 5,
          warn: true,
          link: '/meds',
        ),
      ],
    ).encode();
    final read = RegExp(r'opt(?:String|Long|Int|Boolean|JSONArray|JSONObject|Text)\((?:\w+, )?"(\w+)"').allMatches(kotlin);
    final keys = {for (final m in read) m.group(1)!}..addAll(RegExp(r'\w+\.has\("(\w+)"\)').allMatches(kotlin).map((m) => m.group(1)!));
    expect(keys, containsAll(['v', 'rtl', 'private', 'title', 'stale', 'until', 'pages', 'big', 'sub', 'rows', 'st']));
    for (final k in keys) {
      expect(full, contains('"$k":'), reason: 'Kotlin reads "$k"');
    }
    // Row states and the image naming.
    for (final s in WidgetRowState.values) {
      expect(kotlin, contains('"${s.wire}"'), reason: s.name);
    }
    expect(kotlin, contains(r'"${key}_light"'));
    expect(kotlin, contains(r'"${key}_dark"'));
    expect(WidgetSnapshot.version, 1);
    expect(kotlin, contains('const val VERSION = 1'));
  });

  test('RemoteViews reflection calls use only methods remotable from API 26', () {
    // RemoteViews.setInt / setBoolean / … call a view method by name, and the
    // launcher refuses (the whole widget shows "Can't load widget") a method
    // that is not @RemotableViewMethod on the phone's Android version. Checked
    // by reflection against Robolectric's android-all 8.0 (API 26) and 16
    // (API 36) framework jars:
    //   TextView.setPaintFlags – remotable on 26 and 36;
    //   TextView.setGravity    – NOT remotable on 26 (only from Android 12):
    //                            use XML gravity (start / end / center) instead,
    //                            the text's leading RLM / LRM picks the side.
    const remotableFromApi26 = {'setPaintFlags'};
    final calls = RegExp(
      r'\.set(?:Int|Boolean|Long|Float|Double|Short|Byte|Char|String|CharSequence|Uri|Bitmap|Bundle|Intent|Icon|ColorStateList|BlendMode)\(\s*[\w.]+,\s*"(\w+)"',
    ).allMatches(_kotlin).map((m) => m.group(1)!).toSet();
    for (final method in calls) {
      expect(remotableFromApi26, contains(method), reason: 'RemoteViews reflection on $method(…)');
    }
  });

  test('text alignment comes from the layouts, never from code', () {
    // Every text is placed by XML gravity: start (the reading side of its
    // RLM / LRM-marked paragraph), end, or center.
    final layouts = {
      for (final f in Directory('$_res/layout').listSync().whereType<File>())
        if (f.uri.pathSegments.last.startsWith('widget_')) f.uri.pathSegments.last: f.readAsStringSync(),
    };
    String tagOf(String layout, String id) =>
        RegExp('<(\\w+)\\s[^>]*android:id="@\\+id/$id"[^>]*>').firstMatch(layouts[layout]!)?.group(0) ?? '';
    // The count at the title's far end and each dose's time sit at the end.
    expect(tagOf('widget_list.xml', 'widget_headline'), contains('android:gravity="end|center_vertical"'));
    final styles = _read('$_res/values/widget_styles.xml');
    expect(
      RegExp(r'<style name="widget_text_row_time"[\s\S]*?</style>').firstMatch(styles)!.group(0),
      contains('<item name="android:gravity">end|center_vertical</item>'),
    );
    expect(
      RegExp(r'<style name="widget_text_row"[\s\S]*?</style>').firstMatch(styles)!.group(0),
      contains('<item name="android:gravity">start|center_vertical</item>'),
    );
    // Centred texts stay centred.
    for (final id in ['widget_headline', 'widget_detail', 'widget_countdown']) {
      expect(tagOf('widget_prayer_small.xml', id), contains('android:gravity="center"'), reason: id);
    }
    for (final id in ['widget_title', 'widget_message']) {
      expect(tagOf('widget_placeholder.xml', id), contains('android:gravity="center"'), reason: id);
    }
    // Absolute LEFT / RIGHT would pin a text to one side in both languages.
    for (final e in layouts.entries) {
      expect(e.value, isNot(matches(RegExp(r'android:gravity="[^"]*\b(left|right)\b'))), reason: e.key);
    }
  });

  test('decrypted snapshot text never reaches the log', () {
    // org.json's parse errors quote the whole input ("… at character 12 of
    // {…}"): a snapshot that fails to parse is logged by exception class only.
    final renderer = _read('$_kotlinDir/MadarWidgetRenderer.kt');
    final parse = RegExp(r'fun parse\(text: String\)[\s\S]*?\n        \}').firstMatch(renderer)!.group(0)!;
    expect(parse, contains('Log.w('));
    expect(parse, isNot(matches(RegExp(r'Log\.\w\([^)]*,\s*e\)'))), reason: 'the exception (and its message) is not logged');
  });

  test('MainActivity registers the widgets\' plugin', () {
    final activity = _read('$_main/kotlin/app/madar/orbit/MainActivity.kt');
    expect(activity, contains('import app.madar.orbit.widgets.MadarWidgetsChannel'));
    expect(RegExp(r'MadarWidgetsChannel\.register\(flutterEngine, \w+\)').hasMatch(activity), isTrue);
  });
}
