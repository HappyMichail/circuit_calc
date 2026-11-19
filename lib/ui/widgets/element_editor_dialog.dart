import 'package:material_ui/material_ui.dart';
import '../../core/model/circuit_branch.dart';

class ElementEditorResult {
  final CircuitBranch branch;
  final bool setAsTarget;
  const ElementEditorResult(this.branch, {this.setAsTarget = false});
}

enum _ReactiveMode { lc, xlxc }

class ElementEditorDialog extends StatefulWidget {
  final CircuitBranch branch;
  final bool isAc;
  final double frequencyHz;
  final bool isTargetBranch;
  final String fromLabel;
  final String toLabel;

  const ElementEditorDialog({
    super.key,
    required this.branch,
    required this.isAc,
    this.frequencyHz = 50.0,
    required this.isTargetBranch,
    required this.fromLabel,
    required this.toLabel,
  });

  @override
  State<ElementEditorDialog> createState() => _ElementEditorDialogState();
}

class _ElementEditorDialogState extends State<ElementEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _rCtrl;
  late TextEditingController _lCtrl;
  late TextEditingController _cCtrl;
  late TextEditingController _xlCtrl;
  late TextEditingController _xcCtrl;
  late TextEditingController _eMagCtrl;
  late TextEditingController _ePhaseCtrl;
  late TextEditingController _jMagCtrl;
  late TextEditingController _jPhaseCtrl;

  late _ReactiveMode _reactiveMode;
  late bool _hasCurrentSource;
  late bool _eAligned;
  late bool _jAligned;
  late bool _setAsTarget;
  double? _symbolAngleDeg;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _symbolAngleDeg = b.symbolAngleDeg;
    _reactiveMode =
        (b.xlOhmOverride != null || b.xcOhmOverride != null) &&
                b.lHenry == 0 &&
                b.cFarad == 0
            ? _ReactiveMode.xlxc
            : _ReactiveMode.lc;

    _nameCtrl = TextEditingController(text: b.name);
    _rCtrl = TextEditingController(text: _fmtInit(b.rOhm));
    _lCtrl = TextEditingController(text: _fmtInit(b.lHenry));
    _cCtrl = TextEditingController(text: _fmtInit(b.cFarad));
    _xlCtrl = TextEditingController(text: _fmtInit(b.xlOhmOverride ?? 0));
    _xcCtrl = TextEditingController(text: _fmtInit(b.xcOhmOverride ?? 0));
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

  double? _tryParse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return 0.0;
    final val = double.tryParse(cleaned);
    if (val == null || !val.isFinite) return null;
    return val;
  }

  String? _validateNumber(String? text, {bool nonNegative = false}) {
    if (text == null || text.trim().isEmpty) return null;
    final v = _tryParse(text);
    if (v == null) return 'Введите корректное число';
    if (nonNegative && v < 0) return 'Значение не может быть < 0';
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rCtrl.dispose();
    _lCtrl.dispose();
    _cCtrl.dispose();
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
        width: 440,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _jMagCtrl,
                          validator: (v) => _validateNumber(v),
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
                          child: TextFormField(
                            controller: _jPhaseCtrl,
                            validator: (v) => _validateNumber(v),
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
                  TextFormField(
                    controller: _rCtrl,
                    validator: (v) => _validateNumber(v, nonNegative: true),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Сопротивление R (Ом)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (widget.isAc) ...[
                    const SizedBox(height: 12),
                    SegmentedButton<_ReactiveMode>(
                      segments: const [
                        ButtonSegment(
                          value: _ReactiveMode.lc,
                          label: Text('L / C (Гн, Ф)'),
                        ),
                        ButtonSegment(
                          value: _ReactiveMode.xlxc,
                          label: Text('XL / XC (Ом)'),
                        ),
                      ],
                      selected: {_reactiveMode},
                      onSelectionChanged: (s) =>
                          setState(() => _reactiveMode = s.first),
                    ),
                    const SizedBox(height: 10),
                    if (_reactiveMode == _ReactiveMode.lc)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lCtrl,
                              validator: (v) =>
                                  _validateNumber(v, nonNegative: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Индуктивность L (Гн)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _cCtrl,
                              validator: (v) =>
                                  _validateNumber(v, nonNegative: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Ёмкость C (Ф)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _xlCtrl,
                              validator: (v) =>
                                  _validateNumber(v, nonNegative: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                            child: TextFormField(
                              controller: _xcCtrl,
                              validator: (v) =>
                                  _validateNumber(v, nonNegative: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _eMagCtrl,
                          validator: (v) => _validateNumber(v),
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
                          child: TextFormField(
                            controller: _ePhaseCtrl,
                            validator: (v) => _validateNumber(v),
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
                const Text('Поворот элемента на схеме'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Авто'),
                      selected: _symbolAngleDeg == null,
                      onSelected: (_) => setState(() => _symbolAngleDeg = null),
                    ),
                    for (final deg in [0.0, 45.0, 90.0, 135.0])
                      ChoiceChip(
                        label: Text('${deg.toInt()}°'),
                        selected: _symbolAngleDeg == deg,
                        onSelected: (_) =>
                            setState(() => _symbolAngleDeg = deg),
                      ),
                  ],
                ),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            final r = _tryParse(_rCtrl.text)!;
            final l = _reactiveMode == _ReactiveMode.lc
                ? _tryParse(_lCtrl.text)!
                : 0.0;
            final c = _reactiveMode == _ReactiveMode.lc
                ? _tryParse(_cCtrl.text)!
                : 0.0;
            final xl = _reactiveMode == _ReactiveMode.xlxc
                ? _tryParse(_xlCtrl.text)!
                : 0.0;
            final xc = _reactiveMode == _ReactiveMode.xlxc
                ? _tryParse(_xcCtrl.text)!
                : 0.0;

            final updated = widget.branch.copyWith(
              name: _nameCtrl.text.trim().isEmpty
                  ? widget.branch.name
                  : _nameCtrl.text.trim(),
              hasCurrentSource: _hasCurrentSource,
              rOhm: r,
              lHenry: l,
              cFarad: c,
              xlOhmOverride: xl > 0 ? xl : null,
              xcOhmOverride: xc > 0 ? xc : null,
              clearXlOverride: _reactiveMode == _ReactiveMode.lc || xl <= 0,
              clearXcOverride: _reactiveMode == _ReactiveMode.lc || xc <= 0,
              eMagnitude: _tryParse(_eMagCtrl.text)!,
              ePhaseDeg: _tryParse(_ePhaseCtrl.text)!,
              eAlignedWithBranch: _eAligned,
              jMagnitude: _tryParse(_jMagCtrl.text)!,
              jPhaseDeg: _tryParse(_jPhaseCtrl.text)!,
              jAlignedWithBranch: _jAligned,
              symbolAngleDeg: _symbolAngleDeg,
              clearSymbolAngle: _symbolAngleDeg == null,
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
