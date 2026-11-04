import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../strings.dart';

/// A discreet way into the feedback panel, for a menu, settings page or help screen.
///
/// In production, this (or your own widget calling [Seaproof.show]) is how end users find
/// the panel, since no shake or floating button is shown there by default.
class SeaproofFeedbackButton extends StatelessWidget {
  /// A text button with an icon.
  const SeaproofFeedbackButton({super.key, this.type, this.label, this.controller}) : _tile = false;

  /// A list tile, for menus and settings lists.
  const SeaproofFeedbackButton.listTile({super.key, this.type, this.label, this.controller}) : _tile = true;

  /// The type to preselect, for example [FeedbackType.idea] for "Suggest a feature".
  final FeedbackType? type;

  /// The text. Defaults to "Send feedback" in the app's language.
  final String? label;

  /// The controller, or [Seaproof.instance] when null.
  final SeaproofController? controller;

  final bool _tile;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? Seaproof.instance;
    final text =
        label ??
        SeaproofStrings.forLocale(controller.config.locale ?? Localizations.maybeLocaleOf(context)).openFeedback;
    void open() => controller.show(type: type);

    return _tile
        ? ListTile(leading: const Icon(Icons.rate_review_outlined), title: Text(text), onTap: open)
        : TextButton.icon(onPressed: open, icon: const Icon(Icons.rate_review_outlined), label: Text(text));
  }
}
