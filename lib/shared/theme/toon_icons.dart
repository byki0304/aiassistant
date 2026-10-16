import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ToonGlyph {
  calendar,
  wallet,
  weather,
  exchange,
  news,
  calculator,
  user,
  mic,
  clip,
  upload,
  sparkle,
  trash,
  check,
  gear,
  google,
  flagUs,
  flagJp,
  globe,
  pin,
  sun,
  cloud,
  rain,
  snow,
  money,
  chevronLeft,
  chevronRight,
  close,
  logout,
  database,
  cloudSync,
  send,
  mail,
  phone,
}

class ToonIcon extends StatelessWidget {
  const ToonIcon(this.glyph, {super.key, this.size = 24, this.ink = _ink});

  static const _ink = Color(0xFF26282E);

  final ToonGlyph glyph;
  final double size;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(size: Size.square(size), painter: _ToonIconPainter(glyph, ink)),
    );
  }
}

class _ToonIconPainter extends CustomPainter {
  _ToonIconPainter(this.glyph, this.ink);

  final ToonGlyph glyph;
  final Color ink;

  static const _white = Color(0xFFFFFFFF);
  static const _pink = Color(0xFFF26D8F);
  static const _yellow = Color(0xFFFFC83D);
  static const _green = Color(0xFF6CC48A);
  static const _blue = Color(0xFF5DA9E9);
  static const _red = Color(0xFFE8474C);
  static const _brown = Color(0xFFB8774A);
  static const _lilac = Color(0xFF9C7BE0);
  static const _steel = Color(0xFF5B6574);
  static const _lime = Color(0xFFBDE38F);
  static const _peach = Color(0xFFFFD7B0);
  static const _navy = Color(0xFF34406A);

