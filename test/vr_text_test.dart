import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VrTextRaster (headless canvas-to-texture)', () {
    test('rasterizes text into a non-empty bitmap with ink', () async {
      final bmp = await VrTextRaster.rasterize('HOLA');
      expect(bmp.width, greaterThan(0));
      expect(bmp.height, greaterThan(0));
      expect(bmp.pixels.length, bmp.width * bmp.height * 4);
      expect(bmp.hasInk, isTrue);
    });

    test('wider text produces a wider bitmap (aspect grows)', () async {
      final short = await VrTextRaster.rasterize('SOL');
      final long = await VrTextRaster.rasterize('SOLAR SYSTEM', maxLines: 1);
      expect(long.aspect, greaterThan(short.aspect));
    });

    test('bigger font size produces a bigger bitmap', () async {
      final small = await VrTextRaster.rasterize('KANBAN', fontSize: 48);
      final big = await VrTextRaster.rasterize('KANBAN', fontSize: 120);
      expect(big.width, greaterThan(small.width));
      expect(big.height, greaterThan(small.height));
    });

    test('empty text falls back to a space (never zero-size)', () async {
      final bmp = await VrTextRaster.rasterize('');
      expect(bmp.width, greaterThanOrEqualTo(2));
      expect(bmp.height, greaterThanOrEqualTo(2));
    });

    test('respects the text color (first ink pixel matches)', () async {
      final bmp = await VrTextRaster.rasterize(
        'RGB',
        color: const Color(0xFFFF0000),
      );
      // Find an opaque pixel and check it is reddish (straight alpha RGBA).
      var found = false;
      for (var i = 0; i < bmp.pixels.length; i += 4) {
        final a = bmp.pixels[i + 3];
        if (a > 200) {
          expect(bmp.pixels[i], greaterThan(150)); // R
          expect(bmp.pixels[i + 1], lessThan(80)); // G
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'no fully opaque pixel found');
    });
  });
}
