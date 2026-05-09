import 'dart:convert';
import 'dart:io';

class SkillsMarketCredentials {
  const SkillsMarketCredentials({this.apiKey});

  static const environmentKey = 'SKILLS_SH_API_KEY';
  static const localConfigPath = '.agent_manager/skills_market.json';

  final String? apiKey;

  bool get hasApiKey => apiKey != null && apiKey!.trim().isNotEmpty;

  static Future<SkillsMarketCredentials> load({File? configFile}) async {
    final environmentApiKey = Platform.environment[environmentKey]?.trim();
    if (environmentApiKey != null && environmentApiKey.isNotEmpty) {
      return SkillsMarketCredentials(apiKey: environmentApiKey);
    }

    final file = configFile ?? File(localConfigPath);
    if (!await file.exists()) {
      return const SkillsMarketCredentials();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const SkillsMarketCredentials();
      }

      final apiKey = _readString(decoded, const [
        'apiKey',
        'skillsShApiKey',
      ])?.trim();
      if (apiKey == null || apiKey.isEmpty) {
        return const SkillsMarketCredentials();
      }

      return SkillsMarketCredentials(apiKey: apiKey);
    } on Object {
      return const SkillsMarketCredentials();
    }
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }
}