  late Paint _line;

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  void _shape(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _line);
  }

  void _rrect(Canvas canvas, Rect rect, double radius, Color color) {
    _shape(canvas, Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))), color);
  }

  void _circle(Canvas canvas, Offset center, double radius, Color color) {
    _shape(canvas, Path()..addOval(Rect.fromCircle(center: center, radius: radius)), color);
  }

  void _symbol(Canvas canvas, String symbol, Offset center, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    _line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case ToonGlyph.calendar:
        _rrect(canvas, const Rect.fromLTWH(3, 4.5, 18, 16.5), 3, _white);
        _shape(
          canvas,
          Path()
            ..moveTo(3, 10)
            ..lineTo(3, 7.5)
            ..arcToPoint(const Offset(6, 4.5), radius: const Radius.circular(3))
            ..lineTo(18, 4.5)
            ..arcToPoint(const Offset(21, 7.5), radius: const Radius.circular(3))
            ..lineTo(21, 10)
            ..close(),
          _pink,
        );
        _rrect(canvas, const Rect.fromLTWH(6.6, 2.4, 2.2, 4.4), 1.1, _white);
        _rrect(canvas, const Rect.fromLTWH(15.2, 2.4, 2.2, 4.4), 1.1, _white);
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 4; col++) {
            final hot = row == 1 && col == 2;
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(5.6 + col * 3.5, 12 + row * 4, 2.3, 2.3), const Radius.circular(0.6)),
              _fill(hot ? _red : ink.withValues(alpha: 0.75)),
            );
          }
        }
      case ToonGlyph.wallet:
        canvas.save();
        canvas.translate(12, 7);
        canvas.rotate(-0.18);
        _rrect(canvas, const Rect.fromLTWH(-6.5, -4, 12, 7), 1.2, _lime);
        canvas.drawCircle(const Offset(-0.5, -0.5), 1.4, _line);
        canvas.restore();
        _rrect(canvas, const Rect.fromLTWH(2.5, 8, 19, 13), 3, _brown);
        _rrect(canvas, const Rect.fromLTWH(14, 11.5, 8, 6), 2, const Color(0xFF8E5530));
        canvas.drawCircle(const Offset(17, 14.5), 1.2, _fill(_yellow));
      case ToonGlyph.weather:
      case ToonGlyph.sun:
        final sunCenter = glyph == ToonGlyph.sun ? const Offset(12, 12) : const Offset(9.5, 9);
        final sunRadius = glyph == ToonGlyph.sun ? 5.0 : 4.6;
        final rays = Paint()
          ..color = const Color(0xFFF2A516)
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final from = sunCenter + Offset(math.cos(angle), math.sin(angle)) * (sunRadius + 1.4);
          final to = sunCenter + Offset(math.cos(angle), math.sin(angle)) * (sunRadius + 3.4);
          canvas.drawLine(from, to, rays);
        }
        _circle(canvas, sunCenter, sunRadius, _yellow);
        if (glyph == ToonGlyph.weather) {
          _cloud(canvas, const Offset(14.5, 16), 1, _white);
        }
      case ToonGlyph.cloud:
        _cloud(canvas, const Offset(12, 13.5), 1.25, _white);
      case ToonGlyph.rain:
        _cloud(canvas, const Offset(12, 10.5), 1.2, const Color(0xFFDDE7F3));
        final drop = Paint()
          ..color = _blue
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        for (final x in const [8.0, 12.0, 16.0]) {
          canvas.drawLine(Offset(x, 17), Offset(x - 1.2, 20.5), drop);
        }
      case ToonGlyph.snow:
        _cloud(canvas, const Offset(12, 10.5), 1.2, _white);
        for (final x in const [8.0, 12.0, 16.0]) {
          canvas.drawCircle(Offset(x, 19), 1.3, _fill(_blue));
        }
      case ToonGlyph.exchange:
        _circle(canvas, const Offset(8.5, 9), 6, _yellow);
        _symbol(canvas, '¥', const Offset(8.5, 9.2), 8, ink);
        _circle(canvas, const Offset(15.5, 15.5), 6, _green);
        _symbol(canvas, r'$', const Offset(15.5, 15.7), 8, _white);
        final arrow = Paint()
          ..color = _red
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(const Rect.fromLTWH(14, 2, 8, 8), -1.3, 1.9, false, arrow);
        canvas.drawLine(const Offset(21.6, 7.4), const Offset(20.6, 5.6), arrow);
        canvas.drawArc(const Rect.fromLTWH(2, 14, 8, 8), 1.8, 1.9, false, arrow);
        canvas.drawLine(const Offset(2.4, 16.6), const Offset(3.4, 18.4), arrow);
      case ToonGlyph.news:
        _rrect(canvas, const Rect.fromLTWH(3, 3.5, 18, 17.5), 2.4, _white);
        _rrect(canvas, const Rect.fromLTWH(5.5, 6, 13, 3.6), 1, _lilac);
        _rrect(canvas, const Rect.fromLTWH(5.5, 11.5, 5.5, 5), 1, const Color(0xFFBFDDF7));
        final rule = Paint()
          ..color = ink
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(13, 12.4), const Offset(18.5, 12.4), rule);
        canvas.drawLine(const Offset(13, 15.4), const Offset(18.5, 15.4), rule);
        canvas.drawLine(const Offset(5.5, 18.6), const Offset(18.5, 18.6), rule);
      case ToonGlyph.calculator:
        _rrect(canvas, const Rect.fromLTWH(4.5, 2.5, 15, 19), 3, _steel);
        _rrect(canvas, const Rect.fromLTWH(7, 5, 10, 4.2), 1, _lime);
        const keyColors = [_pink, _yellow, _blue, _white, _white, Color(0xFFF7A33B)];
        for (var i = 0; i < 6; i++) {
          final col = i % 3;
          final row = i ~/ 3;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(7 + col * 3.6, 11.4 + row * 4, 2.6, 2.6), const Radius.circular(0.7)),
            _fill(keyColors[i]),
          );
        }
      case ToonGlyph.user:
        _shape(
          canvas,
          Path()
            ..moveTo(4, 21)
            ..quadraticBezierTo(4, 13.5, 12, 13.5)
            ..quadraticBezierTo(20, 13.5, 20, 21)
            ..close(),
          _navy,
        );
        _circle(canvas, const Offset(12, 8.5), 4.6, _peach);
      case ToonGlyph.mic:
        _rrect(canvas, const Rect.fromLTWH(8.5, 2.5, 7, 11.5), 3.5, _white);
        canvas.drawArc(const Rect.fromLTWH(5.5, 6.5, 13, 11), 0.15, math.pi - 0.3, false, _line);
        canvas.drawLine(const Offset(12, 17.6), const Offset(12, 21), _line);
        canvas.drawLine(const Offset(8.5, 21), const Offset(15.5, 21), _line);
      case ToonGlyph.clip:
        final clip = Path()
          ..moveTo(15.5, 7)
          ..lineTo(15.5, 16)
          ..arcToPoint(const Offset(8.5, 16), radius: const Radius.circular(3.5))
          ..lineTo(8.5, 6.5)
          ..arcToPoint(const Offset(13, 6.5), radius: const Radius.circular(2.25))
          ..lineTo(13, 15.5)
          ..arcToPoint(const Offset(11, 15.5), radius: const Radius.circular(1));
        canvas.drawPath(clip, _line..strokeWidth = 1.7);
      case ToonGlyph.upload:
        _shape(
          canvas,
          Path()
            ..moveTo(3.5, 14)
            ..lineTo(3.5, 19)
            ..arcToPoint(const Offset(5.5, 21), radius: const Radius.circular(2), clockwise: false)
            ..lineTo(18.5, 21)
            ..arcToPoint(const Offset(20.5, 19), radius: const Radius.circular(2), clockwise: false)
            ..lineTo(20.5, 14),
          Colors.transparent,
        );
        _shape(
          canvas,
          Path()
            ..moveTo(12, 3)
            ..lineTo(17.5, 9)
            ..lineTo(14, 9)
            ..lineTo(14, 16)
            ..lineTo(10, 16)
            ..lineTo(10, 9)
            ..lineTo(6.5, 9)
            ..close(),
          _blue,
        );
      case ToonGlyph.sparkle:
        _shape(canvas, _star(const Offset(10, 13), 8, 2.6), _yellow);
        _shape(canvas, _star(const Offset(18.5, 5.5), 3.6, 1.2), _yellow);
      case ToonGlyph.send:
        _shape(
          canvas,
          Path()
            ..moveTo(3, 11)
            ..lineTo(21, 3.5)
            ..lineTo(14.5, 21)
            ..lineTo(11.2, 13.2)
            ..close(),
          _yellow,
        );
      case ToonGlyph.trash:
        _rrect(canvas, const Rect.fromLTWH(6, 7.5, 12, 13.5), 2, _white);
        _rrect(canvas, const Rect.fromLTWH(4, 5, 16, 2.8), 1.2, _red);
        _rrect(canvas, const Rect.fromLTWH(9.5, 2.6, 5, 2.6), 1, _red);
        canvas.drawLine(const Offset(10, 11), const Offset(10, 17.5), _line);
        canvas.drawLine(const Offset(14, 11), const Offset(14, 17.5), _line);
      case ToonGlyph.check:
        _rrect(canvas, const Rect.fromLTWH(3, 3, 18, 18), 4.5, _green);
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 12.5)
            ..lineTo(10.7, 15.6)
            ..lineTo(16.8, 8.6),
          Paint()
            ..color = _white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case ToonGlyph.gear:
        final gear = Path();
        for (var i = 0; i < 16; i++) {
          final angle = i * math.pi / 8;
          final radius = i.isEven ? 9.5 : 7.2;
          final point = Offset(12 + math.cos(angle) * radius, 12 + math.sin(angle) * radius);
          i == 0 ? gear.moveTo(point.dx, point.dy) : gear.lineTo(point.dx, point.dy);
        }
        gear.close();
        _shape(canvas, gear, const Color(0xFFC7CCD3));
        _circle(canvas, const Offset(12, 12), 3, _white);
      case ToonGlyph.google:
        _circle(canvas, const Offset(12, 12), 10, _white);
        const arcs = [(_red, -2.6, 1.45), (_yellow, 2.0, 1.15), (_green, 0.75, 1.3), (_blue, -0.15, 0.95)];
        for (final (color, start, sweep) in arcs) {
          canvas.drawArc(
            const Rect.fromLTWH(6.2, 6.2, 11.6, 11.6),
            start,
            sweep,
            false,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6,
          );
        }
        canvas.drawLine(
          const Offset(12.2, 12),
          const Offset(17.6, 12),
          Paint()
            ..color = _blue
            ..strokeWidth = 2.6,
        );
      case ToonGlyph.flagUs:
        final flag = RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, 5, 19, 14), const Radius.circular(2));
        canvas.save();
        canvas.clipRRect(flag);
        canvas.drawRRect(flag, _fill(_white));
        for (var i = 0; i < 7; i += 2) {
          canvas.drawRect(Rect.fromLTWH(2.5, 5 + i * 2, 19, 2), _fill(_red));
        }
        canvas.drawRect(const Rect.fromLTWH(2.5, 5, 8.5, 7.5), _fill(_navy));
        canvas.restore();
        canvas.drawRRect(flag, _line);
      case ToonGlyph.flagJp:
        _rrect(canvas, const Rect.fromLTWH(2.5, 5, 19, 14), 2, _white);
        canvas.drawCircle(const Offset(12, 12), 4, _fill(_red));
      case ToonGlyph.globe:
        _circle(canvas, const Offset(12, 12), 9, const Color(0xFF8CCBF2));
        final land = Path()
          ..moveTo(6, 8)
          ..quadraticBezierTo(9, 5.5, 11, 8.5)
          ..quadraticBezierTo(9.5, 12, 7, 11.5)
          ..close()
          ..moveTo(13, 13)
          ..quadraticBezierTo(17.5, 11, 18, 15)
          ..quadraticBezierTo(15.5, 19, 13.5, 17)
          ..close();
        canvas.drawPath(land, _fill(_green));
        canvas.drawOval(const Rect.fromLTWH(7.5, 3, 9, 18), _line..strokeWidth = 1);
        canvas.drawLine(const Offset(3, 12), const Offset(21, 12), _line);
      case ToonGlyph.pin:
        _shape(
          canvas,
          Path()
            ..moveTo(12, 21.5)
            ..quadraticBezierTo(4.5, 13.5, 4.5, 9.5)
            ..arcToPoint(const Offset(19.5, 9.5), radius: const Radius.circular(7.5))
            ..quadraticBezierTo(19.5, 13.5, 12, 21.5)
            ..close(),
          _red,
        );
        _circle(canvas, const Offset(12, 9.5), 2.8, _white);
      case ToonGlyph.money:
        _rrect(canvas, const Rect.fromLTWH(2, 6, 20, 12), 2, _lime);
        _circle(canvas, const Offset(12, 12), 3.4, const Color(0xFF6CC48A));
        canvas.drawCircle(const Offset(5.5, 12), 1, _fill(ink));
        canvas.drawCircle(const Offset(18.5, 12), 1, _fill(ink));
      case ToonGlyph.chevronLeft:
      case ToonGlyph.chevronRight:
        final left = glyph == ToonGlyph.chevronLeft;
        canvas.drawPath(
          Path()
            ..moveTo(left ? 15 : 9, 5)
            ..lineTo(left ? 8 : 16, 12)
            ..lineTo(left ? 15 : 9, 19),
          _line..strokeWidth = 2.6,
        );
      case ToonGlyph.close:
        final cross = _line..strokeWidth = 2.4;
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), cross);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), cross);
      case ToonGlyph.logout:
        _rrect(canvas, const Rect.fromLTWH(3.5, 3.5, 10, 17), 2, _white);
        _shape(
          canvas,
          Path()
            ..moveTo(10, 10)
            ..lineTo(16, 10)
            ..lineTo(16, 6.8)
            ..lineTo(21.5, 12)
            ..lineTo(16, 17.2)
            ..lineTo(16, 14)
            ..lineTo(10, 14)
            ..close(),
          _red,
        );
      case ToonGlyph.database:
        for (var i = 2; i >= 0; i--) {
          final top = 5 + i * 5.0;
          _shape(
            canvas,
            Path()
              ..moveTo(4.5, top)
              ..lineTo(4.5, top + 4.5)
              ..arcToPoint(Offset(19.5, top + 4.5), radius: const Radius.elliptical(7.5, 2.6), clockwise: false)
              ..lineTo(19.5, top)
              ..close(),
            i == 0 ? _yellow : const Color(0xFFF7A33B),
          );
        }
        _shape(canvas, Path()..addOval(const Rect.fromLTWH(4.5, 2.4, 15, 5.2)), _yellow);
      case ToonGlyph.cloudSync:
        _cloud(canvas, const Offset(12, 12.5), 1.25, const Color(0xFFBFDDF7));
        final sync = Paint()
          ..color = _navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(const Rect.fromLTWH(9, 10, 6, 6), 3.6, 4.4, false, sync);
        canvas.drawLine(const Offset(15, 13), const Offset(15.4, 11.2), sync);
      case ToonGlyph.mail:
        _rrect(canvas, const Rect.fromLTWH(2.5, 5, 19, 14), 2.4, _white);
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 6.5)
            ..lineTo(12, 13)
            ..lineTo(20.5, 6.5),
          _line,
        );
        _circle(canvas, const Offset(19.5, 6), 2.6, _red);
      case ToonGlyph.phone:
        _rrect(canvas, const Rect.fromLTWH(6, 2, 12, 20), 3, _navy);
        _rrect(canvas, const Rect.fromLTWH(7.8, 4.6, 8.4, 12.6), 1.2, const Color(0xFFBFDDF7));
        canvas.drawCircle(const Offset(12, 19.4), 1, _fill(_white));
        _shape(canvas, _star(const Offset(12, 10.9), 3.2, 1.1), _yellow);
    }
  }

  void _cloud(Canvas canvas, Offset center, double scale, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final path = Path()
      ..moveTo(-6.5, 3.5)
      ..arcToPoint(const Offset(-5, -2), radius: const Radius.circular(3))
      ..arcToPoint(const Offset(2.5, -4), radius: const Radius.circular(4.4))
      ..arcToPoint(const Offset(6.5, 3.5), radius: const Radius.circular(3.8))
      ..close();
    _shape(canvas, path, color);
    canvas.restore();
  }

  Path _star(Offset center, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final radius = i.isEven ? outer : inner;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _ToonIconPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.ink != ink;
}

ToonGlyph weatherGlyph(String condition) {
  final text = condition.toLowerCase();
  if (text.contains('비') || text.contains('rain') || text.contains('drizzle') || text.contains('雨')) {
    return ToonGlyph.rain;
  }
  if (text.contains('눈') || text.contains('snow') || text.contains('雪')) {
    return ToonGlyph.snow;
  }
  if (text.contains('맑') || text.contains('clear') || text.contains('晴')) {
    return ToonGlyph.sun;
  }
  if (text.contains('조금') || text.contains('few')) {
    return ToonGlyph.weather;
  }
  return ToonGlyph.cloud;
}
