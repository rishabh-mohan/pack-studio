import 'package:flutter/material.dart';

import 'json_tree_editor.dart';
import 'theme.dart';

/// The advanced editor for one raw value. Completes with the edited value when
/// the author taps Done, or null when they go back.
Future<dynamic> editJsonValue(BuildContext context, String title, dynamic value) {
  return Navigator.of(context).push<dynamic>(
    MaterialPageRoute(builder: (_) => _JsonValueScreen(title: title, value: value)),
  );
}

class _JsonValueScreen extends StatefulWidget {
  const _JsonValueScreen({required this.title, required this.value});

  final String title;
  final dynamic value;

  @override
  State<_JsonValueScreen> createState() => _JsonValueScreenState();
}

class _JsonValueScreenState extends State<_JsonValueScreen> {
  late dynamic _value = widget.value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: StudioColors.accent,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 18)),
        actions: [TextButton(onPressed: () => Navigator.pop(context, _value), child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16)))],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: StudioColors.rule,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              'You are editing only "${widget.title}". Nothing else in this entry changes. Tap Done to keep your edits, or go back to discard them.',
              style: const TextStyle(fontSize: 12, color: StudioColors.inkSoft),
            ),
          ),
          Expanded(
            child: JsonTreeEditor(rootLabel: widget.title, value: _value, onChanged: (v) => _value = v),
          ),
        ],
      ),
    );
  }
}
