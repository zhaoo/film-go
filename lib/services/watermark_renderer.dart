import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:meta/meta.dart';

/// 测光读数水印数据。
@immutable
class WatermarkData {
  final String iso;
  final String shutter;
  final String aperture;
  final DateTime timestamp;

  const WatermarkData({
    required this.iso,
    required this.shutter,
    required this.aperture,
    required this.timestamp,
  });
}

/// 在 JPEG 图片右下角合成两行水印（时间 + ISO/快门/光圈）。
///
/// 纯函数（除 `package:image` 内部状态外），可在 `Isolate.run` 中安全调用。
class WatermarkRenderer {
  WatermarkRenderer._();

  static Uint8List render({
    required Uint8List sourceJpeg,
    required WatermarkData data,
  }) {
    final base = img.decodeJpg(sourceJpeg);
    if (base == null) {
      throw const FormatException('source bytes are not a decodable JPEG');
    }

    final shortSide = base.width < base.height ? base.width : base.height;
    final padding = (shortSide * 0.03).round().clamp(8, 256);

    // package:image 4.x 自带位图字体三档：arial14/24/48；按短边 ~2.5% 字号挑接近的。
    final desiredFontSize = (shortSide * 0.025).round();
    final font = _pickBitmapFont(desiredFontSize);

    final lineTop = formatTimestamp(data.timestamp);
    final lineBottom = '${data.iso} · ${data.shutter} · ${data.aperture}';

    final lineHeight = font.lineHeight;
    final topWidth = _measure(font, lineTop);
    final bottomWidth = _measure(font, lineBottom);
    final blockWidth = topWidth > bottomWidth ? topWidth : bottomWidth;
    final blockHeight = lineHeight * 2;

    final xRight = base.width - padding;
    final yBottom = base.height - padding;
    final xTopLeft = xRight - blockWidth;
    final xBotLeft = xRight - bottomWidth;
    final yTop = yBottom - blockHeight;

    _drawStroked(
      base,
      font: font,
      x: xTopLeft + (blockWidth - topWidth),
      y: yTop,
      text: lineTop,
    );
    _drawStroked(
      base,
      font: font,
      x: xBotLeft,
      y: yTop + lineHeight,
      text: lineBottom,
    );

    return Uint8List.fromList(img.encodeJpg(base, quality: 90));
  }

  static String formatTimestamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    String four(int n) => n.toString().padLeft(4, '0');
    return '${four(t.year)}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  static img.BitmapFont _pickBitmapFont(int desiredSize) {
    if (desiredSize >= 36) return img.arial48;
    if (desiredSize >= 18) return img.arial24;
    return img.arial14;
  }

  static int _measure(img.BitmapFont font, String text) {
    var w = 0;
    for (final code in text.codeUnits) {
      final ch = font.characters[code];
      w += ch?.xAdvance ?? font.base ~/ 2;
    }
    return w;
  }

  static void _drawStroked(
    img.Image image, {
    required img.BitmapFont font,
    required int x,
    required int y,
    required String text,
  }) {
    final stroke = img.ColorRgb8(0, 0, 0);
    final fill = img.ColorRgb8(255, 255, 255);
    for (final dx in const [-1, 0, 1]) {
      for (final dy in const [-1, 0, 1]) {
        if (dx == 0 && dy == 0) continue;
        img.drawString(
          image,
          text,
          font: font,
          x: x + dx,
          y: y + dy,
          color: stroke,
        );
      }
    }
    img.drawString(image, text, font: font, x: x, y: y, color: fill);
  }
}
