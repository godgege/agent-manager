import 'package:flutter/foundation.dart';

import '../data/app_config_store.dart';
import '../models/prompt_item.dart';
import '../services/project_scanner.dart';
import '../services/skills_cli_service.dart';

class PromptStore extends ChangeNotifier {
  PromptStore({AppConfigStore? configStore, ProjectScanner? projectScanner})
    : _configStore = configStore ?? AppConfigStore(),
      _projectScanner = projectScanner ?? ProjectScanner() {
    final defaults = AppConfig.defaults();
    projects.addAll(defaults.projects);
    selectedProjectId = defaults.selectedProjectId;
    _items.addAll(_seedItems());
    selectedItemId = _items.first.id;
    _loadConfig();
  }

  final AppConfigStore _configStore;
  final ProjectScanner _projectScanner;
  final List<AgentProject> projects = [];
  final List<PromptItem> _items = [];
  late String selectedProjectId;
  String? selectedItemId;

  List<PromptItem> get rules {
    return _items.where((item) => item.kind == PromptKind.rule).toList();
  }

  List<PromptItem> get localSkills {
    return _items
        .where(
          (item) => item.kind == PromptKind.skill && item.source == 'local',
        )
        .toList();
  }

  List<PromptItem> get installedSkills {
    return localSkills
        .where((skill) => skill.installTargetType != null)
        .toList();
  }

  List<PromptItem> get allItems => List.unmodifiable(_items);

  List<PromptItem> enabledPromptsFor(String projectId, AgentRuntime agent) {
    return _items
        .where(
          (item) =>
              item.enabledAgents.contains(agent) &&
              item.isEnabledForProject(projectId),
        )
        .toList();
  }

  AgentProject get selectedProject {
    return projects.firstWhere((project) => project.id == selectedProjectId);
  }

  PromptItem? get selectedItem {
    for (final item in _items) {
      if (item.id == selectedItemId) {
        return item;
      }
    }

    return null;
  }

  void selectProject(String projectId) {
    selectedProjectId = projectId;
    _saveConfig();
    notifyListeners();
  }

  void setSelectedProjectSilently(String projectId) {
    selectedProjectId = projectId;
  }

  Future<AgentProject> addProjectPath(String path) async {
    final project = await _projectScanner.scan(path);
    final existingIndex = projects.indexWhere(
      (existing) => existing.id == project.id || existing.path == project.path,
    );

    if (existingIndex == -1) {
      projects.add(project);
    } else {
      projects[existingIndex] = project;
    }

    selectedProjectId = project.id;
    await _saveConfig();
    notifyListeners();
    return project;
  }

  void selectItem(String itemId) {
    selectedItemId = itemId;
    notifyListeners();
  }

  void clearSelection() {
    selectedItemId = null;
    notifyListeners();
  }

  void toggleAgent(PromptItem item, AgentRuntime agent, bool enabled) {
    if (enabled) {
      item.enabledAgents.add(agent);
    } else {
      item.enabledAgents.remove(agent);
    }

    _saveConfig();
    notifyListeners();
  }

  void updateScope(PromptItem item, PromptScope scope) {
    item.scope = scope;
    if (scope == PromptScope.project) {
      item.enabledProjectIds.add(selectedProjectId);
    } else {
      item.enabledProjectIds.clear();
    }

    _saveConfig();
    notifyListeners();
  }

  void toggleProject(PromptItem item, String projectId, bool enabled) {
    if (enabled) {
      item.enabledProjectIds.add(projectId);
    } else {
      item.enabledProjectIds.remove(projectId);
    }

    _saveConfig();
    notifyListeners();
  }

  PromptItem addSkillToLibrary(PromptItem skill) {
    return installSkill(
      skill,
      target: const SkillInstallTarget.library(),
      packageId: skill.marketSource ?? skill.marketId ?? skill.id,
    );
  }

