import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARB files have consistent translation keys', () {
    final dir = Directory('lib/l10n/arb');
    expect(dir.existsSync(), isTrue, reason: 'Missing ${dir.path}');

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(files, isNotEmpty, reason: 'No .arb files found in ${dir.path}');

    Map<String, dynamic> readJson(File f) {
      final decoded = jsonDecode(f.readAsStringSync());
      expect(decoded, isA<Map>(), reason: 'Invalid JSON in ${f.path}');
      return decoded as Map<String, dynamic>;
    }

    final enFile = files.firstWhere(
      (f) => f.path.endsWith('app_en.arb'),
      orElse: () => files.first,
    );

    final baseJson = readJson(enFile);
    final baseKeys = baseJson.keys.where((k) => !k.startsWith('@')).toSet();

    for (final f in files) {
      final json = readJson(f);

      expect(
        json['@@locale'],
        isNotNull,
        reason: 'Missing @@locale in ${f.path}',
      );

      final keys = json.keys.where((k) => !k.startsWith('@')).toSet();
      final missing = baseKeys.difference(keys).toList()..sort();
      final extra = keys.difference(baseKeys).toList()..sort();

      expect(
        missing,
        isEmpty,
        reason: 'Missing keys in ${f.path}: ${missing.join(', ')}',
      );
      expect(
        extra,
        isEmpty,
        reason: 'Extra keys in ${f.path}: ${extra.join(', ')}',
      );
    }
  });
}
