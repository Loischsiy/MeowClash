import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Encode data to YAML string in a separate isolate to avoid blocking UI
/// Note: This uses JSON encoding which is a valid subset of YAML
Future<String> encodeYamlTask<T>(T data) async {
  return await compute<T, String>(_encodeYaml, data);
}

/// Internal function to encode YAML (runs in isolate)
/// Uses JSON encoding as it's a valid YAML subset and more readable for config preview
Future<String> _encodeYaml<T>(T content) async {
  // Use pretty-printed JSON which is valid YAML and more readable
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(content);
}
