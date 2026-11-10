// Merges the per-area string files in lib/core/i18n/arb_parts/*.json into the
// ARB files consumed by `flutter gen-l10n`.
//
// Part file format (one per feature area, so parallel work never conflicts):
// {
//   "homeTitle": {"ar": "مَدار", "en": "Madar", "description": "App title"},
//   "itemsCount": {
//     "ar": "{count, plural, =0{لا عناصر} =1{عنصر واحد} =2{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}",
//     "en": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
//     "placeholders": {"count": {"type": "int"}}
//   }
// }
//
// Usage: dart run tool/merge_arb.dart && flutter gen-l10n
import 'dart:convert';
import 'dart:io';

void main() {
  final partsDir = Directory('lib/core/i18n/arb_parts');
  final ar = <String, Object?>{'@@locale': 'ar'};
  final en = <String, Object?>{'@@locale': 'en'};
  final seen = <String, String>{};
  final files = partsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in data.entries) {
      final key = entry.key;
      if (seen.containsKey(key)) {
        stderr.writeln('Duplicate key "$key" in ${file.path} (already in ${seen[key]})');
        exitCode = 1;
        continue;
      }
      seen[key] = file.path;
      final v = entry.value as Map<String, dynamic>;
      ar[key] = v['ar'];
      en[key] = v['en'] ?? v['ar'];
      final meta = <String, Object?>{};
      if (v['description'] != null) meta['description'] = v['description'];
      if (v['placeholders'] != null) meta['placeholders'] = v['placeholders'];
      if (meta.isNotEmpty) {
        ar['@$key'] = meta;
        en['@$key'] = meta;
      }
    }
  }
  const encoder = JsonEncoder.withIndent('  ');
  File('lib/core/i18n/arb/app_ar.arb').writeAsStringSync('${encoder.convert(ar)}\n');
  File('lib/core/i18n/arb/app_en.arb').writeAsStringSync('${encoder.convert(en)}\n');
  stdout.writeln('Merged ${seen.length} keys from ${files.length} part files.');
}
