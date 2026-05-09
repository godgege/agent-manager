// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appSubtitle => 'Rules and skills';

  @override
  String get agents => 'Agents';

  @override
  String get project => 'Project';

  @override
  String get writeProjectPrompts => 'Write project prompts';

  @override
  String get mine => 'Mine';

  @override
  String get market => 'Market';

  @override
  String get marketUnavailable => 'Market unavailable';

  @override
  String get retry => 'Retry';

  @override
  String get noSkillsFound => 'No skills found';

  @override
  String get noSkillsMessage => 'skills.sh did not return any skills.';

  @override
  String get refresh => 'Refresh';

  @override
  String get noPrompts => 'No prompts';

  @override
  String get noPromptsMessage => 'There are no local prompts here yet.';

  @override
  String get installToCurrentProject => 'Install to current project';

  @override
  String get selectPrompt => 'Select a prompt';

  @override
  String get selectPromptMessage =>
      'Click a prompt to manage agent and project toggles.';

  @override
  String get agentToggles => 'Agent toggles';

  @override
  String get scope => 'Scope';

  @override
  String get global => 'Global';

  @override
  String get promptContent => 'Prompt content';

  @override
  String get rules => 'Rules';

  @override
  String get skills => 'Skills';

  @override
  String get projects => 'Projects';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get rule => 'Rule';

  @override
  String get skill => 'Skill';

  @override
  String allowAgent(String agent) {
    return 'Allow $agent to use this prompt';
  }

  @override
  String wroteProjectPrompts(String summary) {
    return 'Wrote project prompts. $summary';
  }

  @override
  String failedToWritePrompts(Object error) {
    return 'Failed to write prompts: $error';
  }
}
