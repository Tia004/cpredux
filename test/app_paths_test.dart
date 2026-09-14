import 'dart:io';

import 'package:cpredux/data/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPaths salvaguardia cartelle utente', () {
    tearDown(AppPaths.clearOverrides);

    test('in ambiente di test documentsDir non tocca mai i documenti reali', () {
      AppPaths.clearOverrides();
      final Directory docs = AppPaths.documentsDir();
      
      // Deve essere una cartella di test o temporanea, mai Documents reale dell'utente
      expect(docs.path, contains('test'));
    });

    test('overrideForTesting eredita data o config per documents se non specificato', () {
      final Directory temp = Directory.systemTemp.createTempSync('app_paths_test');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      AppPaths.overrideForTesting(config: temp.path, data: temp.path);
      expect(AppPaths.documentsDir().path, temp.path);
    });

    test('overrideForTesting rispetta documents esplicito', () {
      final Directory temp = Directory.systemTemp.createTempSync('app_paths_test');
      final Directory customDocs = Directory.systemTemp.createTempSync('custom_docs');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        if (customDocs.existsSync()) customDocs.deleteSync(recursive: true);
      });

      AppPaths.overrideForTesting(
        config: temp.path,
        data: temp.path,
        documents: customDocs.path,
      );
      expect(AppPaths.documentsDir().path, customDocs.path);
    });
  });
}
