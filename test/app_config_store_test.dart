import 'dart:io';

import 'package:agent_manager/data/app_config_store.dart';
import 'package:agent_manager/models/prompt_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves and loads projects', () async {
    final temp = await Directory.systemTemp.createTemp('agent-config-test');
    addTearDown(() => temp.delete(recursive: true));

    final store = AppConfigStore(configFile: File('${temp.path}/config.json'));
    final config = AppConfig(
      version: 1,
      selectedProjectId: 'demo',
      projects: const [
        AgentProject(
          id: 'demo',
          name: 'demo',
          path: r'D:\demo',
          detectedAgents: {AgentRuntime.codex, AgentRuntime.claude},
        ),
      ],
      installedSkills: [
        PromptItem(
          id: 'local-review',
          title: 'Review',
          description: 'Review code',
          content: 'Review code',
          kind: PromptKind.skill,
          scope: PromptScope.global,
          enabledAgents: const {AgentRuntime.codex},
          enabledProjectIds: const {},
          marketSource: 'owner/skills/review',
          installedPackageId: 'owner/review',
          installTargetType: SkillInstallTargetType.globalAgent,
          installedAgent: AgentRuntime.codex,
          installedSource: 'owner/skills/review',
          installedPath: r'C:\Users\demo\.codex\skills\review',
        ),
      ],
    );

    await store.save(config);
    final loaded = await store.load();

    expect(loaded.selectedProjectId, 'demo');
    expect(loaded.projects.single.path, r'D:\demo');
    expect(loaded.projects.single.detectedAgents, {
      AgentRuntime.codex,
      AgentRuntime.claude,
    });
    expect(loaded.installedSkills.single.installedPackageId, 'owner/review');
    expect(
      loaded.installedSkills.single.installTargetType,
      SkillInstallTargetType.globalAgent,
    );
    expect(loaded.installedSkills.single.installedAgent, AgentRuntime.codex);
  });
}
