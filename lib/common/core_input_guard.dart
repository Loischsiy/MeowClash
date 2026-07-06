import 'dart:io';
import 'dart:typed_data';

const maxCoreInputBytes = 16 * 1024 * 1024;

class CoreInputTooLargeException implements Exception {
  const CoreInputTooLargeException(this.name, this.bytes);

  final String name;
  final int bytes;

  @override
  String toString() => '$name is too large (${formatCoreInputBytes(bytes)} > '
      '${formatCoreInputBytes(maxCoreInputBytes)})';
}

void ensureCoreInputSize(int bytes, {required String name}) {
  if (bytes > maxCoreInputBytes) {
    throw CoreInputTooLargeException(name, bytes);
  }
}

void ensureCoreInputBytes(Uint8List bytes, {required String name}) {
  ensureCoreInputSize(bytes.length, name: name);
}

void ensureCoreInputFileFits(File file, {required String name}) {
  if (file.existsSync()) {
    ensureCoreInputSize(file.lengthSync(), name: name);
  }
}

void ensureCoreInputHeaderFits(String? contentLength, {required String name}) {
  final bytes = int.tryParse(contentLength ?? '');
  if (bytes != null) {
    ensureCoreInputSize(bytes, name: name);
  }
}

String formatCoreInputBytes(int bytes) {
  final mib = bytes / 1024 / 1024;
  return '${mib.toStringAsFixed(mib >= 10 ? 0 : 1)} MiB';
}
