/// The one thing d30mode's base layer carries that this engine copy reads: the
/// book-completion reward table every pack shares (a pack's own
/// `book_rewards.json` is ignored). d30mode bundles the table and loads it at
/// start; the editor loads none, so book completion stays off there. Tests
/// inject one with [use]. The items and traits half of d30mode's layer is not
/// mirrored: the editor never plays a run.
library;

import 'dart:convert';

class BaseContent {
  static Map<String, String> _text = const {};

  /// The completion-reward table, or null when none is loaded.
  static Map<String, dynamic>? get bookRewards {
    final text = _text['book_rewards.json'];
    return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
  }

  /// Replaces the loaded files; an empty map removes them.
  static void use(Map<String, String> text) => _text = Map.unmodifiable(text);
}
