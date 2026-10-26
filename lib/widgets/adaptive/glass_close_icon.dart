import 'package:flutter/material.dart';

import 'glass_tokens.dart';

/// The SF Symbols `xmark`: two strokes with round caps, as on Apple's close
/// buttons (iOS 26 sheets, macOS panels), in place of Material's square-cut
/// `Icons.close`.
///
/// Size and color come from the surrounding [IconTheme] like an [Icon], so
/// it drops into any `IconButton` (the toolbar capsules restyle it as they
/// do every symbol). Darwin installs it for every `CloseButton` through
/// `GlassTheme.apply` (`ActionIconThemeData.closeButtonIconBuilder`).
class GlassCloseIcon extends StatelessWidget {
  const GlassCloseIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = this.size ?? iconTheme.size ?? 24;
    final base = color ?? iconTheme.color ?? const Color(0xFF000000);
    final opacity = iconTheme.opacity ?? 1;
    final paintColor =
        opacity == 1 ? base : base.withValues(alpha: base.a * opacity);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _XmarkPainter(color: paintColor)),
    );
  }
}

class _XmarkPainter extends CustomPainter {
  const _XmarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = size.shortestSide;
    final half = extent * GlassTokens.closeGlyphSpan / 2;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = extent * GlassTokens.closeGlyphStroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas
      ..drawLine(
        center.translate(-half, -half),
        center.translate(half, half),
        paint,
      )
      ..drawLine(
        center.translate(half, -half),
        center.translate(-half, half),
        paint,
      );
  }

  @override
  bool shouldRepaint(_XmarkPainter oldDelegate) => oldDelegate.color != color;
}
