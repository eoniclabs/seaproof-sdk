import 'package:flutter/material.dart';

import '../design.dart';
import '../models.dart';
import '../strings.dart';
import 'reporter_views.dart';

/// Known problems and public ideas like the draft. A known problem can be linked ("same
/// problem"), an idea voted for; either way the user can still send.
class SuggestionList extends StatelessWidget {
  /// Creates the list.
  const SuggestionList({
    super.key,
    required this.suggestions,
    required this.voted,
    required this.strings,
    required this.onLink,
    required this.onVote,
  });

  /// Best first.
  final List<Suggestion> suggestions;

  /// Ideas voted for from this panel.
  final Set<String> voted;

  /// Texts.
  final SeaproofStrings strings;

  /// Links the report to a known problem.
  final ValueChanged<Suggestion> onLink;

  /// Votes for an idea, or takes the vote back.
  final ValueChanged<Suggestion> onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ideasOnly = suggestions.every((s) => s.type == FeedbackType.idea);
    return _Box(
      key: const ValueKey('seaproof-suggestions'),
      title: ideasOnly ? strings.similarIdeasTitle : strings.suggestionsTitle,
      children: [
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    SeaproofTokens.typeIcon(s.type),
                    size: 18,
                    color: SeaproofTokens.typeColors(s.type, theme.brightness).tone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (s.summary case final summary?)
                        Text(
                          summary,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (s.status != PublicStatus.received) ...[
                        const SizedBox(height: 4),
                        StatusBadge(status: s.status, label: strings.statusLabels[s.status]!),
                      ],
                    ],
                  ),
                ),
                if (s.type == FeedbackType.idea)
                  _VoteButton(suggestion: s, voted: voted.contains(s.id), strings: strings, onPressed: () => onVote(s))
                else
                  TextButton(
                    key: ValueKey('seaproof-same-${s.id}'),
                    onPressed: () => onLink(s),
                    child: Text(strings.sameProblem),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.suggestion, required this.voted, required this.strings, required this.onPressed});

  final Suggestion suggestion;
  final bool voted;
  final SeaproofStrings strings;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = suggestion.votes + (voted ? 1 : 0);
    final label = (voted ? strings.removeVote : strings.voteFor)
        .replaceAll('{title}', suggestion.title)
        .replaceAll('{count}', '$count');
    final button = voted
        ? FilledButton(onPressed: onPressed, child: Text('▲ $count'))
        : OutlinedButton(onPressed: onPressed, child: Text('▲ $count'));
    return Semantics(button: true, label: label, excludeSemantics: true, child: button);
  }
}

/// A sunken box with a small heading, like the tab track.
class _Box extends StatelessWidget {
  const _Box({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? theme.colorScheme.surfaceContainerLowest : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
