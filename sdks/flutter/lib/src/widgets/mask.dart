import 'package:flutter/widgets.dart';

/// Hides its child in screenshots, for example card numbers or personal data.
///
/// The child is shown as usual in the app; only the captured screenshot is blacked out.
class SeaproofMask extends StatefulWidget {
  /// Masks [child].
  const SeaproofMask({super.key, required this.child});

  /// What to hide.
  final Widget child;

  @override
  State<SeaproofMask> createState() => _SeaproofMaskState();
}

class _SeaproofMaskState extends State<SeaproofMask> {
  final GlobalKey _key = GlobalKey();
  MaskRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = MaskScope.maybeOf(context);
    if (registry != _registry) {
      _registry?.remove(_key);
      _registry = registry?..add(_key);
    }
  }

  @override
  void dispose() {
    _registry?.remove(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

/// The masks under one [SeaproofHost].
final class MaskRegistry {
  final Set<GlobalKey> _keys = {};

  /// Registers a mask.
  void add(GlobalKey key) => _keys.add(key);

  /// Unregisters a mask.
  void remove(GlobalKey key) => _keys.remove(key);

  /// The masked areas in [ancestor]'s coordinates.
  List<Rect> rectsIn(RenderObject ancestor) => [
    for (final key in _keys)
      if (key.currentContext?.findRenderObject() case final RenderBox box when box.attached && box.hasSize)
        box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size,
  ];
}

/// Gives [SeaproofMask]s their host's registry.
class MaskScope extends InheritedWidget {
  /// Creates a scope.
  const MaskScope({super.key, required this.registry, required super.child});

  /// The registry.
  final MaskRegistry registry;

  /// The nearest registry, if any.
  static MaskRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MaskScope>()?.registry;

  @override
  bool updateShouldNotify(MaskScope oldWidget) => registry != oldWidget.registry;
}
