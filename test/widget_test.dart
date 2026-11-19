import 'package:circuit_calc/core/export/circuit_exporter.dart';
import 'package:circuit_calc/core/model/circuit.dart';
import 'package:circuit_calc/core/model/circuit_branch.dart';
import 'package:circuit_calc/core/model/circuit_node.dart';
import 'package:circuit_calc/core/solvers/circuit_solver.dart';
import 'package:circuit_calc/core/templates/circuit_templates.dart';
import 'package:circuit_calc/main.dart';
import 'package:circuit_calc/ui/widgets/circuit_canvas.dart';
import 'package:circuit_calc/ui/widgets/element_editor_dialog.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('Dragging a branch element updates its control point on canvas',
      (WidgetTester tester) async {
    var circuit = const Circuit(
      name: 'Drag test',
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 100, y: 100),
        CircuitNode(id: 'n1', label: '1', x: 300, y: 100),
      ],
      branches: [
        CircuitBranch(
          id: 'b1',
          name: '1',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          rOhm: 10,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(
            circuit: circuit,
            solution: null,
            activeTool: CanvasTool.selectMove,
            onCircuitChanged: (c) => circuit = c,
            onGeometryChanged: (c) => circuit = c,
            onEditBranch: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drag from branch midpoint (200, 100) down by 60px
    await tester.dragFrom(const Offset(200, 100), const Offset(0, 60));
    await tester.pumpAndSettle();

    expect(circuit.branches.first.controlX, isNotNull);
    expect(circuit.branches.first.controlY, isNotNull);
    expect(circuit.branches.first.controlY!, greaterThan(150));
  });

  testWidgets('Left-click selects branch without editing; right-click edits',
      (WidgetTester tester) async {
    CircuitBranch? edited;
    CircuitBranch? selected;
    const circuit = Circuit(
      name: 'Right-click test',
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 100, y: 100),
        CircuitNode(id: 'n1', label: '1', x: 300, y: 100),
      ],
      branches: [
        CircuitBranch(
          id: 'b1',
          name: '1',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          rOhm: 10,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(
            circuit: circuit,
            solution: null,
            activeTool: CanvasTool.selectMove,
            onCircuitChanged: (_) {},
            onSelectBranch: (b) => selected = b,
            onEditBranch: (b) => edited = b,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Left-click selects only
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    expect(selected?.id, 'b1');
    expect(edited, isNull);

    // Right-click opens editor
    await tester.tapAt(const Offset(200, 100), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.id, 'b1');
  });

  test('CircuitExporter generates valid SVG and PDF with Cyrillic support',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final circuit = CircuitTemplates.twoLoopDc();
    final sol =
        CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);

    final svg = CircuitExporter.buildSvg(circuit, sol);
    expect(svg, contains('<svg'));
    expect(svg, contains('</svg>'));
    expect(svg, contains('Ветвь 1'));

    final pdfBytes = await CircuitExporter.buildPdf(circuit, sol);
    expect(pdfBytes.length, greaterThan(1000));
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
  });
}
