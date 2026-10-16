import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'toon.dart';
import 'toon_icons.dart';

class ToonBackground extends StatelessWidget {
  const ToonBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: _BackgroundPainter(), child: SizedBox.expand()),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Toon.mint);
    final doodle = Paint()
      ..color = Toon.mintDeep
      ..style = PaintingStyle.fill;
    const step = 120.0;
    final random = math.Random(7);
    for (var y = -20.0; y < size.height + step; y += step) {
      for (var x = -20.0; x < size.width + step; x += step) {
        final offset = Offset(x + random.nextDouble() * 60, y + random.nextDouble() * 60);
        canvas.save();
        canvas.translate(offset.dx, offset.dy);
        canvas.rotate((random.nextDouble() - 0.5) * 0.9);
        switch (random.nextInt(3)) {
          case 0:
            canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 34, 24), const Radius.circular(10)), doodle);
            canvas.drawPath(
              Path()
                ..moveTo(8, 22)
                ..lineTo(4, 32)
                ..lineTo(16, 23)
                ..close(),
              doodle,
            );
          case 1:
            canvas.drawPath(
              Path()
                ..moveTo(0, 14)
                ..lineTo(34, 0)
                ..lineTo(24, 30)
                ..lineTo(17, 18)
                ..close(),
              doodle,
            );
          default:
            canvas.drawCircle(const Offset(12, 12), 12, doodle);
            canvas.drawCircle(const Offset(12, 12), 5, Paint()..color = Toon.mint);
        }
        canvas.restore();
      }
    }
    _halftone(canvas, Offset(size.width, 0), size);
    _halftone(canvas, Offset(0, size.height), size);
  }

  void _halftone(Canvas canvas, Offset corner, Size size) {
    final paint = Paint()..color = Toon.ink.withValues(alpha: 0.13);
    const reach = 220.0;
    const gap = 11.0;
    for (var dy = 0.0; dy < reach; dy += gap) {
      for (var dx = 0.0; dx < reach; dx += gap) {
        final falloff = 1 - math.sqrt(dx * dx + dy * dy) / reach;
        if (falloff <= 0) {
          continue;
        }
        final x = corner.dx == 0 ? dx : corner.dx - dx;
        final y = corner.dy == 0 ? dy : corner.dy - dy;
        canvas.drawCircle(Offset(x, y), 3.6 * falloff, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ToonCard extends StatelessWidget {
  const ToonCard({
    super.key,
    required this.child,
    this.color = Toon.white,
    this.padding = const EdgeInsets.all(14),
    this.radius = Toon.radius,
    this.shadow = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(Toon.border),
        boxShadow: shadow ? Toon.lift : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class ToonDot extends StatelessWidget {
  const ToonDot({super.key, this.color = Toon.sun, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Toon.ink, width: 2),
      ),
    );
  }
}

class ToonTitle extends StatelessWidget {
  const ToonTitle(this.text, {super.key, this.dot = Toon.sun, this.glyph, this.trailing, this.size = 16});

  final String text;
  final Color dot;
  final ToonGlyph? glyph;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (glyph != null) ToonIcon(glyph!, size: size + 8) else ToonDot(color: dot, size: size - 1),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Springs down on press and up on hover, the motion every tappable sticker shares.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.label, this.selected = false});

  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final scale = !enabled
        ? 1.0
        : _down
        ? 0.93
        : _hover
        ? 1.04
        : 1.0;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: widget.label != null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: Opacity(opacity: enabled ? 1 : 0.5, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class ToonButton extends StatelessWidget {
  const ToonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.color = Toon.white,
    this.textColor = Toon.ink,
    this.compact = false,
    this.subtitle,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final ToonGlyph? glyph;
  final Color color;
  final Color textColor;
  final bool compact;
  final String? subtitle;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final iconOnly = label.isEmpty;
    final caption = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: compact ? 12.5 : 14),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
          ),
      ],
    );
    final body = Container(
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? (compact ? 7 : 10) : (compact ? 11 : 16), vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.fromBorderSide(Toon.border),
        boxShadow: Toon.lift,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (glyph != null) ToonIcon(glyph!, size: compact ? 18 : 22),
            if (glyph != null && !iconOnly) const SizedBox(width: 6),
            if (!iconOnly) constraints.hasBoundedWidth ? Flexible(child: caption) : caption,
          ],
        ),
      ),
    );
    final button = Pressable(onTap: onPressed, label: label.isEmpty ? tooltip : label, child: body);
    return tooltip == null ? button : Tooltip(message: tooltip!, excludeFromSemantics: true, child: button);
  }
}

