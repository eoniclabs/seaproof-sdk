import 'package:flutter/material.dart';

/// A message on the left side of the chat.
class ChatIncomingBubble extends StatelessWidget {
  /// Creates an incoming message with optional next actions.
  const ChatIncomingBubble({
    super.key,
    required this.text,
    this.actions = const [],
    this.icon = Icons.auto_awesome_outlined,
  });

  /// The symbol identifying the sender.
  final IconData icon;

  /// Message text.
  final String text;

  /// Actions shown after the message.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(icon, size: 14, color: scheme.primary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(text),
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: actions),
          ),
      ],
    );
  }
}

/// A message sent by the reporter.
class ChatOutgoingBubble extends StatelessWidget {
  /// Wraps the reporter’s message.
  const ChatOutgoingBubble({super.key, required this.child});

  /// Message content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: scheme.onPrimary),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The reporter’s image preview in the conversation.
class ChatImageBubble extends StatelessWidget {
  /// Shows an image with its description.
  const ChatImageBubble({super.key, required this.image, required this.label, this.onTap});

  /// The thumbnail source.
  final ImageProvider<Object> image;

  /// The image description.
  final String label;

  /// Opens the attachment.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image(
                image: image,
                height: 140,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox(height: 48, child: Icon(Icons.broken_image_outlined)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays an animated screen recording at a readable size.
class ChatRecordingViewer extends StatelessWidget {
  /// Creates the viewer.
  const ChatRecordingViewer({
    super.key,
    required this.image,
    required this.title,
    required this.back,
    required this.loadFailed,
    required this.onClose,
  });

  /// Animated PNG to play.
  final ImageProvider<Object> image;

  /// Heading.
  final String title;

  /// Back button tooltip.
  final String back;

  /// Message displayed when the recording cannot be loaded.
  final String loadFailed;

  /// Returns to the conversation.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        leading: IconButton(icon: const BackButtonIcon(), tooltip: back, onPressed: onClose),
        title: Text(title),
      ),
      Expanded(
        child: InteractiveViewer(
          child: Image(
            image: image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Center(child: Text(loadFailed)),
          ),
        ),
      ),
    ],
  );
}

/// The conversation’s scrollable history, above its pinned composer.
class ChatHistory extends StatelessWidget {
  /// Creates the chat history.
  const ChatHistory({super.key, this.controller, required this.children});

  /// Controls the position in the conversation.
  final ScrollController? controller;

  /// Message bubbles and loading or error states.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = theme.brightness == Brightness.dark ? scheme.surfaceContainerLowest : scheme.surfaceContainerHighest;
    return ColoredBox(
      color: Color.alphaBlend(tint.withValues(alpha: 0.45), scheme.surface),
      child: ListView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: children,
      ),
    );
  }
}

/// The shared outline, editor area, and bottom row of chat actions.
class ChatComposer extends StatelessWidget {
  /// Creates a composer.
  const ChatComposer({super.key, required this.editor, required this.send, this.actions = const [], this.details});

  /// The message editor.
  final Widget editor;

  /// The send action.
  final Widget send;

  /// Optional actions preceding the send control.
  final List<Widget> actions;

  /// Optional controls between the editor and its toolbar.
  final Widget? details;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            editor,
            ?details,
            Row(children: [...actions, const Spacer(), send]),
          ],
        ),
      ),
    ),
  );
}

/// The Flutter text editor shared by the chat and replies.
class ChatTextField extends StatelessWidget {
  /// Creates a message editor.
  const ChatTextField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.onSubmit,
    this.autofocus = false,
    this.enabled = true,
  });

  /// Identifies the editable field.
  final Key fieldKey;

  /// Text draft.
  final TextEditingController controller;

  /// Prompt shown when the field is empty.
  final String hint;

  /// Maximum length supported by this message endpoint.
  final int maxLength;

  /// The keyboard’s send action.
  final VoidCallback onSubmit;

  /// Whether to request focus when mounted.
  final bool autofocus;

  /// Whether the reporter can edit the draft.
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    autofocus: autofocus,
    enabled: enabled,
    minLines: 1,
    maxLines: 5,
    maxLength: maxLength,
    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
    textCapitalization: TextCapitalization.sentences,
    textInputAction: TextInputAction.send,
    onSubmitted: (_) => onSubmit(),
    decoration: InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: InputBorder.none,
    ),
  );
}

/// A tappable attachment preview with an optional remove action.
class ChatAttachmentRow extends StatelessWidget {
  /// Creates the attachment row.
  const ChatAttachmentRow({
    super.key,
    required this.preview,
    required this.title,
    this.removeTooltip,
    this.removeKey,
    this.onRemove,
    this.onTap,
    this.leadingAction = Icons.edit_outlined,
  });

  /// Thumbnail or placeholder.
  final Widget preview;

  /// The visible attachment label.
  final String title;

  /// When present, displays a remove button with this tooltip.
  final String? removeTooltip;

  /// The remove button key.
  final Key? removeKey;

  /// Removes the attachment.
  final VoidCallback? onRemove;

  /// Opens the attachment.
  final VoidCallback? onTap;

  /// The icon that indicates what tapping the row does.
  final IconData leadingAction;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            button: onTap != null,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: preview),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.labelLarge)),
                    if (onTap != null) Icon(leadingAction, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (removeTooltip != null)
          IconButton(
            key: removeKey,
            icon: const Icon(Icons.close, size: 18),
            tooltip: removeTooltip,
            onPressed: onRemove,
          ),
      ],
    ),
  );
}
