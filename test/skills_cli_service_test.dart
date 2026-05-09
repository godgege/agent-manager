import 'package:agent_manager/models/prompt_item.dart';
import 'package:agent_manager/services/skills_cli_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('packageIdFor converts skills.sh source path to CLI package id', () {
    final service = SkillsCliService();
    final skill = PromptItem(
      id: 'market-vercel-labs-skills-find-skills',
      title: 'Find Skills',
      description: 'Find relevant skills.',
      content: 'Find relevant skills.',
      kind: PromptKind.skill,
      scope: PromptScope.project,
      enabledAgents: const {},
      enabledProjectIds: const {},
      source: 'skills.sh',
      marketId: 'vercel-labs-skills-find-skills',
      marketSource: 'vercel-labs/skills/find-skills',
    );

    expect(service.packageIdFor(skill), 'vercel-labs/find-skills');
  });

  test('agent runtime maps to skills CLI agent names', () {
    expect(AgentRuntime.codex.cliName, 'codex');
    expect(AgentRuntime.gemini.cliName, 'gemini-cli');
    expect(AgentRuntime.claude.cliName, 'claude-code');
  });
}
