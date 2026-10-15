import 'package:flutter/material.dart';

import '../state/providers.dart';

class InkPalette {
  const InkPalette._();

  static const paper = Color(0xFFF3E6D0);
  static const panel = Color(0xFFFFF8EE);
  static const cream = Color(0xFFFFFDF8);
  static const ink = Color(0xFF1C1915);
  static const mustard = Color(0xFFF0C14A);
  static const coral = Color(0xFFE56B4E);
  static const teal = Color(0xFF1F8A7A);
  static const sky = Color(0xFFD5E7F6);
  static const mint = Color(0xFFD7F0DE);
  static const blush = Color(0xFFF8D4C4);
}

enum InkGlyph { calendar, ledger, sun, exchange, news, calculator, badge, mic, clip, send, exit }

InkGlyph inkGlyphFor(AppMenu menu) {
  return switch (menu) {
    AppMenu.schedules => InkGlyph.calendar,
    AppMenu.balance => InkGlyph.ledger,
    AppMenu.weather => InkGlyph.sun,
    AppMenu.exchange => InkGlyph.exchange,
    AppMenu.news => InkGlyph.news,
    AppMenu.calculator => InkGlyph.calculator,
  };
}

class InkIcon extends StatelessWidget {
  const InkIcon(this.glyph, {super.key, this.size = 24, this.color = InkPalette.ink});

  final InkGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _InkIconPainter(glyph, color),
    );
  }
}

class _InkIconPainter extends CustomPainter {
  _InkIconPainter(this.glyph, this.color);

