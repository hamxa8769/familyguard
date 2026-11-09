import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Numbers that don't jiggle while they animate (tabular figures).
TextStyle fgNumber(BuildContext context, double size,
        {FontWeight weight = FontWeight.w600, Color? color}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.5,
      color: color ?? FgColors.of(context).text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Flat surface card with a hairline border. The base building block.
class FgCard extends StatelessWidget {
  const FgCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FgSpace.lg),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final radius = BorderRadius.circular(FgSpace.radius);
    return Material(
      color: color ?? c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small uppercase-free section label with optional trailing action.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, FgSpace.lg, 4, FgSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Animated progress ring (screen time, permissions, …). Pure CustomPaint —
/// no extra packages, cheap to redraw.
class StatRing extends StatelessWidget {
  const StatRing({
    super.key,
    required this.value,
    required this.center,
    this.size = 120,
    this.stroke = 10,
    this.color,
  });

  /// 0..1 (values above 1 are drawn full).
  final double value;
  final Widget center;
  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(
            value: v,
            track: c.border,
            color: color ?? c.accent,
            stroke: stroke,
          ),
          child: child,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.track,
    required this.color,
    required this.stroke,
  });

  final double value;
  final Color track;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Thin animated bar for "app X used Y of the max".
class FgBar extends StatelessWidget {
  const FgBar({super.key, required this.value, this.color});
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.border)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                heightFactor: 1,
                child: ColoredBox(color: color ?? c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status dot that gently pulses when [pulse] is true (e.g. device online).
class StatusDot extends StatefulWidget {
  const StatusDot({super.key, required this.color, this.pulse = false});
  final Color color;
  final bool pulse;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.pulse && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse)
                Container(
                  width: 8 + 6 * t,
                  height: 8 + 6 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Loading placeholder that breathes instead of spinning.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 8});
  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: c.surfaceHigh,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Round icon well used in tiles and quick actions.
class IconWell extends StatelessWidget {
  const IconWell(this.icon, {super.key, this.color, this.size = 40});
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final col = color ?? c.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.tint(col),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: col, size: size * 0.5),
    );
  }
}

/// Square shortcut button (Home → quick actions).
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FgCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconWell(icon, color: color, size: 32),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Feature row used by the Activity / Rules hubs.
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return FgCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FgSpace.md),
      child: Row(
        children: [
          IconWell(icon, color: color),
          const SizedBox(width: FgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, color: c.textMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
