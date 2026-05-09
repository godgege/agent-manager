enum PromptKind { rule, skill }

enum PromptScope { global, project }

enum AgentRuntime { codex, gemini, claude }

enum SkillInstallTargetType { library, globalAgent, project }

extension PromptKindLabel on PromptKind {
  String get label {
    switch (this) {
      case PromptKind.rule:
        return 'Rule';
      case PromptKind.skill:
        return 'Skill';
    }
  }
}

extension PromptScopeLabel on PromptScope {
  String get label {
    switch (this) {
      case PromptScope.global:
        return 'Global';
      case PromptScope.project:
        return 'Project';
    }
  }
}

extension AgentRuntimeLabel on AgentRuntime {
  String get label {
    switch (this) {
      case AgentRuntime.codex:
        return 'Codex';
      case AgentRuntime.gemini:
        return 'Gemini';
      case AgentRuntime.claude:
        return 'Claude';
    }
  }
}

class PromptItem {
  PromptItem({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.kind,
    required this.scope,
    required Set<AgentRuntime> enabledAgents,
    required Set<String> enabledProjectIds,
    this.source = 'local',
    this.author,
    this.marketId,
    this.marketSource,
    this.marketUrl,
    this.installUrl,
    this.installs,
    this.sourceType,
    this.isDuplicate = false,
    this.isVerified = false,
    this.hash,
    this.installedPackageId,
    this.installTargetType,
    this.installedAgent,
    this.installedProjectId,
    this.installedProjectPath,
    this.installedSource,
    this.installedPath,
    List<SkillFile> marketFiles = const [],
  }) : enabledAgents = {...enabledAgents},
       enabledProjectIds = {...enabledProjectIds},
       marketFiles = List.unmodifiable(marketFiles);

  final String id;
  final String title;
  final String description;
  final String content;
  final PromptKind kind;
  final String source;
  final String? author;
  final String? marketId;
  final String? marketSource;
  final String? marketUrl;
  final String? installUrl;
  final int? installs;
  final String? sourceType;
  final bool isDuplicate;
  final bool isVerified;
  final String? hash;
  final String? installedPackageId;
  final SkillInstallTargetType? installTargetType;
  final AgentRuntime? installedAgent;
  final String? installedProjectId;
  final String? installedProjectPath;
  final String? installedSource;
  final String? installedPath;
  final List<SkillFile> marketFiles;
  PromptScope scope;
  final Set<AgentRuntime> enabledAgents;
  final Set<String> enabledProjectIds;

  bool get hasInstallSource {
    return (marketSource != null && marketSource!.trim().isNotEmpty) ||
        (marketId != null && marketId!.trim().isNotEmpty) ||
        (installedPackageId != null && installedPackageId!.trim().isNotEmpty);
  }

  bool isEnabledForProject(String projectId) {
    return scope == PromptScope.global || enabledProjectIds.contains(projectId);
  }

  PromptItem copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    PromptKind? kind,
    PromptScope? scope,
    Set<AgentRuntime>? enabledAgents,
    Set<String>? enabledProjectIds,
    String? source,
    String? author,
    String? marketId,
    String? marketSource,
    String? marketUrl,
    String? installUrl,
    int? installs,
    String? sourceType,
    bool? isDuplicate,
    bool? isVerified,
    String? hash,
    String? installedPackageId,
    SkillInstallTargetType? installTargetType,
    AgentRuntime? installedAgent,
    String? installedProjectId,
    String? installedProjectPath,
    String? installedSource,
    String? installedPath,
    List<SkillFile>? marketFiles,
  }) {
    return PromptItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      kind: kind ?? this.kind,
      scope: scope ?? this.scope,
      enabledAgents: enabledAgents ?? this.enabledAgents,
      enabledProjectIds: enabledProjectIds ?? this.enabledProjectIds,
      source: source ?? this.source,
      author: author ?? this.author,
      marketId: marketId ?? this.marketId,
      marketSource: marketSource ?? this.marketSource,
      marketUrl: marketUrl ?? this.marketUrl,
      installUrl: installUrl ?? this.installUrl,
      installs: installs ?? this.installs,
      sourceType: sourceType ?? this.sourceType,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      isVerified: isVerified ?? this.isVerified,
      hash: hash ?? this.hash,
      installedPackageId: installedPackageId ?? this.installedPackageId,
      installTargetType: installTargetType ?? this.installTargetType,
      installedAgent: installedAgent ?? this.installedAgent,
      installedProjectId: installedProjectId ?? this.installedProjectId,
      installedProjectPath: installedProjectPath ?? this.installedProjectPath,
      installedSource: installedSource ?? this.installedSource,
      installedPath: installedPath ?? this.installedPath,
      marketFiles: marketFiles ?? this.marketFiles,
    );
  }
}

class SkillFile {
  const SkillFile({required this.path, required this.contents});

  final String path;
  final String contents;

  bool get isSkillMarkdown {
    return path.split('/').last.toLowerCase() == 'skill.md';
  }

  int get byteLength {
    return contents.codeUnits.length;
  }
}

class AgentProject {
  const AgentProject({
    required this.id,
    required this.name,
    required this.path,
    this.detectedAgents = const {},
  });

  final String id;
  final String name;
  final String path;
  final Set<AgentRuntime> detectedAgents;

  AgentProject copyWith({
    String? id,
    String? name,
    String? path,
    Set<AgentRuntime>? detectedAgents,
  }) {
    return AgentProject(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      detectedAgents: detectedAgents ?? this.detectedAgents,
    );
  }
}
