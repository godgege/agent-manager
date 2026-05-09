import 'dart:io';

import '../models/prompt_item.dart';

class ProjectScanner {
  Future<AgentProject> scan(String path) async {
    final directory = Directory(path);
    final normalizedPath = directory.absolute.path;
    final stat = await directory.stat();
    if (stat.type != FileSystemEntityType.directory) {
      throw FileSystemException('Project path is not a directory', path);
    }

    final name = normalizedPath
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .last;
    return AgentProject(
      id: _projectId(normalizedPath),
      name: name,
      path: normalizedPath,
      detectedAgents: await _detectAgents(normalizedPath),
    );
  }

  Future<Set<AgentRuntime>> _detectAgents(String path) async {
    final agents = <AgentRuntime>{};

    if (await _exists(path, 'AGENTS.md') || await _exists(path, '.codex')) {
      agents.add(AgentRuntime.codex);
    }

    if (await _exists(path, 'CLAUDE.md') || await _exists(path, '.claude')) {
      agents.add(AgentRuntime.claude);
    }

    if (await _exists(path, 'GEMINI.md') || await _exists(path, '.gemini')) {
      agents.add(AgentRuntime.gemini);
    }

    return agents;
  }

  Future<bool> _exists(String basePath, String name) {
    return FileSystemEntity.type(
      '$basePath${Platform.pathSeparator}$name',
    ).then((type) => type != FileSystemEntityType.notFound);
  }

  String _projectId(String path) {
    return path
        .toLowerCase()
        .replaceAll(RegExp(r'^[a-z]:\\'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