class ToonPill extends StatelessWidget {
  const ToonPill(this.text, {super.key, this.color = Toon.cream, this.glyph});

  final String text;
  final Color color;
  final ToonGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Toon.ink, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[ToonIcon(glyph!, size: 14), const SizedBox(width: 4)],
          Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.2)),
        ],
      ),
    );
  }
}

class ToonCheck extends StatelessWidget {
  const ToonCheck({super.key, required this.checked, this.size = 22});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: checked
          ? ToonIcon(ToonGlyph.check, key: const ValueKey(true), size: size + 2)
          : Container(
              key: const ValueKey(false),
              width: size,
              height: size,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Toon.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Toon.ink, width: 2),
              ),
            ),
    );
  }
}

/// A menu sticker: colored tile with icon, optional caption, and a rainbow halo when selected.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.glyph,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showLabel = true,
    this.iconSize = 34,
  });

  final ToonGlyph glyph;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showLabel;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      width: double.infinity,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: showLabel ? 7 : 6),
      transform: Matrix4.translationValues(0, selected ? -3 : 0, 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Toon.ink, width: selected ? 2.8 : 2.2),
        boxShadow: selected ? const [BoxShadow(color: Toon.ink, offset: Offset(0, 5))] : Toon.lift,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToonIcon(glyph, size: iconSize),
          if (showLabel) ...[
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.1),
            ),
          ],
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      label: label,
      selected: selected,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (selected)
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(0, -3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Toon.lilac.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 3),
                      BoxShadow(color: Toon.sky.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                ),
              ),
            ),
          tile,
        ],
      ),
    );
  }
}

enum RobotPose { wave, run, point, head, logo }

class RobotArt extends StatelessWidget {
  const RobotArt(this.pose, {super.key, required this.height, this.bob = false});

  final RobotPose pose;
  final double height;
  final bool bob;

  String get _asset => switch (pose) {
    RobotPose.wave => 'assets/images/robot_wave.webp',
    RobotPose.run => 'assets/images/robot_run.webp',
    RobotPose.point => 'assets/images/robot_point.webp',
    RobotPose.head => 'assets/images/robot_head.webp',
    RobotPose.logo => 'assets/images/robot_logo.webp',
  };

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      height: height,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    if (!bob || MediaQuery.disableAnimationsOf(context)) {
      return image;
    }
    return _Bob(child: image);
  }
}

class _Bob extends StatefulWidget {
  const _Bob({required this.child});

  final Widget child;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -5 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.06, child: child),
        );
      },
    );
  }
}

class RobotAvatar extends StatelessWidget {
  const RobotAvatar({super.key, this.size = 36, this.color = Toon.sky});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Toon.ink, width: 2),
      ),
      child: FittedBox(child: RobotArt(RobotPose.logo, height: size)),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 36, this.photoUrl, this.color = Toon.cream});

  final double size;
  final String? photoUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Toon.ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: ToonIcon(ToonGlyph.user, size: size),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Padding(
                padding: EdgeInsets.all(size * 0.14),
                child: ToonIcon(ToonGlyph.user, size: size),
              ),
            ),
    );
  }
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 20, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RobotArt(RobotPose.logo, height: size * 1.25),
        SizedBox(width: size * 0.3),
        Text(
          'aiAssistant',
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: onDark ? Toon.white : Toon.ink),
        ),
      ],
    );
  }
}

class ToonEmpty extends StatelessWidget {
  const ToonEmpty(this.text, {super.key, this.pose = RobotPose.run, this.compact = false});

  final String text;
  final RobotPose pose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RobotArt(pose, height: compact ? 64 : 104, bob: true),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Toon.inkSoft, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
