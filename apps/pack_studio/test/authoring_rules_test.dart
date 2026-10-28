import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/record_form.dart';
import 'package:pack_studio/schema.dart';
import 'package:pack_studio/theme.dart';

/// REQ-01 (description limits), REQ-02 (location types), REQ-04 (Work), REQ-09 (dates).
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
      openJson: (title, value) async => null,
    ),
  );
}

Future<void> pump(WidgetTester tester, RecordSpec spec, Map<String, dynamic> initial, ValueChanged<Map<String, dynamic>> onRecord) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: Scaffold(body: _Host(spec, initial, onRecord))));
}

void main() {
  group('REQ-02 location types', () {
    test('every option has the requested name and states its effect', () {
      final labels = {for (final c in locationTypeChoices(const PackTuning())) c.value: c.label};
      expect(labels, {
        'none': 'Basic (no additional bonus)',
        'sleep': 'Rest (+3 Sleep stamina)',
        'school': 'School (no additional bonus)',
        'exercise': 'Workout (no additional bonus)',
        'partTimeJob': 'Work (no additional bonus)',
        'study': 'Study (no additional bonus)',
      });
    });

    test('the Rest effect follows the pack\'s own rules', () {
      final tuning = PackTuning.fromRules({
        'day': {'sleepRestoresHp': 12, 'sleepLocationBonusHp': 4},
      });
      final rest = locationTypeChoices(tuning).firstWhere((c) => c.value == 'sleep');
      expect(rest.label, 'Rest (+4 Sleep stamina)');
      expect(rest.help, contains('12 + 4 = 16'));
      // Rules with no day section fall back to the engine defaults: 10, +3.
      expect(PackTuning.fromRules({}).sleepLocationBonusHp, 3);
      expect(PackTuning.fromRules({}).sleepRestoresHp, 10);
    });

    testWidgets('the dropdown shows the effects', (tester) async {
      await pump(tester, locationRecordFor(const PackTuning()), {'id': 1, 'name': 'Room', 'type': 'none'}, (_) {});
      await tester.tap(find.byKey(const ValueKey('field:type')));
      await tester.pumpAndSettle();
      expect(find.text('Rest (+3 Sleep stamina)'), findsOneWidget);
      expect(find.text('Workout (no additional bonus)'), findsOneWidget);
    });
  });

  testWidgets('REQ-04: the work action is called Work, and still stores partTimeJob', (tester) async {
    expect(actionTypes.firstWhere((c) => c.value == 'partTimeJob').label, 'Work');
    final spec = locationRecordFor(const PackTuning());
    final title = spec.fields.firstWhere((f) => f.key == 'actions').item!.title({'locationActionType': 'partTimeJob'});
    expect(title, 'Work'); // the default action label
  });

  group('REQ-01 description limits', () {
    testWidgets('a live counter shows the maximum', (tester) async {
      await pump(tester, locationRecordFor(const PackTuning()), {'id': 1, 'name': 'Room', 'description': 'A quiet room'}, (_) {});
      expect(find.text('12 / 38'), findsOneWidget);
      expect(find.textContaining('Limit: 38 characters'), findsOneWidget);
    });

    testWidgets('typing past the limit is refused with an explanation', (tester) async {
      Map<String, dynamic>? latest;
      await pump(tester, locationRecordFor(const PackTuning()), {'id': 1, 'name': 'Room', 'description': 'x' * 30}, (r) => latest = r);
      await tester.enterText(find.byKey(const ValueKey('field:description')), 'x' * 39);
      await tester.pump();
      expect(latest, isNull); // nothing was saved
      expect(find.textContaining('past the limit of 38'), findsOneWidget);
      // Exactly at the limit is fine.
      await tester.enterText(find.byKey(const ValueKey('field:description')), 'y' * 38);
      await tester.pump();
      expect(latest!['description'], 'y' * 38);
    });

    testWidgets('existing over-long text is kept and flagged, and can be shortened', (tester) async {
      Map<String, dynamic>? latest;
      final long = 'z' * 60;
      await pump(tester, locationRecordFor(const PackTuning()), {'id': 1, 'name': 'Room', 'description': long}, (r) => latest = r);
      expect(find.text('60 / 38'), findsOneWidget);
      expect(find.textContaining('Longer than the game can show'), findsOneWidget);
      expect(latest, isNull); // opening the form changed nothing
      await tester.enterText(find.byKey(const ValueKey('field:description')), 'z' * 50);
      await tester.pump();
      expect(latest!['description'], 'z' * 50); // shortening is allowed, still flagged
      expect(find.textContaining('Longer than the game can show'), findsOneWidget);
    });

    testWidgets('trait descriptions have their own limit and never hold a line break', (tester) async {
      Map<String, dynamic>? latest;
      await pump(tester, traitRecord, {'id': 1, 'name': 'Calm', 'description': 'Steady'}, (r) => latest = r);
      expect(find.text('6 / 41'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field:description')), 'Steady\nhands');
      await tester.pump();
      // Flutter's single-line field already drops pasted line breaks; either way none is stored.
      expect((latest?['description'] ?? '') as String, isNot(contains('\n')));
      await tester.enterText(find.byKey(const ValueKey('field:description')), 'w' * 42);
      await tester.pump();
      expect(find.textContaining('past the limit of 41'), findsOneWidget);
    });

    test('limits come from the layout, one per bounded description spot', () {
      expect(locationDescriptionLimit.maxChars, isNot(traitDescriptionLimit.maxChars));
      expect(locationDescriptionLimit.why, contains('2 lines'));
      expect(traitDescriptionLimit.why, contains('3 lines'));
    });
  });

  group('REQ-09 calendar dates', () {
    Map<String, dynamic> pack0() => {
      'id': 'p',
      'name': 'P',
      'calendar': {'startDate': 'DATE_2023101615', 'endDate': 'DATE_2023111600', 'ticksPerDay': 15},
    };

    testWidgets('existing dates are shown as YYYY/MM/DD', (tester) async {
      await pump(tester, packInfoRecord, pack0(), (_) {});
      final start = tester.widget<TextField>(find.byKey(const ValueKey('field:startDate')));
      final end = tester.widget<TextField>(find.byKey(const ValueKey('field:endDate')));
      expect(start.controller!.text, '2023/10/16');
      expect(end.controller!.text, '2023/11/16');
    });

    testWidgets('typing a date stores the internal form, keeping the time slot and other settings', (tester) async {
      Map<String, dynamic>? latest;
      await pump(tester, packInfoRecord, pack0(), (r) => latest = r);
      await tester.enterText(find.byKey(const ValueKey('field:startDate')), '2026/10/28');
      await tester.pump();
      final calendar = latest!['calendar'] as Map;
      expect(calendar['startDate'], 'DATE_2026102815'); // slot 15 kept
      expect(calendar['endDate'], 'DATE_2023111600');
      expect(calendar['ticksPerDay'], 15);
    });

    testWidgets('real-date validation: month lengths, leap years, and format', (tester) async {
      Map<String, dynamic>? latest;
      await pump(tester, packInfoRecord, pack0(), (r) => latest = r);
      final box = find.byKey(const ValueKey('field:endDate'));

      await tester.enterText(box, '2025/02/29'); // 2025 is not a leap year
      await tester.pump();
      expect(find.text('That month has 28 days in 2025.'), findsOneWidget);
      expect(latest, isNull);

      await tester.enterText(box, '2024/02/29'); // 2024 is
      await tester.pump();
      expect((latest!['calendar'] as Map)['endDate'], 'DATE_2024022900');

      await tester.enterText(box, '2024/13/01');
      await tester.pump();
      expect(find.text('The month must be between 1 and 12.'), findsOneWidget);

      await tester.enterText(box, 'tomorrow');
      await tester.pump();
      expect(find.text('Write the date as YYYY/MM/DD, for example 2026/10/28.'), findsOneWidget);
      expect((latest!['calendar'] as Map)['endDate'], 'DATE_2024022900'); // last good value kept
    });

    testWidgets('a short month/day is accepted and does not get rewritten under the cursor', (tester) async {
      await pump(tester, packInfoRecord, pack0(), (_) {});
      final box = find.byKey(const ValueKey('field:startDate'));
      await tester.enterText(box, '2026/1/5');
      await tester.pump();
      expect(tester.widget<TextField>(box).controller!.text, '2026/1/5');
    });
  });
}
