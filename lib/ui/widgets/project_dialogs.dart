import 'dart:io';
import 'package:material_ui/material_ui.dart';
import '../../core/export/circuit_exporter.dart';
import '../../core/storage/project_storage.dart';
import '../controllers/circuit_editor_controller.dart';

class ProjectDialogs {
  static Future<bool> confirmDiscardIfDirty(
    BuildContext context,
    CircuitEditorController controller,
  ) async {
    if (!controller.isDirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text(
          'Текущий проект содержит несохранённые изменения. Продолжить без сохранения?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    return res == true;
  }

  static Future<void> showSaveProjectDialog(
    BuildContext context,
    CircuitEditorController controller,
  ) async {
    final nameCtrl = TextEditingController(text: controller.circuit.name);
    final pathCtrl = TextEditingController(
      text: ProjectStorage.defaultProjectFilePath(controller.circuit.name),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить проект'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название проекта',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  pathCtrl.text = ProjectStorage.defaultProjectFilePath(val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Путь к файлу (.ccalc.json)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    final newName = nameCtrl.text.trim();
    final rawPath = pathCtrl.text.trim();
    nameCtrl.dispose();
    pathCtrl.dispose();

    if (confirmed != true || rawPath.isEmpty || !context.mounted) return;

    final sep = Platform.pathSeparator;
    var targetPath = rawPath;
    if (!targetPath.contains('\\') && !targetPath.contains('/')) {
      final dir = ProjectStorage.defaultProjectsDirectory().path;
      targetPath = '$dir$sep$targetPath';
    }
    if (Directory(targetPath).existsSync() ||
        targetPath.endsWith('\\') ||
        targetPath.endsWith('/')) {
      final cleanDir = targetPath.endsWith('\\') || targetPath.endsWith('/')
          ? targetPath.substring(0, targetPath.length - 1)
          : targetPath;
      final fileName =
          ProjectStorage.defaultProjectFilePath(newName).split(sep).last;
      targetPath = '$cleanDir$sep$fileName';
    } else if (!targetPath.toLowerCase().endsWith('.json')) {
      targetPath = '$targetPath.ccalc.json';
    }

    final updatedCircuit = newName.isEmpty
        ? controller.circuit
        : controller.circuit.copyWith(name: newName);
    final savedObj = SavedProject(
      circuit: updatedCircuit,
      method: controller.method,
      acBaseMethod: controller.acBaseMethod,
    );

    try {
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(ProjectStorage.encode(savedObj));

      if (!context.mounted) return;
      controller.markSaved(newName: newName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Проект сохранён: ${file.path}')),
      );
    } on PathAccessException catch (_) {
      if (!context.mounted) return;
      final fallbackPath = ProjectStorage.defaultProjectFilePath(
        newName.isEmpty ? controller.circuit.name : newName,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: const Text(
            'Нет прав на запись в выбранную папку (например, корень диска).',
          ),
          action: SnackBarAction(
            label: 'В Документы',
            onPressed: () async {
              final f = File(fallbackPath);
              await f.parent.create(recursive: true);
              await f.writeAsString(ProjectStorage.encode(savedObj));
              if (!context.mounted) return;
              controller.markSaved(newName: newName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Проект сохранён: ${f.path}')),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения проекта: $e')),
      );
    }
  }

  static Future<bool> showOpenProjectDialog(
    BuildContext context,
    CircuitEditorController controller,
  ) async {
    final savedFiles = ProjectStorage.listSavedProjects();
    final pathCtrl = TextEditingController();

    final selectedPath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Открыть проект'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (savedFiles.isNotEmpty) ...[
                Text(
                  'Сохранённые проекты:',
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: savedFiles.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final f = savedFiles[idx];
                      final fileName =
                          f.path.split(Platform.pathSeparator).last;
                      return ListTile(
                        dense: true,
                        leading:
                            const Icon(Icons.description_outlined, size: 18),
                        title: Text(fileName),
                        subtitle: Text(
                          f.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.of(ctx).pop(f.path),
                      );
                    },
                  ),
                ),
                const Divider(height: 20),
              ],
              TextField(
                controller: pathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Или введите путь к файлу (.json)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final p = pathCtrl.text.trim();
              if (p.isNotEmpty) Navigator.of(ctx).pop(p);
            },
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
    pathCtrl.dispose();

    if (selectedPath == null || selectedPath.isEmpty || !context.mounted) {
      return false;
    }

    try {
      final raw = await File(selectedPath).readAsString();
      final project = ProjectStorage.decode(raw);
      controller.loadSavedProject(project);
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Проект загружен: ${project.circuit.name}')),
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки проекта: $e')),
      );
      return false;
    }
  }

  static Future<void> showExportDialog(
    BuildContext context,
    CircuitEditorController controller,
    String extType,
  ) async {
    final defaultPath = CircuitExporter.defaultExportPath(extType);
    final pathCtrl = TextEditingController(text: defaultPath);

    final chosenPath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Экспорт схемы и результатов (${extType.toUpperCase()})'),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: pathCtrl,
            decoration: const InputDecoration(
              labelText: 'Путь сохранения файла',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(pathCtrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    pathCtrl.dispose();

    if (chosenPath == null || chosenPath.isEmpty || !context.mounted) return;

    final sep = Platform.pathSeparator;
    var targetPath = chosenPath;
    if (!targetPath.contains('\\') && !targetPath.contains('/')) {
      final dir = File(defaultPath).parent.path;
      targetPath = '$dir$sep$targetPath';
    }
    if (Directory(targetPath).existsSync() ||
        targetPath.endsWith('\\') ||
        targetPath.endsWith('/')) {
      final cleanDir = targetPath.endsWith('\\') || targetPath.endsWith('/')
          ? targetPath.substring(0, targetPath.length - 1)
          : targetPath;
      final fileName = defaultPath.split(sep).last;
      targetPath = '$cleanDir$sep$fileName';
    } else if (!targetPath.toLowerCase().endsWith('.$extType')) {
      targetPath = '$targetPath.$extType';
    }

    Future<void> writeTo(String path) async {
      final file = File(path);
      await file.parent.create(recursive: true);
      if (extType == 'svg') {
        final svg =
            CircuitExporter.buildSvg(controller.circuit, controller.solution);
        await file.writeAsString(svg);
      } else {
        final bytes = await CircuitExporter.buildPdf(
            controller.circuit, controller.solution);
        await file.writeAsBytes(bytes);
      }
    }

    try {
      await writeTo(targetPath);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл сохранён: $targetPath')),
      );
    } on PathAccessException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: const Text(
            'Нет прав на запись в выбранную папку (например, корень диска).',
          ),
          action: SnackBarAction(
            label: 'В Загрузки',
            onPressed: () async {
              await writeTo(defaultPath);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Файл сохранён: $defaultPath')),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }
}