  final InkGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final scale = size.width / 24;
    canvas.scale(scale);
    switch (glyph) {
      case InkGlyph.calendar:
        _calendar(canvas, stroke, fill);
      case InkGlyph.ledger:
        _ledger(canvas, stroke, fill);
      case InkGlyph.sun:
        _sun(canvas, stroke, fill);
      case InkGlyph.exchange:
        _exchange(canvas, stroke, fill);
      case InkGlyph.news:
        _news(canvas, stroke, fill);
      case InkGlyph.calculator:
        _calculator(canvas, stroke, fill);
      case InkGlyph.badge:
        _badge(canvas, stroke, fill);
      case InkGlyph.mic:
        _mic(canvas, stroke, fill);
      case InkGlyph.clip:
        _clip(canvas, stroke, fill);
      case InkGlyph.send:
        _send(canvas, fill);
      case InkGlyph.exit:
        _exit(canvas, stroke, fill);
    }
  }

  void _calendar(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 5, 18, 16), const Radius.circular(2)), stroke);
    canvas.drawLine(const Offset(3, 10), const Offset(21, 10), stroke);
    canvas.drawLine(const Offset(8, 3), const Offset(8, 7), stroke);
    canvas.drawLine(const Offset(16, 3), const Offset(16, 7), stroke);
    canvas.drawCircle(const Offset(8, 15), 1.2, fill);
    canvas.drawCircle(const Offset(12, 15), 1.2, fill);
    canvas.drawCircle(const Offset(16, 15), 1.2, fill);
  }

  void _ledger(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 3, 14, 18), const Radius.circular(2)), stroke);
    canvas.drawLine(const Offset(8, 8), const Offset(14, 8), stroke);
    canvas.drawLine(const Offset(8, 12), const Offset(14, 12), stroke);
    canvas.drawLine(const Offset(8, 16), const Offset(12, 16), stroke);
    canvas.drawCircle(const Offset(17, 16), 3.2, fill);
  }

  void _sun(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(12, 12), 4.2, stroke);
    canvas.drawCircle(const Offset(12, 12), 1.6, fill);
    for (final point in const [
      [12.0, 2.5, 12.0, 5.2],
      [12.0, 18.8, 12.0, 21.5],
      [2.5, 12.0, 5.2, 12.0],
      [18.8, 12.0, 21.5, 12.0],
      [5.2, 5.2, 7.1, 7.1],
      [16.9, 16.9, 18.8, 18.8],
      [18.8, 5.2, 16.9, 7.1],
      [7.1, 16.9, 5.2, 18.8],
    ]) {
      canvas.drawLine(Offset(point[0], point[1]), Offset(point[2], point[3]), stroke);
    }
  }

  void _exchange(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(12, 12), 8, stroke);
    final right = Path()
      ..moveTo(7, 9)
      ..lineTo(16, 9)
      ..lineTo(13, 6.2);
    final left = Path()
      ..moveTo(17, 15)
      ..lineTo(8, 15)
      ..lineTo(11, 17.8);
    canvas.drawPath(right, stroke);
    canvas.drawPath(left, stroke);
    canvas.drawCircle(const Offset(16, 9), 1.3, fill);
    canvas.drawCircle(const Offset(8, 15), 1.3, fill);
  }

  void _news(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 4, 18, 16), const Radius.circular(2)), stroke);
    canvas.drawLine(const Offset(7, 8), const Offset(17, 8), stroke);
    canvas.drawLine(const Offset(7, 12), const Offset(17, 12), stroke);
    canvas.drawLine(const Offset(7, 16), const Offset(13, 16), stroke);
    final fold = Path()
      ..moveTo(16, 4)
      ..lineTo(21, 4)
      ..lineTo(21, 9)
      ..close();
    canvas.drawPath(fold, fill);
  }

  void _calculator(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 2, 16, 20), const Radius.circular(2)), stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(7, 5, 10, 4), const Radius.circular(1)), stroke);
    for (final offset in const [Offset(8, 13), Offset(12, 13), Offset(16, 13), Offset(8, 17), Offset(12, 17), Offset(16, 17)]) {
      canvas.drawCircle(offset, 1.15, fill);
    }
  }

  void _badge(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 3, 16, 18), const Radius.circular(3)), stroke);
    canvas.drawCircle(const Offset(12, 9), 2.4, stroke);
    canvas.drawLine(const Offset(8, 15), const Offset(16, 15), stroke);
    canvas.drawCircle(const Offset(12, 9), 1, fill);
  }

  void _mic(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, 3, 6, 10), const Radius.circular(3)), stroke);
    canvas.drawArc(const Rect.fromLTWH(6, 8, 12, 9), 0, 3.14, false, stroke);
    canvas.drawLine(const Offset(12, 17), const Offset(12, 21), stroke);
    canvas.drawLine(const Offset(8, 21), const Offset(16, 21), stroke);
    canvas.drawCircle(const Offset(12, 8), 1.1, fill);
  }

  void _clip(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(6, 3, 12, 17), const Radius.circular(2)), stroke);
    final fold = Path()
      ..moveTo(13, 3)
      ..lineTo(18, 8)
      ..lineTo(13, 8)
      ..close();
    canvas.drawPath(fold, fill);
    canvas.drawLine(const Offset(9, 12), const Offset(15, 12), stroke);
    canvas.drawLine(const Offset(9, 16), const Offset(13, 16), stroke);
  }

  void _send(Canvas canvas, Paint fill) {
    final path = Path()
      ..moveTo(3, 12)
      ..lineTo(21, 4)
      ..lineTo(14, 21)
      ..lineTo(11, 13)
      ..close();
    canvas.drawPath(path, fill);
  }

  void _exit(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawLine(const Offset(4, 5), const Offset(4, 19), stroke);
    canvas.drawLine(const Offset(4, 5), const Offset(12, 5), stroke);
    canvas.drawLine(const Offset(4, 19), const Offset(12, 19), stroke);
    canvas.drawLine(const Offset(10, 12), const Offset(20, 12), stroke);
    final head = Path()
      ..moveTo(16, 8)
      ..lineTo(21, 12)
      ..lineTo(16, 16)
      ..close();
    canvas.drawPath(head, fill);
  }

  @override
  bool shouldRepaint(covariant _InkIconPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.color != color;
}
