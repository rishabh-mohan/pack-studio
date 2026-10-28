import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/json_tree_editor.dart';
import 'package:pack_studio/json_value_screen.dart';
import 'package:pack_studio/record_form.dart';
import 'package:pack_studio/schema.dart';
import 'package:pack_studio/theme.dart';

/// REQ-07: every "(advanced)" control must open exactly the field it belongs to.
class _Host extends StatefulWidget {
  const _Host(this.spec, this.initial, this.onRecord);

  final RecordSpec spec;
  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>> onRecord;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Map<String, dynamic> _value = widget.initial;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: RecordForm(
      spec: widget.spec,
      value: _value,
      onChanged: (r) {
        setState(() => _value = r);
        widget.onRecord(r);
      },
      openJson: (title, value) => editJsonValue(context, title, value),
    ),
  );
}

Future<void> pump(WidgetTester tester, RecordSpec spec, Map<String, dynamic> initial, ValueChanged<Map<String, dynamic>> onRecord) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: Scaffold(body: _Host(spec, initial, onRecord))));
}

dynamic shown(WidgetTester tester) => tester.widget<JsonTreeEditor>(find.byType(JsonTreeEditor)).value;

void main() {
  final character = {
    'id': 70,
    'name': 'Artisan',
    'plusEffect': {'type': 'plusSleepHp', 'plusValue': 2},
  };

  testWidgets('Bonus effect opens the bonus effect, not the whole character', (tester) async {
    await pump(tester, characterRecord, character, (_) {});
    await tester.tap(find.byKey(const ValueKey('field:plusEffect')));
    await tester.pumpAndSettle();
    expect(shown(tester), {'type': 'plusSleepHp', 'plusValue': 2});
    expect(find.text('root'), findsNothing); // the top row is named after the field
    expect(find.textContaining('editing only "Bonus effect"'), findsOneWidget);
  });

  testWidgets('an absent optional effect opens as an empty structure and saves only that key', (tester) async {
    Map<String, dynamic>? latest;
    await pump(tester, characterRecord, {'id': 1, 'name': 'Nobody'}, (r) => latest = r);
    await tester.tap(find.byKey(const ValueKey('field:plusEffect')));
    await tester.pumpAndSettle();
    expect(shown(tester), <String, dynamic>{});
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(latest!['name'], 'Nobody');
    expect(latest!['plusEffect'], <String, dynamic>{});
  });

  testWidgets('a control inside a list entry opens that entry\'s value only', (tester) async {
    final location = {
      'id': 801,
      'name': 'Workshop',
      'actions': [
        {'locationActionType': 'sleep', 'changer': {'funcCode': 'A'}},
        {'locationActionType': 'study', 'changer': {'funcCode': 'B'}},
      ],
    };
    await pump(tester, locationRecord, location, (_) {});
    // Expand the second action card, then open its effects.
    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('field:actions:1/changer')));
    await tester.pumpAndSettle();
    expect(shown(tester), {'funcCode': 'B'});
  });
}
