import 'dart:convert';
import 'dart:io';

import 'package:agent_manager/services/skills_market_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load reads api key from local config file', () async {
    final temp = await Directory.systemTemp.createTemp(
      'skills-market-credentials-test',
    );
    addTearDown(() => temp.delete(recursive: true));

    final configFile = File('${temp.path}/skills_market.json');
    await configFile.writeAsString(jsonEncode({'apiKey': 'test-api-key'}));

    final credentials = await SkillsMarketCredentials.load(
      configFile: configFile,
    );

    expect(credentials.apiKey, 'test-api-key');
    expect(credentials.hasApiKey, isTrue);
  });

  test('load returns empty credentials for missing config file', () async {
    final temp = await Directory.systemTemp.createTemp(
      'skills-market-credentials-test',
    );
    addTearDown(() => temp.delete(recursive: true));

    final credentials = await SkillsMarketCredentials.load(
      configFile: File('${temp.path}/missing.json'),
    );

    expect(credentials.hasApiKey, isFalse);
  });
}
