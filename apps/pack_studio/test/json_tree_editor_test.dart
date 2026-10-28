import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/json_tree_editor.dart';
import 'package:pack_studio/theme.dart';

void main() {
  testWidgets('tapping a number opens the edit dialog and Save reports the new tree', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    dynamic changed;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: JsonTreeEditor(
          value: {'id': 801, 'name': 'Workshop', 'tags': ['a', 'b']},
          onChanged: (v) => changed = v,
        ),
      ),
    ));

    expect(find.text('id'), findsOneWidget);
    expect(find.text('801'), findsOneWidget);

    await tester.tap(find.text('801'));
    await tester.pumpAndSettle();
    expect(find.text('Edit value'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '802');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(changed, {'id': 802, 'name': 'Workshop', 'tags': ['a', 'b']});
    expect((changed as Map).keys.toList(), ['id', 'name', 'tags']); // order kept
    expect(find.text('802'), findsOneWidget);
  });

  testWidgets('a collapsed container expands when tapped', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: JsonTreeEditor(value: {'tags': ['alpha', 'beta']}, onChanged: (_) {}),
      ),
    ));
    expect(find.textContaining('alpha'), findsNothing);
    await tester.tap(find.text('tags'));
    await tester.pumpAndSettle();
    expect(find.textContaining('alpha'), findsOneWidget);
  });
}
