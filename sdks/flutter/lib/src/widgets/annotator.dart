import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design.dart';
import '../strings.dart';

/// What a drag on the screenshot does.
enum MarkTool {
  /// A rounded box around what matters.
  box,

  /// An arrow from where the drag starts to where it ends.
  arrow,

  /// A free line.
  pen,

  /// A filled box over something private.
  hide,
}

/// One mark on a screenshot, in the image's own pixels.
@immutable
class ScreenshotMark {
  /// Creates a mark.
  const ScreenshotMark(this.tool, this.points);

  /// How it is drawn.
  final MarkTool tool;

  /// For [MarkTool.pen] every point of the line; otherwise the start and the end of the drag.
  final List<Offset> points;
}

/// Lets the user mark up a screenshot: circle what matters, point at it, draw, or hide what is private.
class ScreenshotAnnotator extends StatefulWidget {
  /// Creates the view for [image].
  const ScreenshotAnnotator({
    super.key,
    required this.image,
    required this.strings,
    required this.onDone,
    required this.onCancel,
    this.penColor = defaultPenColor,
    this.hideFirst = false,
  });

  /// The default colour of the marks: Seaproof's signal orange.
  static const Color defaultPenColor = SeaproofTokens.signal;

  /// The screenshot.
  final ui.Image image;

  /// Texts.
  final SeaproofStrings strings;

  /// Called with the marked-up PNG and how many areas were hidden.
  final void Function(Uint8List png, int hidden) onDone;

  /// Called when the user leaves without changes.
  final VoidCallback onCancel;

  /// Colour of the marks.
  final Color penColor;

  /// Start with the hide tool. End users are more likely than testers to have something private on screen.
  final bool hideFirst;

  /// Renders [image] with [marks] to PNG.
  static Future<Uint8List> render(
    ui.Image image,
    List<ScreenshotMark> marks, {
    Color penColor = defaultPenColor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawImage(image, Offset.zero, Paint());
    _paintMarks(canvas, marks, _strokeWidthFor(image), penColor);
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image.width, image.height);
    picture.dispose();
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    return bytes!.buffer.asUint8List();
  }

  static double _strokeWidthFor(ui.Image image) => (image.width / 120).clamp(3, 12);

  static void _paintMarks(Canvas canvas, List<ScreenshotMark> marks, double width, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final mark in marks) {
      final a = mark.points.first;
      final b = mark.points.last;
      switch (mark.tool) {
        case MarkTool.hide:
          canvas.drawRect(Rect.fromPoints(a, b), Paint()..color = SeaproofTokens.ink);
        case MarkTool.box:
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(a, b), Radius.circular(width * 2)), paint);
        case MarkTool.arrow:
          final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
          final head = width * 5;
          Offset wing(double turn) => b - Offset(head * math.cos(angle + turn), head * math.sin(angle + turn));
          canvas.drawPath(
            Path()
              ..moveTo(a.dx, a.dy)
              ..lineTo(b.dx, b.dy)
              ..moveTo(wing(-math.pi / 6).dx, wing(-math.pi / 6).dy)
              ..lineTo(b.dx, b.dy)
              ..lineTo(wing(math.pi / 6).dx, wing(math.pi / 6).dy),
            paint,
          );
        case MarkTool.pen:
          if (mark.points.length == 1) {
            canvas.drawCircle(a, width / 2, Paint()..color = color);
          } else {
            canvas.drawPath(Path()..addPolygon(mark.points, false), paint);
          }
      }
    }
  }

  @override
  State<ScreenshotAnnotator> createState() => _ScreenshotAnnotatorState();
}

class _ScreenshotAnnotatorState extends State<ScreenshotAnnotator> {
  final List<ScreenshotMark> _marks = [];
  late MarkTool _tool = _tools.first;
  bool _rendering = false;

  List<MarkTool> get _tools => widget.hideFirst
      ? const [MarkTool.hide, MarkTool.box, MarkTool.arrow, MarkTool.pen]
      : const [MarkTool.box, MarkTool.arrow, MarkTool.pen, MarkTool.hide];

  Future<void> _done() async {
    if (_marks.isEmpty) {
      widget.onCancel();
      return;
    }

    setState(() => _rendering = true);
    final png = await ScreenshotAnnotator.render(widget.image, _marks, penColor: widget.penColor);
    widget.onDone(png, _marks.where((m) => m.tool == MarkTool.hide).length);
  }

  void _start(Offset point) => setState(() => _marks.add(ScreenshotMark(_tool, [point])));

  void _update(Offset point) => setState(() {
    final mark = _marks.removeLast();
    _marks.add(
      ScreenshotMark(mark.tool, mark.tool == MarkTool.pen ? [...mark.points, point] : [mark.points.first, point]),
    );
  });

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.close), tooltip: strings.cancel, onPressed: widget.onCancel),
              Expanded(child: Text(strings.annotateTitle, style: theme.textTheme.titleMedium)),
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: strings.undo,
                onPressed: _marks.isEmpty ? null : () => setState(_marks.removeLast),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _rendering ? null : _done,
                child: Text(_marks.isEmpty ? strings.close : strings.applyScreenshotEdits),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final image = widget.image;
                final scale = math.min(constraints.maxWidth / image.width, constraints.maxHeight / image.height);
                final size = Size(image.width * scale, image.height * scale);
                Offset toImage(Offset local) => Offset(
                  (local.dx / scale).clamp(0, image.width.toDouble()),
                  (local.dy / scale).clamp(0, image.height.toDouble()),
                );

                return Center(
                  child: SizedBox.fromSize(
                    size: size,
                    child: GestureDetector(
                      key: const ValueKey('seaproof-annotation-canvas'),
                      onPanStart: (d) => _start(toImage(d.localPosition)),
                      onPanUpdate: (d) => _update(toImage(d.localPosition)),
                      onTapUp: _tool == MarkTool.pen ? (d) => _start(toImage(d.localPosition)) : null,
                      child: CustomPaint(
                        painter: _AnnotationPainter(
                          image,
                          _marks,
                          scale,
                          ScreenshotAnnotator._strokeWidthFor(image),
                          widget.penColor,
                        ),
                        size: size,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final tool in _tools)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _ToolButton(
                      key: ValueKey('seaproof-tool-${tool.name}'),
                      icon: switch (tool) {
                        MarkTool.box => Icons.crop_square,
                        MarkTool.arrow => Icons.north_east,
                        MarkTool.pen => Icons.edit_outlined,
                        MarkTool.hide => Icons.visibility_off_outlined,
                      },
                      label: switch (tool) {
                        MarkTool.box => strings.toolBox,
                        MarkTool.arrow => strings.toolArrow,
                        MarkTool.pen => strings.toolPen,
                        MarkTool.hide => strings.toolHide,
                      },
                      selected: _tool == tool,
                      onPressed: () => setState(() => _tool = tool),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter(this.image, this.marks, this.scale, this.strokeWidth, this.color);

  final ui.Image image;
  final List<ScreenshotMark> marks;
  final double scale;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(scale);
    paintImage(
      canvas: canvas,
      rect: Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      image: image,
      filterQuality: FilterQuality.medium,
    );
    ScreenshotAnnotator._paintMarks(canvas, marks, strokeWidth, color);
    canvas.restore();
  }

  // The list changes in place, so always repaint.
  @override
  bool shouldRepaint(_AnnotationPainter oldDelegate) => true;
}
