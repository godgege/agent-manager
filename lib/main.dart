import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/prompt_manager_screen.dart';

void main() {
  runApp(const AgentManagerApp());
}

class AgentManagerApp extends StatefulWidget {
  const AgentManagerApp({
    super.key,
    this.fetchMarketSkills,
    this.fetchMarketSkillDetails,
    this.installMarketSkill,
  });

  final FetchMarketSkills? fetchMarketSkills;
  final FetchMarketSkillDetails? fetchMarketSkillDetails;
  final InstallMarketSkill? installMarketSkill;

  @override
  State<AgentManagerApp> createState() => _AgentManagerAppState();
}

class _AgentManagerAppState extends State<AgentManagerApp> {
  Locale _locale = const Locale('zh');

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agent Manager',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B57D0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFBFCFE),
        useMaterial3: true,
      ),
      home: PromptManagerScreen(
        fetchMarketSkills: widget.fetchMarketSkills,
        fetchMarketSkillDetails: widget.fetchMarketSkillDetails,
        installMarketSkill: widget.installMarketSkill,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}
