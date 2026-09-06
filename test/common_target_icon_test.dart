import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/icon.dart';

// A one-pixel transparent GIF. No network or filesystem image dependency.
const _icon =
    'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

Widget _host(String src, {double size = 24, double ratio = 2}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(devicePixelRatio: ratio),
        child: Center(child: CommonTargetIcon(src: src, size: size)),
      ),
    );

ResizeImage _image(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).image as ResizeImage;
Uint8List _bytes(WidgetTester tester) =>
    (_image(tester).imageProvider as MemoryImage).bytes;

void main() {
  testWidgets('base64 bytes and image cache key survive repeated rebuilds',
      (tester) async {
    await tester.pumpWidget(_host(_icon));
    final bytes = _bytes(tester);
    final image = _image(tester);
    for (var i = 0; i < 100; i++) {
      await tester.pumpWidget(_host(_icon));
      expect(identical(_bytes(tester), bytes), isTrue);
      expect(_image(tester), image);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('size and pixel ratio update without decoding the source again',
      (tester) async {
    await tester.pumpWidget(_host(_icon));
    final bytes = _bytes(tester);
    expect(_image(tester).width, 48);
    await tester.pumpWidget(_host(_icon, size: 30, ratio: 3));
    expect(identical(_bytes(tester), bytes), isTrue);
    expect(_image(tester).width, 90);
    expect(_image(tester).height, 90);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changing source discards the old decoded bytes', (tester) async {
    await tester.pumpWidget(_host(_icon));
    final bytes = _bytes(tester);
    final different = Uint8List.fromList(base64.decode(_icon.split(',').last));
    different[13] =
        255; // Change a color-table entry, preserving valid GIF data.
    await tester
        .pumpWidget(_host('data:image/gif;base64,${base64.encode(different)}'));
    expect(identical(_bytes(tester), bytes), isFalse);
    await tester.pumpWidget(_host(''));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('malformed data URI uses the fallback without a network request',
      (tester) async {
    await tester.pumpWidget(_host('data:image/png;base64,%%%'));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
  });
}
