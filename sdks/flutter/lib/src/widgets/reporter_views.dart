import 'package:flutter/material.dart';

import '../controller.dart';
import '../design.dart';
import '../models.dart';
import '../strings.dart';

/// The user's own feedback, and the conversation with the team about one item.
class OwnFeedbackView extends StatefulWidget {
  /// Creates the view.
  const OwnFeedbackView({
    super.key,
    required this.controller,
    required this.strings,
    required this.items,
    required this.onRead,
  });

  /// The SDK state.
  final SeaproofController controller;

  /// Texts.
  final SeaproofStrings strings;

  /// The user's items, newest first.
  final List<OwnFeedback> items;

  /// Called after an item's replies were read, so unread markers can update.
  final VoidCallback onRead;

  @override
  State<OwnFeedbackView> createState() => _OwnFeedbackViewState();
}

class _OwnFeedbackViewState extends State<OwnFeedbackView> {
  final TextEditingController _reply = TextEditingController();
  OwnFeedback? _open;
  OwnFeedbackDetail? _detail;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  SeaproofStrings get _strings => widget.strings;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _openItem(OwnFeedback item) async {
    setState(() {
      _open = item;
      _detail = null;
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.controller.myFeedbackItem(item.id);
      if (!mounted || _open != item) {
        return;
      }

      setState(() => _detail = detail);
      widget.onRead();
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not load feedback ${item.id} ($e).');
      if (mounted) {
        setState(() => _error = _strings.loadFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    final detail = _detail;
    if (body.isEmpty || detail == null) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await widget.controller.sendMessage(detail.id, body);
      if (mounted) {
        _reply.clear();
        setState(() => _detail = detail.withMessage(message));
      }
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not send the answer ($e).');
      if (mounted) {
        setState(() => _error = _strings.failed);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _open == null ? _list(context) : _conversation(context);

  Widget _list(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final item in widget.items)
          ListTile(
            key: ValueKey('seaproof-own-${item.id}'),
            title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                '#${item.number}',
                _strings.statusLabels[item.status]!,
                if (item.replies > 0) _strings.replies(item.replies),
              ].join(' · '),
            ),
            trailing: widget.controller.hasUnreadReply(item)
                ? Semantics(
                    label: _strings.newReply,
                    child: const Icon(Icons.circle, size: 10, color: SeaproofTokens.signal),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _openItem(item),
          ),
      ],
    );
  }

  Widget _conversation(BuildContext context) {
    final theme = Theme.of(context);
    final item = _open!;
    final detail = _detail;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const BackButtonIcon(),
                tooltip: _strings.back,
                onPressed: _sending ? null : () => setState(() => _open = null),
              ),
              Expanded(child: Text(item.title, style: theme.textTheme.titleMedium, maxLines: 2)),
              StatusBadge(
                status: detail?.status ?? item.status,
                label: _strings.statusLabels[detail?.status ?? item.status]!,
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: [
              if (_loading)
                const Center(
                  child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                ),
              if (detail != null) ...[
                _Bubble(author: _strings.fromYou, body: detail.description, mine: true),
                for (final m in detail.messages)
                  _Bubble(author: m.fromTeam ? _strings.fromTeam : _strings.fromYou, body: m.body, mine: !m.fromTeam),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
            ],
          ),
        ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('seaproof-reply'),
                    controller: _reply,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 5000,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: _strings.reply, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('seaproof-reply-send'),
                  onPressed: _sending ? null : _send,
                  child: Text(_sending ? _strings.sending : _strings.send),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.author, required this.body, required this.mine});

  final String author;
  final String body;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Yours on the right in the primary colour, the team's on the left; the pointed corner shows who spoke.
    const round = Radius.circular(16);
    const point = Radius.circular(4);
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(author, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: mine ? scheme.primary : scheme.surface,
                border: mine ? null : Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadiusDirectional.only(
                  topStart: mine ? round : point,
                  topEnd: mine ? point : round,
                  bottomStart: round,
                  bottomEnd: round,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(body, style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A public status as a small pill, coloured for the statuses that mean progress.
class StatusBadge extends StatelessWidget {
  /// Creates the badge.
  const StatusBadge({super.key, required this.status, required this.label});

  /// The status.
  final PublicStatus status;

  /// Its text.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = SeaproofTokens.statusColors(status, theme.brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors?.tint ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors?.tone ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The ideas the team published, where the user votes.
class IdeasView extends StatefulWidget {
  /// Creates the view.
  const IdeasView({
    super.key,
    required this.controller,
    required this.strings,
    required this.ideas,
    required this.onSuggest,
  });

  /// The SDK state.
  final SeaproofController controller;

  /// Texts.
  final SeaproofStrings strings;

  /// The published ideas, most voted first.
  final List<PublicIdea> ideas;

  /// Opens the form to suggest a new idea.
  final VoidCallback onSuggest;

  @override
  State<IdeasView> createState() => _IdeasViewState();
}

class _IdeasViewState extends State<IdeasView> {
  late List<PublicIdea> _ideas = widget.ideas;
  final Set<String> _pending = {};

  @override
  void didUpdateWidget(IdeasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.ideas, widget.ideas)) {
      _ideas = widget.ideas;
    }
  }

  void _replace(PublicIdea idea) => _ideas = [for (final i in _ideas) i.id == idea.id ? idea : i];

  // Optimistic: the count changes at once and is restored if the API refuses.
  Future<void> _toggle(PublicIdea idea) async {
    final value = !idea.voted;
    setState(() {
      _pending.add(idea.id);
      _replace(idea.withVote(value: value));
    });
    try {
      await (value ? widget.controller.vote(idea.id) : widget.controller.unvote(idea.id));
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not change the vote ($e).');
      if (mounted) {
        setState(() => _replace(idea));
      }
    } finally {
      if (mounted) {
        setState(() => _pending.remove(idea.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = widget.strings;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        for (final idea in _ideas)
          Padding(
            key: ValueKey('seaproof-idea-${idea.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VoteButton(
                  idea: idea,
                  label: strings.voteLabel(idea),
                  onPressed: _pending.contains(idea.id) ? null : () => _toggle(idea),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(idea.title, style: theme.textTheme.titleSmall),
                      if (idea.summary case final summary? when summary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(summary, style: theme.textTheme.bodyMedium),
                      ],
                      if (idea.status != PublicStatus.received) ...[
                        const SizedBox(height: 6),
                        StatusBadge(status: idea.status, label: strings.statusLabels[idea.status]!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: widget.onSuggest,
          icon: Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: SeaproofTokens.typeColors(FeedbackType.idea, theme.brightness).tone,
          ),
          label: Text(strings.suggestIdea),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.idea, required this.label, required this.onPressed});

  final PublicIdea idea;
  final String label;
  final VoidCallback? onPressed;

  static final _style = ButtonStyle(
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
    minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  @override
  Widget build(BuildContext context) {
    // The button reads as "Vote for X, 4 votes" rather than "4".
    final child = Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [const Icon(Icons.keyboard_arrow_up, size: 20), Text('${idea.votes}')],
        ),
      ),
    );
    return idea.voted
        ? FilledButton(onPressed: onPressed, style: _style, child: child)
        : OutlinedButton(onPressed: onPressed, style: _style, child: child);
  }
}
