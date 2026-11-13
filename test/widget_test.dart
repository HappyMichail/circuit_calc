import 'package:circuit_calc/main.dart';
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
}
