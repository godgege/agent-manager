import 'package:agent_manager/main.dart';
import 'package:agent_manager/models/prompt_item.dart';
import 'package:agent_manager/services/skills_cli_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prompt manager shows expanded navigation groups', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AgentManagerApp(
        fetchMarketSkills: ({String query = ''}) async => _marketSkills,
        fetchMarketSkillDetails: _fetchMarketSkillDetails,
        installMarketSkill: _installMarketSkill,
      ),
    );

    expect(find.text('EN'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_outlined), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.text('Codex'), findsWidgets);
    expect(find.text('Gemini'), findsWidgets);
    expect(find.text('Claude'), findsWidgets);
    expect(find.text('agent-manager'), findsWidgets);
    expect(find.text('test-agent-manager'), findsWidgets);
    expect(find.text('Flutter UI Builder'), findsWidgets);
    expect(find.text('Package Info'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pump();

    expect(find.text('Search skills.sh'), findsOneWidget);
  });

  testWidgets('skills can switch from mine to market', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AgentManagerApp(
        fetchMarketSkills: ({String query = ''}) async => _marketSkills,
        fetchMarketSkillDetails: _fetchMarketSkillDetails,
        installMarketSkill: _installMarketSkill,
      ),
    );

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Market Skill'), findsOneWidget);
    expect(find.text('owner/skills'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('installs'), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('agent navigation opens blank scene', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AgentManagerApp(
        fetchMarketSkills: ({String query = ''}) async => _marketSkills,
        fetchMarketSkillDetails: _fetchMarketSkillDetails,
        installMarketSkill: _installMarketSkill,
      ),
    );

    await tester.tap(find.text('Codex').first);
    await tester.pump();

    expect(find.text('Codex'), findsWidgets);
    expect(find.text('Flutter UI Builder'), findsNothing);
    expect(find.text('Package Info'), findsNothing);

    await tester.tap(find.byIcon(Icons.workspace_premium_outlined));
    await tester.pump();

    expect(find.text('Flutter UI Builder'), findsWidgets);
  });

  testWidgets('project navigation shows project prompts', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AgentManagerApp(
        fetchMarketSkills: ({String query = ''}) async => _marketSkills,
        fetchMarketSkillDetails: _fetchMarketSkillDetails,
        installMarketSkill: _installMarketSkill,
      ),
    );

    await tester.tap(find.text('agent-manager').first);
    await tester.pump();

    expect(find.text('agent-manager'), findsWidgets);
    expect(find.text('Project Context Loader'), findsOneWidget);
    expect(find.text('Flutter UI Builder'), findsOneWidget);
  });

  testWidgets('market install can target a project and track local source', (
    WidgetTester tester,
  ) async {
    var installed = false;
    SkillInstallTarget? installedTarget;

    await tester.pumpWidget(
      AgentManagerApp(
        fetchMarketSkills: ({String query = ''}) async => _marketSkills,
        fetchMarketSkillDetails: _fetchMarketSkillDetails,
        installMarketSkill: ({required skill, required target}) async {
          installed = true;
          installedTarget = target;
          return SkillsCliInstallResult(
            packageId: skill.marketSource ?? skill.marketId ?? skill.id,
            target: target,
            outputPath: r'D:\project\.codex\skills\test',
            output: 'installed',
          );
        },
      ),
    );

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'agent-manager'));
    await tester.pumpAndSettle();

    expect(installed, isTrue);
    expect(installedTarget?.type, SkillInstallTargetType.project);

    await tester.tap(find.byIcon(Icons.workspace_premium_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Market Skill'), findsWidgets);
    expect(find.text('Install source'), findsOneWidget);
  });

  testWidgets('market skill selection shows detailed files', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AgentManagerApp(
        fetchMarketSkills: ({String query = ''}) async => _marketSkills,
        fetchMarketSkillDetails: _fetchMarketSkillDetails,
        installMarketSkill: _installMarketSkill,
      ),
    );

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Market Skill'));
    await tester.pumpAndSettle();

    expect(find.text('Sub skills'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Review Helper'), findsOneWidget);
    expect(find.text('review-helper/SKILL.md'), findsWidgets);
    expect(find.textContaining('Review helper workflow.'), findsOneWidget);
  });
}

Future<SkillsCliInstallResult> _installMarketSkill({
  required PromptItem skill,
  required SkillInstallTarget target,
}) async {
  return SkillsCliInstallResult(
    packageId: skill.marketSource ?? skill.marketId ?? skill.id,
    target: target,
    output: 'installed',
  );
}

Future<PromptItem> _fetchMarketSkillDetails(PromptItem skill) async {
  return skill.copyWith(
    content: 'Primary market skill workflow.',
    marketFiles: const [
      SkillFile(path: 'SKILL.md', contents: 'Primary market skill workflow.'),
      SkillFile(
        path: 'review-helper/SKILL.md',
        contents: 'Review helper workflow.',
      ),
      SkillFile(path: 'assets/checklist.md', contents: '- check tests'),
    ],
  );
}

final List<PromptItem> _marketSkills = [
  PromptItem(
    id: 'market-test',
    title: 'Market Skill',
    description: 'A skill loaded from the test market source.',
    content: 'Use this skill for tests.',
    kind: PromptKind.skill,
    scope: PromptScope.project,
    enabledAgents: const {},
    enabledProjectIds: const {},
    source: 'skills.sh',
    marketId: 'test',
    marketSource: 'owner/skills/test',
    installs: 42,
    isVerified: true,
  ),
];
