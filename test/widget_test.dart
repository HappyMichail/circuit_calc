import 'package:circuit_calc/core/model/circuit_branch.dart';
import 'package:circuit_calc/main.dart';
import 'package:circuit_calc/ui/widgets/element_editor_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('CircuitCalcApp renders, switches tabs, and expands detailed steps',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CircuitCalcApp());
    await tester.pumpAndSettle();

    expect(find.text('Калькулятор электрических цепей (ТОЭ)'), findsOneWidget);
    expect(find.text('Рассчитать'), findsOneWidget);

    // On default 800x600 test viewport, switch to 'Решение' tab
    await tester.tap(find.text('Решение'));
    await tester.pumpAndSettle();

    // Scroll the SolutionPanel ListView down to reveal the toggle button
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    final toggleBtn = find.text('Показать подробное решение');
    expect(toggleBtn, findsOneWidget);

    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    expect(find.text('Скрыть подробное решение'), findsOneWidget);
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

    // Save without changes -> lHenry must be preserved, xlOhmOverride must remain null
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.branch.lHenry, 0.05);
    expect(saved!.branch.xlOhmOverride, isNull);

    // Reopen and enter invalid resistance
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
