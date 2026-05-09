// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appSubtitle => '规则与技能管理';

  @override
  String get agents => '支持 Agent';

  @override
  String get project => '项目';

  @override
  String get writeProjectPrompts => '写入项目 Prompt';

  @override
  String get mine => '我的';

  @override
  String get market => '市场';

  @override
  String get marketUnavailable => '市场暂时不可用';

  @override
  String get retry => '重试';

  @override
  String get noSkillsFound => '没有找到 skills';

  @override
  String get noSkillsMessage => 'skills.sh 没有返回任何 skill。';

  @override
  String get refresh => '刷新';

  @override
  String get noPrompts => '暂无 Prompts';

  @override
  String get noPromptsMessage => '这里还没有本地 prompt。';

  @override
  String get installToCurrentProject => '安装到当前项目';

  @override
  String get selectPrompt => '选择一个 Prompt';

  @override
  String get selectPromptMessage => '点击一个 prompt 来管理 agent 和项目开关。';

  @override
  String get agentToggles => 'Agent 开关';

  @override
  String get scope => '作用范围';

  @override
  String get global => '全局';

  @override
  String get promptContent => 'Prompt 内容';

  @override
  String get rules => '规则';

  @override
  String get skills => '技能';

  @override
  String get projects => '项目';

  @override
  String get on => '已启用';

  @override
  String get off => '未启用';

  @override
  String get rule => '规则';

  @override
  String get skill => '技能';

  @override
  String allowAgent(String agent) {
    return '允许 $agent 使用这个 prompt';
  }

  @override
  String wroteProjectPrompts(String summary) {
    return '已写入项目 prompts。$summary';
  }

  @override
  String failedToWritePrompts(Object error) {
    return '写入 prompts 失败：$error';
  }
}
