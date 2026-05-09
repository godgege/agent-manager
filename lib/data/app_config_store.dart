import 'dart:convert';
import 'dart:io';

import '../models/prompt_item.dart';

class AppConfigStore {
  AppConfigStore({File? configFile}) : _configFile = configFile;

  final File? _configFile;

  Future<AppConfig> load() async {
    final file = await _file();
    if (!await file.exists()) {
      return AppConfig.defaults();
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return AppConfig.defaults();
    }

    return AppConfig.fromJson(decoded);
  }

  Future<void> save(AppConfig config) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(config.toJson())}\n');
  }

  Future<File> _file() async {
    final injected = _configFile;
    if (injected != null) {
      return injected;
    }

    final appData =
        Platform.environment['APPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Roaming';
    return File('$appData\\agent_manager\\config.json');
  }
}

class AppConfig {
  const AppConfig({
    required this.version,
    required this.selectedProjectId,
    required this.projects,
    this.installedSkills = const [],
  });

  factory AppConfig.defaults() {
    const projects = [
      AgentProject(
        id: 'agent-manager',
        name: 'agent-manager',
        path: r'D:\_my\agent-manager',
      ),
      AgentProject(
        id: 'test-agent-manager',
        name: 'test-agent-manager',
        path: r'D:\_my\test-agent-manager',
      ),
    ];

    return AppConfig(
      version: 1,
      selectedProjectId: projects.first.id,
      projects: projects,
      installedSkills: const [],
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final projects = (json['projects'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_projectFromJson)
        .toList();
    final fallback = AppConfig.defaults();

    if (projects.isEmpty) {
      return fallback;
    }

    final selectedProjectId = json['selectedProjectId'] as String?;
    return AppConfig(
      version: json['version'] as int? ?? 1,
      selectedProjectId:
          selectedProjectId != null &&
              projects.any((project) => project.id == selectedProjectId)
          ? selectedProjectId
          : projects.first.id,
      projects: projects,
      installedSkills: (json['installedSkills'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_promptFromJson)
          .whereType<PromptItem>()
          .toList(),
    );
  }

  final int version;
  final String selectedProjectId;
  final List<AgentProject> projects;
  final List<PromptItem> installedSkills;

  AppConfig copyWith({
    int? version,
    String? selectedProjectId,
    List<AgentProject>? projects,
    List<PromptItem>? installedSkills,
  }) {
    return AppConfig(
      version: version ?? this.version,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      projects: projects ?? this.projects,
      installedSkills: installedSkills ?? this.installedSkills,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'selectedProjectId': selectedProjectId,
      'projects': projects.map(_projectToJson).toList(),
      'installedSkills': installedSkills.map(_promptToJson).toList(),
    };
  }

  static PromptItem? _promptFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final title = json['title'] as String? ?? '';
    final content = json['content'] as String? ?? '';
    if (id.isEmpty || title.isEmpty || content.isEmpty) {
      return null;
    }

    return PromptItem(
      id: id,
      title: title,
      description: json['description'] as String? ?? '',
      content: content,
      kind: _kindFromName(json['kind'] as String?) ?? PromptKind.skill,
      scope: _scopeFromName(json['scope'] as String?) ?? PromptScope.project,
      enabledAgents: (json['enabledAgents'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map(_agentFromName)
          .whereType<AgentRuntime>()
          .toSet(),
      enabledProjectIds:
          (json['enabledProjectIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toSet(),
      source: json['source'] as String? ?? 'local',
      author: json['author'] as String?,
      marketId: json['marketId'] as String?,
      marketSource: json['marketSource'] as String?,
      marketUrl: json['marketUrl'] as String?,
      installUrl: json['installUrl'] as String?,
      installs: json['installs'] as int?,
      sourceType: json['sourceType'] as String?,
      isDuplicate: json['isDuplicate'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      hash: json['hash'] as String?,
      installedPackageId: json['installedPackageId'] as String?,
      installTargetType: _targetTypeFromName(
        json['installTargetType'] as String?,
      ),
      installedAgent: _agentFromName(json['installedAgent'] as String? ?? ''),
      installedProjectId: json['installedProjectId'] as String?,
      installedProjectPath: json['installedProjectPath'] as String?,
      installedSource: json['installedSource'] as String?,
      installedPath: json['installedPath'] as String?,
    );
  }

  static Map<String, dynamic> _promptToJson(PromptItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'description': item.description,
      'content': item.content,
      'kind': item.kind.name,
      'scope': item.scope.name,
      'enabledAgents': item.enabledAgents.map((agent) => agent.name).toList(),
      'enabledProjectIds': item.enabledProjectIds.toList(),
      'source': item.source,
      'author': item.author,
      'marketId': item.marketId,
      'marketSource': item.marketSource,
      'marketUrl': item.marketUrl,
      'installUrl': item.installUrl,
      'installs': item.installs,
      'sourceType': item.sourceType,
      'isDuplicate': item.isDuplicate,
      'isVerified': item.isVerified,
      'hash': item.hash,
      'installedPackageId': item.installedPackageId,
      'installTargetType': item.installTargetType?.name,
      'installedAgent': item.installedAgent?.name,
      'installedProjectId': item.installedProjectId,
      'installedProjectPath': item.installedProjectPath,
      'installedSource': item.installedSource,
      'installedPath': item.installedPath,
    };
  }

  static AgentProject _projectFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final path = json['path'] as String? ?? '';
    final name = json['name'] as String? ?? path.split('\\').last;
    final detectedAgents =
        (json['detectedAgents'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(_agentFromName)
            .whereType<AgentRuntime>()
            .toSet();

    return AgentProject(
      id: id.isEmpty ? _projectIdFromPath(path) : id,
      name: name,
      path: path,
      detectedAgents: detectedAgents,
    );
  }

  static Map<String, dynamic> _projectToJson(AgentProject project) {
    return {
      'id': project.id,
      'name': project.name,
      'path': project.path,
      'detectedAgents': project.detectedAgents
          .map((agent) => agent.name)
          .toList(),
    };
  }

  static AgentRuntime? _agentFromName(String name) {
    for (final agent in AgentRuntime.values) {
      if (agent.name == name) {
        return agent;
      }
    }

    return null;
  }

  static PromptKind? _kindFromName(String? name) {
    for (final kind in PromptKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }

    return null;
  }

  static PromptScope? _scopeFromName(String? name) {
    for (final scope in PromptScope.values) {
      if (scope.name == name) {
        return scope;
      }
    }

    return null;
  }

  static SkillInstallTargetType? _targetTypeFromName(String? name) {
    for (final type in SkillInstallTargetType.values) {
      if (type.name == name) {
        return type;
      }
    }

    return null;
  }

  static String _projectIdFromPath(String path) {
    return path
        .toLowerCase()
        .replaceAll(RegExp(r'^[a-z]:\\'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
