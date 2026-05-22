import 'dart:io';

import 'package:d1vai_app/services/local_workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = LocalWorkspaceService();

  group('LocalWorkspaceService.readFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('d1v-local-workspace');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reads text files as decoded text', () async {
      final file = File('${tempDir.path}/notes.txt');
      await file.writeAsString('hello local workspace');

      final result = await service.readFile(tempDir.path, 'notes.txt');

      expect(result.path, 'notes.txt');
      expect(result.isBinary, isFalse);
      expect(result.content, 'hello local workspace');
      expect(result.size, greaterThan(0));
    });

    test('returns placeholder content for binary files', () async {
      final file = File('${tempDir.path}/image.bin');
      await file.writeAsBytes(<int>[0, 159, 250, 88, 10, 11, 12]);

      final result = await service.readFile(tempDir.path, 'image.bin');

      expect(result.path, 'image.bin');
      expect(result.isBinary, isTrue);
      expect(result.content, isEmpty);
      expect(result.size, 7);
    });
  });
}
