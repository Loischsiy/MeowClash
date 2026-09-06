import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:meowclash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';

class CommonTargetIcon extends StatefulWidget {
  const CommonTargetIcon({
    super.key,
    required this.src,
    required this.size,
  });
  final String src;
  final double size;

  @override
  State<CommonTargetIcon> createState() => _CommonTargetIconState();
}

class _CommonTargetIconState extends State<CommonTargetIcon> {
  Uint8List? _base64;
  Future<File>? _svgFile;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  @override
  void didUpdateWidget(covariant CommonTargetIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) _loadSource();
  }

  void _loadSource() {
    // MemoryImage keys include the identity of the byte array. Decoding on
    // every build creates another image-cache entry for the same icon.
    _base64 = widget.src.getBase64;
    _svgFile = _base64 == null && widget.src.isSvg
        ? DefaultCacheManager().getSingleFile(widget.src)
        : null;
  }

  Widget _defaultIcon() => Icon(IconsExt.target, size: widget.size);

  Widget _buildIcon(BuildContext context) {
    final src = widget.src;
    final size = widget.size;
    if (src.isEmpty) return _defaultIcon();
    final cacheSize =
        max(1, (size * MediaQuery.devicePixelRatioOf(context)).ceil());
    final base64 = _base64;
    if (base64 != null) {
      return Image.memory(
        base64,
        gaplessPlayback: true,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (_, error, ___) => _defaultIcon(),
      );
    }
    // A malformed data URI is not a network URL.
    if (src.startsWith('data:')) return _defaultIcon();

    if (src.isSvg) {
      return FutureBuilder<File>(
        key: ValueKey(src),
        future: _svgFile,
        builder: (_, snapshot) {
          if (snapshot.hasError) return _defaultIcon();
          final data = snapshot.data;
          if (data == null) return const SizedBox();
          return SvgPicture.file(
            data,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => _defaultIcon(),
          );
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      memCacheWidth: cacheSize,
      memCacheHeight: cacheSize,
      placeholder: (_, __) => const SizedBox(),
      errorWidget: (_, __, ___) => _defaultIcon(),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: _buildIcon(context),
      );
}
