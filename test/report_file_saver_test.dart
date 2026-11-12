import 'dart:io';
import 'dart:typed_data';

import 'package:cots_monitor/services/report_file_saver.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Selector extends FileSelectorPlatform {
  FileSaveLocation? result;
  SaveDialogOptions? options;
  List<XTypeGroup>? types;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    this.options = options;
    types = acceptedTypeGroups;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FileSelectorPlatform original;
  late _Selector selector;
  const channel = MethodChannel('file_saver');
  setUp(() {
    original = FileSelectorPlatform.instance;
    selector = _Selector();
    FileSelectorPlatform.instance = selector;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async =>
                throw StateError('Windows must never use file_saver saveAs'));
  });
  tearDown(() {
    FileSelectorPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final extension in ['pdf', 'csv']) {
    test('Windows $extension export writes exact bytes using selected path',
        () async {
      final directory = await Directory.systemTemp.createTemp('report_export_');
      try {
        final path = '${directory.path}/Samal report ñ.$extension';
        selector.result = FileSaveLocation(path);
        final bytes = Uint8List.fromList([37, 80, 68, 70, 45, 0, 255]);
        final saved = await ReportFileSaver.save(
            name: 'cots_report',
            bytes: bytes,
            fileExtension: extension,
            mimeType: extension == 'pdf' ? MimeType.pdf : MimeType.csv);
        expect(saved, path);
        expect(await File(path).readAsBytes(), bytes);
        expect(selector.options!.suggestedName, 'cots_report.$extension');
        expect(selector.types!.single.extensions, [extension]);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }

  test('Windows cancellation returns null without a file write', () async {
    expect(
        await ReportFileSaver.save(
            name: 'report',
            bytes: Uint8List(3),
            fileExtension: 'pdf',
            mimeType: MimeType.pdf),
        isNull);
  });

  test('Windows write failure is catchable instead of closing the app',
      () async {
    final directory = await Directory.systemTemp.createTemp('report_error_');
    try {
      selector.result =
          FileSaveLocation('${directory.path}/missing/report.pdf');
      await expectLater(
          ReportFileSaver.save(
              name: 'report',
              bytes: Uint8List(3),
              fileExtension: 'pdf',
              mimeType: MimeType.pdf),
          throwsA(isA<FileSystemException>()));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('Android keeps its existing native save flow and bytes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (value) async {
      call = value;
      return Platform.isWindows
          ? Int64List.fromList('content://report.pdf'.codeUnits)
          : 'content://report.pdf';
    });
    final bytes = Uint8List.fromList([37, 80, 68, 70, 45]);
    expect(
        await ReportFileSaver.save(
            name: 'report',
            bytes: bytes,
            fileExtension: 'pdf',
            mimeType: MimeType.pdf),
        'content://report.pdf');
    expect(call!.method, 'saveAs');
    expect(call!.arguments['bytes'], bytes);
    expect(selector.options, isNull);
  });
}
