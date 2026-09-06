import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Read the synchronous core config API with explicit allocator ownership.
/// Empty/error responses must release both the Dart path and core C string.
Map<String, dynamic> readNativeConfig(
  String path, {
  required Pointer<Char> Function(Pointer<Char>) getConfig,
  required void Function(Pointer<Char>) freeCString,
  Allocator allocator = malloc,
}) {
  final pathPointer = path.toNativeUtf8(allocator: allocator).cast<Char>();
  Pointer<Char> configPointer = nullptr;
  try {
    configPointer = getConfig(pathPointer);
    if (configPointer == nullptr) return {};
    final source = configPointer.cast<Utf8>().toDartString();
    if (source.isEmpty) return {};
    return json.decode(source) as Map<String, dynamic>;
  } finally {
    try {
      if (configPointer != nullptr) freeCString(configPointer);
    } finally {
      allocator.free(pathPointer);
    }
  }
}
