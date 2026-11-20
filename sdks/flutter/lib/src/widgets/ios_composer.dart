import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Uses UIKit's edit menu and responder chain for text and image paste.
class IosComposer extends StatefulWidget {
  /// Connects the native field to the report draft.
  const IosComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onImage,
    this.enabled = true,
    this.onFocus,
    this.maxLength = 10000,
  });

  /// The report's text draft.
  final TextEditingController controller;

  /// The text displayed while the draft is empty.
  final String hint;

  /// Delivers a pasted PNG, or null if the image could not be read.
  final ValueChanged<Uint8List?> onImage;

  /// Allows editing the draft.
  final bool enabled;

  /// Called when the native editor becomes first responder.
  final VoidCallback? onFocus;

  /// Maximum length supported by the message endpoint.
  final int maxLength;

  @override
  State<IosComposer> createState() => IosComposerState();
}

/// Keeps the text draft and the per-view UIKit responder in sync.
class IosComposerState extends State<IosComposer> {
  static const _viewType = 'io.seaproof/composer';
  MethodChannel? _channel;
  Map<String, Object>? _settings;
  String? _nativeText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateText);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  /// Releases the native editor's keyboard focus.
  Future<void> dismissKeyboard() async {
    await _channel?.invokeMethod<void>('blur');
  }

  void _updateText() {
    final value = widget.controller.text;
    if (_nativeText != value) {
      _nativeText = value;
      unawaited(_channel?.invokeMethod<void>('setText', value));
    }
  }

  void _onCreated(int id) {
    if (!mounted) {
      return;
    }
    _channel = MethodChannel('$_viewType/$id')..setMethodCallHandler(_handleCall);
    unawaited(_channel?.invokeMethod<void>('configure', _settings));
    _nativeText = null;
    _updateText();
  }

  Future<void> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'edit':
        final text = call.arguments as String;
        _nativeText = text;
        widget.controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      case 'pasteImage':
        widget.onImage(call.arguments as Uint8List?);
      case 'focus':
        widget.onFocus?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final direction = Directionality.of(context);
    final size = MediaQuery.textScalerOf(context).scale(theme.textTheme.bodyLarge?.fontSize ?? 16);
    final settings = {
      'hint': widget.hint,
      'fontSize': size,
      'foreground': scheme.onSurface.toARGB32(),
      'secondary': scheme.onSurfaceVariant.toARGB32(),
      'accent': scheme.primary.toARGB32(),
      'rtl': direction == TextDirection.rtl,
      'dark': theme.brightness == Brightness.dark,
      'enabled': widget.enabled,
      'maxLength': widget.maxLength,
    };
    if (!mapEquals(_settings, settings)) {
      _settings = settings;
      unawaited(_channel?.invokeMethod<void>('configure', settings));
    }

    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder(
        valueListenable: widget.controller,
        builder: (context, draft, view) {
          final painter = TextPainter(
            text: TextSpan(
              text: draft.text.isEmpty ? ' ' : draft.text,
              style: TextStyle(fontSize: size, height: 1.25),
            ),
            textDirection: direction,
            maxLines: 5,
          )..layout(maxWidth: (constraints.maxWidth - 24).clamp(0, double.infinity));
          final height = painter.height;
          painter.dispose();
          return SizedBox(height: height + 16, child: view);
        },
        child: UiKitView(
          viewType: _viewType,
          layoutDirection: direction,
          creationParams: {...settings, 'text': widget.controller.text},
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: const {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
          onPlatformViewCreated: _onCreated,
        ),
      ),
    );
  }
}
