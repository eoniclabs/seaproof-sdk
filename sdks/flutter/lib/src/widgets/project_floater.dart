import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';

/// The styled launcher used when the project supplies a custom configuration.
class ProjectFloater extends StatelessWidget {
  /// Creates a button with the project's launcher settings.
  const ProjectFloater({
    super.key,
    required this.settings,
    required this.label,
    required this.onPressed,
    required this.theme,
    required this.icon,
    required this.minimumSize,
    this.obstructions = const [],
  });

  /// The position and appearance from the Seaproof project.
  final SeaproofLauncherSettings settings;

  /// The text rendered on the button and read by assistive technology.
  final String label;

  /// Opens the feedback panel.
  final VoidCallback onPressed;

  /// The theme used by the feedback widget.
  final ThemeData theme;

  /// The launcher icon.
  final IconData icon;

  /// The minimum size of the interactive button.
  final double minimumSize;

  /// The controls that the launcher may move to avoid.
  final List<Rect> obstructions;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    const margin = 12.0;
    final edges = EdgeInsets.fromLTRB(
      math.max(padding.left, insets.left) + margin,
      math.max(padding.top, insets.top) + margin,
      math.max(padding.right, insets.right) + margin,
      math.max(padding.bottom, insets.bottom) + margin,
    );
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(999);
    final caption = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelLarge?.copyWith(color: colors.onPrimary),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = edges.deflateSize(constraints.biggest);
        if (area.width < minimumSize || area.height < minimumSize) {
          return const SizedBox.shrink();
        }

        return CustomSingleChildLayout(
          delegate: _FloaterLayout(edges, settings.position, settings.avoidObstructions ? obstructions : const []),
          child: Semantics(
            button: true,
            label: label,
            onTap: onPressed,
            excludeSemantics: true,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: Material(
                color: colors.primary,
                borderRadius: radius,
                elevation: 6,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onPressed,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minimumSize, minHeight: minimumSize),
                    child: Padding(
                      padding: settings.vertical
                          ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8)
                          : const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Flex(
                        direction: settings.vertical ? Axis.vertical : Axis.horizontal,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 8,
                        children: [
                          Icon(icon, size: 20, color: colors.onPrimary),
                          Flexible(child: settings.vertical ? RotatedBox(quarterTurns: 1, child: caption) : caption),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloaterLayout extends SingleChildLayoutDelegate {
  const _FloaterLayout(this.edges, this.preferred, this.obstructions);

  final EdgeInsets edges;
  final SeaproofLauncherPosition? preferred;
  final List<Rect> obstructions;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(edges.deflateSize(constraints.biggest));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final area = edges.deflateRect(Offset.zero & size);
    final available = Size(area.width - childSize.width, area.height - childSize.height);

    Rect at(SeaproofLauncherPosition position) {
      final alignment = switch (position) {
        SeaproofLauncherPosition.topLeft => Alignment.topLeft,
        SeaproofLauncherPosition.middleLeft => Alignment.centerLeft,
        SeaproofLauncherPosition.bottomLeft => Alignment.bottomLeft,
        SeaproofLauncherPosition.topRight => Alignment.topRight,
        SeaproofLauncherPosition.middleRight => Alignment.centerRight,
        SeaproofLauncherPosition.bottomRight => Alignment.bottomRight,
      };
      return (area.topLeft + alignment.alongSize(available)) & childSize;
    }

    double overlapOf(Rect bounds) {
      var overlap = 0.0;
      for (final obstacle in obstructions) {
        final intersection = bounds.intersect(obstacle.inflate(8));
        if (!intersection.isEmpty) {
          overlap += intersection.width * intersection.height;
        }
      }
      return overlap;
    }

    final position = preferred;
    final origin = position == null
        ? (area.topLeft + Offset(available.width, available.height * 0.75)) & childSize
        : at(position);
    var best = origin;
    var bestOverlap = overlapOf(origin);
    if (bestOverlap == 0) {
      return origin.topLeft;
    }

    var bestDistance = 0.0;
    for (final position in SeaproofLauncherPosition.values) {
      final candidate = at(position);
      final overlap = overlapOf(candidate);
      final distance = (candidate.topLeft - origin.topLeft).distanceSquared;
      if (overlap < bestOverlap || (overlap == bestOverlap && distance < bestDistance)) {
        best = candidate;
        bestOverlap = overlap;
        bestDistance = distance;
      }
    }
    return best.topLeft;
  }

  @override
  bool shouldRelayout(_FloaterLayout oldDelegate) =>
      edges != oldDelegate.edges || preferred != oldDelegate.preferred || obstructions != oldDelegate.obstructions;
}
