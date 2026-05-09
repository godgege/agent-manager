import 'dart:io';

import 'package:agent_manager/models/prompt_item.dart';
import 'package:agent_manager/services/project_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects agent files in project folder', () async {
    final temp = await Directory.systemTemp.createTemp('project-scanner-test');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/AGENTS.md').writeAsString('codex');
    await File('${temp.path}/CLAUDE.md').writeAsString('claude');

    final project = await ProjectScanner().scan(temp.path);

    expect(project.name, temp.uri.pathSegments.where((p) => p.isNotEmpty).last);
    expect(project.detectedAgents, {AgentRuntime.codex, AgentRuntime.claude});
  });
}
