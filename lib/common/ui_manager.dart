import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/state.dart';
import 'package:path/path.dart';

class UiManager {
  static UiManager? _instance;

  UiManager._internal();

  factory UiManager() {
    _instance ??= UiManager._internal();
    return _instance!;
  }

  Future<void> initializeUI() async {
    commonPrint.log('=== initializeUI: start ===');
    try {
      final uiPath = await appPath.uiPath;
      commonPrint.log('=== initializeUI: uiPath=$uiPath ===');
      final uiDir = Directory(uiPath);
      final versionFile = File(join(uiPath, '.ui_version'));
      final currentVersion = globalState.packageInfo.version;
      commonPrint.log('=== initializeUI: currentVersion=$currentVersion ===');

      if (await uiDir.exists()) {
        if (await versionFile.exists()) {
          final existingVersion = await versionFile.readAsString();
          if (existingVersion.trim() == currentVersion) {
            commonPrint.log('UI already up to date (v$currentVersion)');
            return;
          }
          commonPrint.log('UI version mismatch: $existingVersion -> $currentVersion');
        }
        await clearUI();
      }

      commonPrint.log('Extracting UI from assets...');

      await uiDir.create(recursive: true);

      final zipData = await rootBundle.load('assets/data/zash.zip');
      
      final bytes = Uint8List.fromList(zipData.buffer.asUint8List());

      final tempPath = await appPath.tempPath;
      final tempExtractPath = join(
        tempPath,
        'ui_extract_${DateTime.now().millisecondsSinceEpoch}',
      );

      await Isolate.run(() async {
        final tempExtractDir = Directory(tempExtractPath);
        await tempExtractDir.create(recursive: true);

        try {
          final archive = ZipDecoder().decodeBytes(bytes);

          for (final file in archive) {
            final filename = file.name;
            final filePath = join(tempExtractPath, filename);

            if (file.isFile) {
              final outFile = File(filePath);
              await outFile.create(recursive: true);
              await outFile.writeAsBytes(file.content as List<int>);
            } else {
              await Directory(filePath).create(recursive: true);
            }
          }

          final extractedFiles = await tempExtractDir.list().toList();
          String sourceDir = tempExtractPath;

          if (extractedFiles.length == 1 && extractedFiles.first is Directory) {
            sourceDir = extractedFiles.first.path;
          }

          await _copyDirectory(Directory(sourceDir), Directory(uiPath));

          final vFile = File(join(uiPath, '.ui_version'));
          await vFile.writeAsString(currentVersion);
        } finally {
          if (await tempExtractDir.exists()) {
            await tempExtractDir.delete(recursive: true);
          }
        }
      });

      commonPrint.log('UI extracted successfully to: $uiPath (v$currentVersion)');
    } catch (e) {
      commonPrint.log('Error extracting UI: $e');
      rethrow;
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(
          join(destination.path, basename(entity.path)),
        );
        await newDirectory.create(recursive: true);
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File(join(destination.path, basename(entity.path)));
        await entity.copy(newFile.path);
      }
    }
  }

  Future<void> clearUI() async {
    try {
      final uiPath = await appPath.uiPath;
      final uiDir = Directory(uiPath);

      if (await uiDir.exists()) {
        await uiDir.delete(recursive: true);
        commonPrint.log('UI cleared successfully');
      }
    } catch (e) {
      commonPrint.log('Error clearing UI: $e');
    }
  }
}

final uiManager = UiManager();