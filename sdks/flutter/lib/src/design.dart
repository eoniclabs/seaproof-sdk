import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

/// Seaproof's own design tokens, used where the app's theme has nothing to say: the colour of
/// each feedback type, the signal orange and the recording red. See docs/design/tokens.md.
abstract final class SeaproofTokens {
  /// Deep sea, Seaproof's primary colour.
  static const Color deep = Color(0xFF0B3D5C);

  /// Buoy orange: focus, the unread dot and the waterline in the mark. Not for text.
  static const Color signal = Color(0xFFE8590C);

  /// The dark bar shown while recording, whatever the app's theme.
  static const Color ink = Color(0xFF0A1F2E);

  /// The recording dot.
  static const Color recording = Color(0xFFFF5B4A);

  /// Text and tint for a feedback type, for light or dark surfaces. Text on the tint passes 4.5:1.
  static ({Color tone, Color tint}) typeColors(FeedbackType type, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final tone = switch (type) {
      FeedbackType.bug => dark ? const Color(0xFFFF8A7A) : const Color(0xFFB42318),
      FeedbackType.feedback => dark ? const Color(0xFF7DB8F0) : const Color(0xFF1B649F),
      FeedbackType.idea => dark ? const Color(0xFFF2C14E) : const Color(0xFF8A5300),
      FeedbackType.question => dark ? const Color(0xFF5FD3BF) : const Color(0xFF0B6E61),
    };
    final tint = dark
        ? tone.withValues(alpha: 0.12)
        : switch (type) {
            FeedbackType.bug => const Color(0xFFFDECEA),
            FeedbackType.feedback => const Color(0xFFE8F1FA),
            FeedbackType.idea => const Color(0xFFFDF3DE),
            FeedbackType.question => const Color(0xFFE2F4F1),
          };
    return (tone: tone, tint: tint);
  }

  /// The icon for a feedback type.
  static IconData typeIcon(FeedbackType type) => switch (type) {
    FeedbackType.bug => Icons.bug_report_outlined,
    FeedbackType.feedback => Icons.chat_bubble_outline,
    FeedbackType.idea => Icons.lightbulb_outline,
    FeedbackType.question => Icons.help_outline,
  };

  /// Status badge colours, from the type palette so the widget needs no extra colours.
  static ({Color tone, Color tint})? statusColors(PublicStatus status, Brightness brightness) => switch (status) {
    PublicStatus.underReview => typeColors(FeedbackType.feedback, brightness),
    PublicStatus.inProgress => typeColors(FeedbackType.idea, brightness),
    PublicStatus.done => typeColors(FeedbackType.question, brightness),
    PublicStatus.received || PublicStatus.closed => null,
  };

  /// The standard curve: tabs, selection, hover.
  static const Curve tide = Cubic(0.2, 0.8, 0.2, 1);

  /// Entering the screen: the panel and the sent mark.
  static const Curve swell = Cubic(0.32, 0.72, 0, 1);
}

/// The Plimsoll mark: a ring with the waterline through it. The water fills from below once,
/// unless the platform asks for less motion.
class SeaproofMark extends StatelessWidget {
  /// Creates the mark.
  const SeaproofMark({super.key, this.size = 64, this.color});

  /// Width and height.
  final double size;

  /// Ring and water. Defaults to the theme's primary colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: SeaproofTokens.swell,
        builder: (context, fill, _) => CustomPaint(
          size: Size.square(size),
          painter: _MarkPainter(color: color, fill: fill),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.color, required this.fill});

  final Color color;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 32;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = 10.5 * unit;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(1, fill)
      ..translate(-centre.dx, -centre.dy)
      ..drawArc(Rect.fromCircle(center: centre, radius: radius), 0, math.pi, true, Paint()..color = color)
      ..restore()
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * unit,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(unit, 14.6 * unit, 30 * unit, 2.8 * unit), Radius.circular(1.4 * unit)),
        Paint()..color = SeaproofTokens.signal,
      );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color || old.fill != fill;
}
