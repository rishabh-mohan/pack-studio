import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/record_form.dart';
import 'package:pack_studio/schema.dart';
import 'package:pack_studio/theme.dart';

/// Hosts a form the way the editor screen does: the latest record is fed back in.
class _Host extends StatefulWidget {
  const _Host({required this.spec, required this.initial, required this.onRecord});

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
      openJson: (title, value) async => null,
    ),
  );
}

Future<void> pumpForm(
  WidgetTester tester,
  RecordSpec spec,
  Map<String, dynamic> initial,
  ValueChanged<Map<String, dynamic>> onRecord,
) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: Scaffold(body: _Host(spec: spec, initial: initial, onRecord: onRecord)),
  ));
}

Map<String, dynamic> workshop() => {
  'id': 801,
  'name': 'Workshop',
  'type': 'none',
  'futureField': 7, // a key the form knows nothing about
  'actions': [
    {'locationActionType': 'sleep'},
    {'locationActionType': 'study'},
  ],
};

void main() {
  testWidgets('a location is a form with friendly names, not JSON', (tester) async {
    await pumpForm(tester, locationRecord, workshop(), (_) {});
    expect(find.byKey(const ValueKey('field:name')), findsOneWidget);
    expect(find.text('Kind of place'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget); // action cards use friendly names
    expect(find.text('Study'), findsOneWidget);
    expect(find.textContaining('locationActionType'), findsNothing);
    expect(find.textContaining('{'), findsNothing);
  });

  testWidgets('editing the name keeps unknown fields and the key order', (tester) async {
    Map<String, dynamic>? latest;
    await pumpForm(tester, locationRecord, workshop(), (r) => latest = r);
    await tester.enterText(find.byKey(const ValueKey('field:name')), 'Studio');
    await tester.pump();
    expect(latest!['name'], 'Studio');
    expect(latest!['futureField'], 7);
    expect(latest!.keys.toList(), ['id', 'name', 'type', 'futureField', 'actions']);
  });

  testWidgets('choosing Rest as the kind of place stores "sleep"', (tester) async {
    Map<String, dynamic>? latest;
    await pumpForm(tester, locationRecord, workshop(), (r) => latest = r);
    await tester.tap(find.byKey(const ValueKey('field:type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest (+3 Sleep stamina)').last);
    await tester.pumpAndSettle();
    expect(latest!['type'], 'sleep');
  });

  testWidgets('adding an action first asks which kind', (tester) async {
    Map<String, dynamic>? latest;
    await pumpForm(tester, locationRecord, workshop(), (r) => latest = r);
    await tester.ensureVisible(find.byKey(const ValueKey('add:actions')));
    await tester.tap(find.byKey(const ValueKey('add:actions')));
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    final actions = latest!['actions'] as List;
    expect(actions.length, 3);
    expect((actions.last as Map)['locationActionType'], 'partTimeJob');
    expect(actions.first, {'locationActionType': 'sleep'}); // untouched
  });

  testWidgets('deleting an action asks first, then removes only that action', (tester) async {
    Map<String, dynamic>? latest;
    await pumpForm(tester, locationRecord, workshop(), (r) => latest = r);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete this action?'), findsOneWidget);
    expect(latest, isNull); // nothing happened yet
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(latest!['actions'], [
      {'locationActionType': 'study'},
    ]);
  });

  testWidgets('a toggle writes a bool; clearing an optional number removes the key', (tester) async {
    Map<String, dynamic>? latest;
    await pumpForm(tester, traitRecord, {'id': 1, 'name': 'Calm', 'initialLifeTime': 5, 'gachable': false}, (r) => latest = r);
    await tester.tap(find.byKey(const ValueKey('field:gachable')));
    await tester.pump();
    expect(latest!['gachable'], true);
    await tester.enterText(find.byKey(const ValueKey('field:initialLifeTime')), '');
    await tester.pump();
    expect(latest!.containsKey('initialLifeTime'), isFalse);
    await tester.enterText(find.byKey(const ValueKey('field:initialLifeTime')), 'abc');
    await tester.pump();
    expect(find.text('Enter a whole number'), findsOneWidget);
  });
}
