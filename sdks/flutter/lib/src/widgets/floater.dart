import 'package:flutter/material.dart';

/// A small round button that can be dragged and snaps to the nearest side.
class SeaproofFloater extends StatefulWidget {
  /// Creates the button.
  const SeaproofFloater({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
    this.icon = Icons.chat_bubble_outline,
    this.themeData,
  });

  /// Opens the panel.
  final VoidCallback onPressed;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Diameter of the button.
  final double size;

  /// The icon.
  final IconData icon;

  /// Theme for the button, so Seaproof's colours apply without restyling the app.
  final ThemeData? themeData;

  @override
  State<SeaproofFloater> createState() => _SeaproofFloaterState();
}

class _SeaproofFloaterState extends State<SeaproofFloater> {
  static const double _margin = 12;

  // Kept across rebuilds so the button stays where the user put it.
  static Offset? _lastPosition;

  Offset? _position;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = media.padding;
    final area = media.size;
    final minX = padding.left + _margin;
    final maxX = area.width - padding.right - _margin - widget.size;
    final minY = padding.top + _margin;
    final maxY = area.height - padding.bottom - _margin - widget.size;
    if (maxX < minX || maxY < minY) {
      return const SizedBox.shrink();
    }

    final position = _clamp(_position ?? _lastPosition ?? Offset(maxX, maxY * 0.75), minX, maxX, minY, maxY);
    final scheme = (widget.themeData ?? Theme.of(context)).colorScheme;

    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() => _position = _clamp(position + d.delta, minX, maxX, minY, maxY)),
        onPanEnd: (_) => setState(() {
          _dragging = false;
          final snapped = Offset(position.dx + widget.size / 2 < area.width / 2 ? minX : maxX, position.dy);
          _position = _lastPosition = snapped;
        }),
        child: Tooltip(
          message: widget.tooltip,
          // The icon's label names the button; the tooltip would repeat it.
          excludeFromSemantics: true,
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            elevation: 6,
            // Screen readers announce it as a button, not a group.
            child: Semantics(
              container: true,
              button: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: Icon(
                    widget.icon,
                    size: widget.size / 2,
                    color: scheme.onPrimary,
                    semanticLabel: widget.tooltip,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Offset _clamp(Offset p, double minX, double maxX, double minY, double maxY) =>
      Offset(p.dx.clamp(minX, maxX), p.dy.clamp(minY, maxY));
}
