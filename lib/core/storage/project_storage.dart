import 'dart:convert';
import 'dart:io';
import '../model/circuit.dart';
import '../model/circuit_branch.dart';
import '../model/circuit_node.dart';

class SavedProject {
  final int schemaVersion;
  final Circuit circuit;
  final CalculationMethod method;
  final CalculationMethod acBaseMethod;

  const SavedProject({
    this.schemaVersion = 1,
    required this.circuit,
    required this.method,
    required this.acBaseMethod,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'method': method.name,
        'acBaseMethod': acBaseMethod.name,
        'circuit': ProjectStorage.circuitToJson(circuit),
      };

  factory SavedProject.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > 1) {
      throw FormatException('Неподдерживаемая версия файла проекта: $version');
    }

    final methodName = json['method'] as String?;
    final acBaseName = json['acBaseMethod'] as String?;
    final method = CalculationMethod.values.firstWhere(
      (m) => m.name == methodName,
      orElse: () => CalculationMethod.nodalPotentials,
    );
    final acBaseMethod = CalculationMethod.values.firstWhere(
      (m) => m.name == acBaseName,
      orElse: () => CalculationMethod.nodalPotentials,
    );

    final circuitJson = json['circuit'] as Map<String, dynamic>?;
    if (circuitJson == null) {
      throw const FormatException('В файле отсутствует описание схемы (circuit).');
    }

    return SavedProject(
      schemaVersion: version,
      circuit: ProjectStorage.circuitFromJson(circuitJson),
      method: method,
      acBaseMethod: acBaseMethod,
    );
  }
}

class ProjectStorage {
  static Map<String, dynamic> nodeToJson(CircuitNode n) => {
        'id': n.id,
        'label': n.label,
        'x': n.x,
        'y': n.y,
      };

  static CircuitNode nodeFromJson(Map<String, dynamic> j) => CircuitNode(
        id: j['id'] as String,
        label: j['label'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
      );

  static Map<String, dynamic> branchToJson(CircuitBranch b) => {
        'id': b.id,
        'name': b.name,
        'fromNodeId': b.fromNodeId,
        'toNodeId': b.toNodeId,
        'rOhm': b.rOhm,
        'lHenry': b.lHenry,
        'cFarad': b.cFarad,
        if (b.xlOhmOverride != null) 'xlOhmOverride': b.xlOhmOverride,
        if (b.xcOhmOverride != null) 'xcOhmOverride': b.xcOhmOverride,
        'eMagnitude': b.eMagnitude,
        'ePhaseDeg': b.ePhaseDeg,
        'eAlignedWithBranch': b.eAlignedWithBranch,
        'hasCurrentSource': b.hasCurrentSource,
        'jMagnitude': b.jMagnitude,
        'jPhaseDeg': b.jPhaseDeg,
        'jAlignedWithBranch': b.jAlignedWithBranch,
        if (b.controlX != null) 'controlX': b.controlX,
        if (b.controlY != null) 'controlY': b.controlY,
        if (b.symbolAngleDeg != null) 'symbolAngleDeg': b.symbolAngleDeg,
      };

  static CircuitBranch branchFromJson(Map<String, dynamic> j) => CircuitBranch(
        id: j['id'] as String,
        name: j['name'] as String,
        fromNodeId: j['fromNodeId'] as String,
        toNodeId: j['toNodeId'] as String,
        rOhm: (j['rOhm'] as num?)?.toDouble() ?? 0.0,
        lHenry: (j['lHenry'] as num?)?.toDouble() ?? 0.0,
        cFarad: (j['cFarad'] as num?)?.toDouble() ?? 0.0,
        xlOhmOverride: (j['xlOhmOverride'] as num?)?.toDouble(),
        xcOhmOverride: (j['xcOhmOverride'] as num?)?.toDouble(),
        eMagnitude: (j['eMagnitude'] as num?)?.toDouble() ?? 0.0,
        ePhaseDeg: (j['ePhaseDeg'] as num?)?.toDouble() ?? 0.0,
        eAlignedWithBranch: j['eAlignedWithBranch'] as bool? ?? true,
        hasCurrentSource: j['hasCurrentSource'] as bool? ?? false,
        jMagnitude: (j['jMagnitude'] as num?)?.toDouble() ?? 0.0,
        jPhaseDeg: (j['jPhaseDeg'] as num?)?.toDouble() ?? 0.0,
        jAlignedWithBranch: j['jAlignedWithBranch'] as bool? ?? true,
        controlX: (j['controlX'] as num?)?.toDouble(),
        controlY: (j['controlY'] as num?)?.toDouble(),
        symbolAngleDeg: (j['symbolAngleDeg'] as num?)?.toDouble(),
      );

  static Map<String, dynamic> circuitToJson(Circuit c) => {
        'name': c.name,
        'isAc': c.isAc,
        'frequencyHz': c.frequencyHz,
        if (c.referenceNodeId != null) 'referenceNodeId': c.referenceNodeId,
        if (c.targetBranchId != null) 'targetBranchId': c.targetBranchId,
        'nodes': [for (final n in c.nodes) nodeToJson(n)],
        'branches': [for (final b in c.branches) branchToJson(b)],
      };

  static Circuit circuitFromJson(Map<String, dynamic> j) {
    final nodesList = (j['nodes'] as List<dynamic>)
        .map((e) => nodeFromJson(e as Map<String, dynamic>))
        .toList();
    final branchesList = (j['branches'] as List<dynamic>)
        .map((e) => branchFromJson(e as Map<String, dynamic>))
        .toList();

    return Circuit(
      name: j['name'] as String? ?? 'Без названия',
      isAc: j['isAc'] as bool? ?? false,
      frequencyHz: (j['frequencyHz'] as num?)?.toDouble() ?? 50.0,
      referenceNodeId: j['referenceNodeId'] as String?,
      targetBranchId: j['targetBranchId'] as String?,
      nodes: nodesList,
      branches: branchesList,
    );
  }

  static String encode(SavedProject project) =>
      const JsonEncoder.withIndent('  ').convert(project.toJson());

  static SavedProject decode(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Некорректный формат JSON-файла проекта.');
    }
    return SavedProject.fromJson(decoded);
  }

  static Directory defaultProjectsDirectory() {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final docs = Directory('$userProfile\\Documents\\CircuitCalc');
      return docs;
    }
    final home = Platform.environment['HOME'];
    if (home != null) {
      return Directory('$home/CircuitCalc');
    }
    return Directory('${Directory.current.path}${Platform.pathSeparator}projects');
  }

  static String defaultProjectFilePath(String projectName) {
    final safeName = projectName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final base = safeName.isEmpty ? 'circuit_project' : safeName;
    final dir = defaultProjectsDirectory();
    return '${dir.path}${Platform.pathSeparator}$base.ccalc.json';
  }

  static List<File> listSavedProjects() {
    final dir = defaultProjectsDirectory();
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
}
