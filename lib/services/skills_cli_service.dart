import 'dart:io';

import '../models/prompt_item.dart';

class SkillsCliService {
  Future<SkillsCliInstallResult> installSkill({
    required PromptItem skill,
    required SkillInstallTarget target,
  }) async {
    final packageId = packageIdFor(skill);
    final args = <String>['skills', 'add', packageId, '-y'];
    String? workingDirectory;

    switch (target.type) {
      case SkillInstallTargetType.library:
        throw ArgumentError('Library installs do not use the skills CLI');
      case SkillInstallTargetType.globalAgent:
        final agent = target.agent;
        if (agent == null) {
          throw ArgumentError('Global installs require an agent');
        }
        args
          ..add('-g')
          ..add('--agent')
          ..add(agent.cliName);
      case SkillInstallTargetType.project:
        final project = target.project;
        if (project == null) {
          throw ArgumentError('Project installs require a project');
        }
        workingDirectory = project.path;
        args.add('--agent');
        final agent = target.agent;
        if (agent == null) {
          args.addAll(AgentRuntime.values.map((agent) => agent.cliName));
        } else {
          args.add(agent.cliName);
        }
    }

    final result = await Process.run(
      'npx',
      args,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );

    if (result.exitCode != 0) {
      throw ProcessException(
        'npx',
        ['skills', 'add', packageId],
        _outputText(result),
        result.exitCode,
      );
    }

    return SkillsCliInstallResult(
      packageId: packageId,
      target: target,
      outputPath: _readOutputPath(result),
      output: _outputText(result),
    );
  }

  String packageIdFor(PromptItem skill) {
    final source = skill.marketSource?.trim();
    if (source != null && source.isNotEmpty) {
      return source.replaceFirst('/skills/', '/');
    }

    final id = skill.marketId ?? skill.id.replaceFirst('market-', '');
    return id.replaceFirst('-skills-', '/');
  }

  String _outputText(ProcessResult result) {
    return [result.stdout, result.stderr]
        .map((part) => part.toString().trim())
        .where((part) => part.isNotEmpty)
        .join('\n');
  }

  String? _readOutputPath(ProcessResult result) {
    final output = _outputText(result);
    final patterns = [
      RegExp(r'(?:Installed|Linked|Copied)[^\n]*?\s(?:to|at)\s+(.+)$'),
      RegExp(r'(?:Location|Path):\s*(.+)$'),
    ];

    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      for (final pattern in patterns) {
        final match = pattern.firstMatch(trimmed);
        if (match != null) {
          return match.group(1)?.trim();
        }
      }
    }

    return null;
  }
}

extension AgentRuntimeSkillsCliName on AgentRuntime {
  String get cliName {
    switch (this) {
      case AgentRuntime.codex:
        return 'codex';
      case AgentRuntime.gemini:
        return 'gemini-cli';
      case AgentRuntime.claude:
        return 'claude-code';
    }
  }
}

class SkillInstallTarget {
  const SkillInstallTarget.library()
    : type = SkillInstallTargetType.library,
      agent = null,
      project = null;

  const SkillInstallTarget.globalAgent(this.agent)
    : type = SkillInstallTargetType.globalAgent,
      project = null;

  const SkillInstallTarget.project({required this.project, this.agent})
    : type = SkillInstallTargetType.project;

  final SkillInstallTargetType type;
  final AgentRuntime? agent;
  final AgentProject? project;

  String get label {
    switch (type) {
      case SkillInstallTargetType.library:
        return 'My library';
      case SkillInstallTargetType.globalAgent:
        return '${agent!.label} global';
      case SkillInstallTargetType.project:
        final selectedAgent = agent;
        if (selectedAgent == null) {
          return project!.name;
        }
        return '${project!.name} / ${selectedAgent.label}';
    }
  }
}

class SkillsCliInstallResult {
  const SkillsCliInstallResult({
    required this.packageId,
    required this.target,
    this.outputPath,
    required this.output,
  });

  final String packageId;
  final SkillInstallTarget target;
  final String? outputPath;
  final String output;
}