  PromptItem installSkill(
    PromptItem skill, {
    required SkillInstallTarget target,
    required String packageId,
    String? installedPath,
  }) {
    final agent = target.agent;
    final project = target.project;
    final scope = target.type == SkillInstallTargetType.globalAgent
        ? PromptScope.global
        : PromptScope.project;
    final enabledAgents = target.type == SkillInstallTargetType.library
        ? <AgentRuntime>{}
        : agent == null
        ? (skill.enabledAgents.isEmpty
              ? target.type == SkillInstallTargetType.project
                    ? AgentRuntime.values.toSet()
                    : {AgentRuntime.codex}
              : skill.enabledAgents)
        : {agent};
    final enabledProjectIds =
        scope == PromptScope.project &&
            target.type != SkillInstallTargetType.library
        ? {project?.id ?? selectedProjectId}
        : <String>{};
    final targetId = switch (target.type) {
      SkillInstallTargetType.library => 'library',
      SkillInstallTargetType.globalAgent => 'global-${agent!.name}',
      SkillInstallTargetType.project =>
        'project-${project!.id}-${agent?.name ?? 'all-agents'}',
    };
    final localId = _localSkillId(skill, targetId);
    final localSkill = PromptItem(
      id: localId,
      title: skill.title,
      description: skill.description,
      content: skill.content,
      kind: PromptKind.skill,
      scope: scope,
      enabledAgents: enabledAgents,
      enabledProjectIds: enabledProjectIds,
      source: 'local',
      author: skill.author,
      marketId: skill.marketId,
      marketSource: skill.marketSource,
      marketUrl: skill.marketUrl,
      installUrl: skill.installUrl,
      installs: skill.installs,
      sourceType: skill.sourceType,
      isDuplicate: skill.isDuplicate,
      isVerified: skill.isVerified,
      hash: skill.hash,
      installedPackageId: packageId,
      installTargetType: target.type,
      installedAgent: agent,
      installedProjectId: project?.id,
      installedProjectPath: project?.path,
      installedSource: skill.marketSource ?? skill.marketId ?? skill.id,
      installedPath: installedPath,
    );

    final existingIndex = _items.indexWhere((item) => item.id == localId);
    if (existingIndex == -1) {
      _items.add(localSkill);
    } else {
      _items[existingIndex] = localSkill;
    }
    selectedItemId = localSkill.id;
    _saveConfig();
    notifyListeners();
    return localSkill;
  }

  PromptItem moveSkill(
    PromptItem skill, {
    required SkillInstallTarget target,
    required String packageId,
    String? installedPath,
  }) {
    _items.removeWhere((item) => item.id == skill.id);
    return installSkill(
      skill,
      target: target,
      packageId: packageId,
      installedPath: installedPath,
    );
  }

  String _localSkillId(PromptItem skill, String targetId) {
    final sourceId = (skill.marketId ?? skill.id)
        .replaceFirst('market-', '')
        .replaceFirst('local-', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
    return 'local-$sourceId-$targetId';
  }

  Future<void> _loadConfig() async {
    final config = await _configStore.load();
    projects
      ..clear()
      ..addAll(config.projects);
    _items.removeWhere(
      (item) =>
          item.kind == PromptKind.skill &&
          item.source == 'local' &&
          item.installTargetType != null,
    );
    _items.addAll(config.installedSkills);
    selectedProjectId = config.selectedProjectId;
    notifyListeners();
  }

  Future<void> _saveConfig() {
    return _configStore.save(
      AppConfig(
        version: 1,
        selectedProjectId: selectedProjectId,
        projects: projects,
        installedSkills: installedSkills,
      ),
    );
  }

  List<PromptItem> _seedItems() {
    return [
      PromptItem(
        id: 'rule-codex-style',
        title: 'Codex Engineering Rules',
        description:
            'Default engineering collaboration style for scoped edits, checks, and user work protection.',
        content:
            'Read the existing code before editing. Keep changes scoped. Never revert user work. Run focused checks before handoff.',
        kind: PromptKind.rule,
        scope: PromptScope.global,
        enabledAgents: {
          AgentRuntime.codex,
          AgentRuntime.gemini,
          AgentRuntime.claude,
        },
        enabledProjectIds: {},
      ),
      PromptItem(
        id: 'rule-project-context',
        title: 'Project Context Loader',
        description:
            'Read README, package config, source layout, and workspace state before starting agent work.',
        content:
            'Before making changes, inspect README, package configuration, source layout, and current worktree state.',
        kind: PromptKind.rule,
        scope: PromptScope.project,
        enabledAgents: {AgentRuntime.codex, AgentRuntime.claude},
        enabledProjectIds: {'agent-manager'},
      ),
      PromptItem(
        id: 'skill-flutter-ui',
        title: 'Flutter UI Builder',
        description:
            'Build desktop Flutter pages with responsive layout and Material controls.',
        content:
            'Build native-feeling Flutter UI with constrained layouts, semantic controls, and analyzer-clean Dart code.',
        kind: PromptKind.skill,
        scope: PromptScope.project,
        enabledAgents: {AgentRuntime.codex, AgentRuntime.gemini},
        enabledProjectIds: {'agent-manager', 'playground'},
      ),
      PromptItem(
        id: 'skill-docs-writer',
        title: 'Docs Writer',
        description:
            'Turn implementation details into concise README, changelog, and usage notes.',
        content:
            'Write practical documentation with commands, assumptions, and concise examples that match the repository.',
        kind: PromptKind.skill,
        scope: PromptScope.global,
        enabledAgents: {AgentRuntime.claude},
        enabledProjectIds: {},
      ),
    ];
  }
}
