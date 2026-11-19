import 'package:circuit_calc/core/model/circuit_branch.dart';
import 'package:circuit_calc/main.dart';
import 'package:circuit_calc/ui/widgets/element_editor_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('CircuitCalcApp mobile layout renders and expands detailed steps',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CircuitCalcApp());
    await tester.pumpAndSettle();

    expect(find.text('CircuitCalc'), findsOneWidget);
    expect(find.text('Рассчитать →'), findsOneWidget);

    // Switch to 'Решение' tab on 800x600 test viewport
    await tester.tap(find.text('Решение'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    final toggleBtn = find.text('Показать подробное решение');
    expect(toggleBtn, findsOneWidget);

    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    expect(find.text('Скрыть подробное решение'), findsOneWidget);
  });

  testWidgets('CircuitCalcApp desktop workstation layout renders dual-pane',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CircuitCalcApp());
    await tester.pumpAndSettle();

    expect(find.text('CircuitCalc'), findsOneWidget);
    expect(find.text('Рассчитать'), findsOneWidget);
    expect(find.text('Результаты расчёта'), findsOneWidget);
    expect(find.text('Баланс мощностей сошёлся'), findsOneWidget);
  });

  testWidgets('ElementEditorDialog preserves L/C values and validates invalid input',
      (WidgetTester tester) async {
    const branch = CircuitBranch(
      id: 'bL',
      name: 'L1',
      fromNodeId: 'n1',
      toNodeId: 'n0',
      rOhm: 8,
      lHenry: 0.05,
    );
    ElementEditorResult? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await showDialog<ElementEditorResult>(
                    context: context,
                    builder: (_) => const ElementEditorDialog(
                      branch: branch,
                      isAc: true,
                      frequencyHz: 100,
                      isTargetBranch: false,
                      fromLabel: '1',
                      toLabel: '0',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.branch.lHenry, 0.05);
    expect(saved!.branch.xlOhmOverride, isNull);

    saved = null;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Сопротивление R (Ом)'), '1e-3x');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Введите корректное число'), findsOneWidget);
    expect(saved, isNull);
  });
}
