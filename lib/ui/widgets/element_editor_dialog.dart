import 'package:material_ui/material_ui.dart';
import '../../core/model/circuit_branch.dart';

class ElementEditorResult {
  final CircuitBranch branch;
  final bool setAsTarget;
  const ElementEditorResult(this.branch, {this.setAsTarget = false});
}

class ElementEditorDialog extends StatefulWidget {
  final CircuitBranch branch;
  final bool isAc;
  final bool isTargetBranch;
  final String fromLabel;
  final String toLabel;

  const ElementEditorDialog({
    super.key,
    required this.branch,
    required this.isAc,
    required this.isTargetBranch,
    required this.fromLabel,
    required this.toLabel,
  });

  @override
  State<ElementEditorDialog> createState() => _ElementEditorDialogState();
}

class _ElementEditorDialogState extends State<ElementEditorDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _rCtrl;
  late TextEditingController _xlCtrl;
  late TextEditingController _xcCtrl;
  late TextEditingController _eMagCtrl;
  late TextEditingController _ePhaseCtrl;
  late TextEditingController _jMagCtrl;
  late TextEditingController _jPhaseCtrl;

  late bool _hasCurrentSource;
  late bool _eAligned;
  late bool _jAligned;
  late bool _setAsTarget;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameCtrl = TextEditingController(text: b.name);
    _rCtrl = TextEditingController(text: _fmtInit(b.rOhm));
    _xlCtrl = TextEditingController(
        text: _fmtInit(b.xlOhmOverride ?? (b.lHenry > 0 ? b.lHenry * b.omegaDefault : 0)));
    _xcCtrl = TextEditingController(
        text: _fmtInit(b.xcOhmOverride ??
            (b.cFarad > 0 ? 1.0 / (b.cFarad * b.omegaDefault) : 0)));
    _eMagCtrl = TextEditingController(text: _fmtInit(b.eMagnitude));
    _ePhaseCtrl = TextEditingController(text: _fmtInit(b.ePhaseDeg));
    _jMagCtrl = TextEditingController(text: _fmtInit(b.jMagnitude));
    _jPhaseCtrl = TextEditingController(text: _fmtInit(b.jPhaseDeg));

    _hasCurrentSource = b.hasCurrentSource;
    _eAligned = b.eAlignedWithBranch;
    _jAligned = b.jAlignedWithBranch;
    _setAsTarget = widget.isTargetBranch;
  }

  String _fmtInit(double v) => v == 0 ? '0' : v.toString();

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0.0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rCtrl.dispose();
    _xlCtrl.dispose();
    _xcCtrl.dispose();
    _eMagCtrl.dispose();
    _ePhaseCtrl.dispose();
    _jMagCtrl.dispose();
    _jPhaseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          'Ветвь ${widget.branch.name} (${widget.fromLabel} → ${widget.toLabel})'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Обозначение ветви',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ветвь с источником тока (J)'),
                subtitle: const Text(
                    'Фиксирует ток в ветви; отключает R, L, C, E'),
                value: _hasCurrentSource,
                onChanged: (v) => setState(() => _hasCurrentSource = v),
              ),
              const Divider(),
              if (_hasCurrentSource) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _jMagCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Ток J (А)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (widget.isAc) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _jPhaseCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Фаза (°)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Направлен от ${widget.fromLabel} к ${widget.toLabel}'),
                  value: _jAligned,
                  onChanged: (v) => setState(() => _jAligned = v ?? true),
                ),
              ] else ...[
                TextField(
                  controller: _rCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Сопротивление R (Ом)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (widget.isAc) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _xlCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'XL (Ом)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _xcCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'XC (Ом)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _eMagCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'ЭДС E (В)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (widget.isAc) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ePhaseCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Фаза E (°)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'ЭДС направлена от ${widget.fromLabel} к ${widget.toLabel}'),
                  value: _eAligned,
                  onChanged: (v) => setState(() => _eAligned = v ?? true),
                ),
              ],
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Целевая ветвь (для Тевенина / Нортона)'),
                value: _setAsTarget,
                onChanged: (v) => setState(() => _setAsTarget = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final xl = _parse(_xlCtrl);
            final xc = _parse(_xcCtrl);
            final updated = widget.branch.copyWith(
              name: _nameCtrl.text.trim().isEmpty
                  ? widget.branch.name
                  : _nameCtrl.text.trim(),
              hasCurrentSource: _hasCurrentSource,
              rOhm: _parse(_rCtrl).abs(),
              lHenry: 0,
              cFarad: 0,
              xlOhmOverride: xl > 0 ? xl : null,
              xcOhmOverride: xc > 0 ? xc : null,
              clearXlOverride: xl <= 0,
              clearXcOverride: xc <= 0,
              eMagnitude: _parse(_eMagCtrl),
              ePhaseDeg: _parse(_ePhaseCtrl),
              eAlignedWithBranch: _eAligned,
              jMagnitude: _parse(_jMagCtrl),
              jPhaseDeg: _parse(_jPhaseCtrl),
              jAlignedWithBranch: _jAligned,
            );
            Navigator.of(context).pop(
              ElementEditorResult(updated, setAsTarget: _setAsTarget),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
