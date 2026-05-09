import 'package:flutter/material.dart';

import '../data/prompt_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/prompt_item.dart';
import '../services/project_prompt_writer.dart';
import '../services/skills_cli_service.dart';
import '../services/skills_market_service.dart';

typedef FetchMarketSkills = Future<List<PromptItem>> Function({String query});
typedef FetchMarketSkillDetails = Future<PromptItem> Function(PromptItem item);
typedef InstallMarketSkill =
    Future<SkillsCliInstallResult> Function({
      required PromptItem skill,
      required SkillInstallTarget target,
    });

enum PromptSection { rules, skills, projects }

enum SkillSourceTab { mine, market }

enum AppLanguage { zh, en }

extension AppLanguageLocale on AppLanguage {
  Locale get locale {
    switch (this) {
      case AppLanguage.zh:
        return const Locale('zh');
      case AppLanguage.en:
        return const Locale('en');
    }
  }
}

extension PromptSectionText on PromptSection {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case PromptSection.rules:
        return l10n.rules;
      case PromptSection.skills:
        return l10n.skills;
      case PromptSection.projects:
        return l10n.projects;
    }
  }
}

extension PromptKindText on PromptKind {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case PromptKind.rule:
        return l10n.rule;
      case PromptKind.skill:
        return l10n.skill;
    }
  }
}

extension PromptScopeText on PromptScope {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case PromptScope.global:
        return l10n.global;
      case PromptScope.project:
        return l10n.project;
    }
  }
}

class PromptManagerScreen extends StatefulWidget {
  const PromptManagerScreen({
    super.key,
    FetchMarketSkills? fetchMarketSkills,
    FetchMarketSkillDetails? fetchMarketSkillDetails,
    InstallMarketSkill? installMarketSkill,
    required this.onLocaleChanged,
  }) : fetchMarketSkills = fetchMarketSkills ?? _fetchDefaultMarketSkills,
       fetchMarketSkillDetails =
           fetchMarketSkillDetails ?? _fetchDefaultMarketSkillDetails,
       installMarketSkill = installMarketSkill ?? _installDefaultMarketSkill;

  final FetchMarketSkills fetchMarketSkills;
  final FetchMarketSkillDetails fetchMarketSkillDetails;
  final InstallMarketSkill installMarketSkill;
  final ValueChanged<Locale> onLocaleChanged;

  static Future<List<PromptItem>> _fetchDefaultMarketSkills({
    String query = '',
  }) {
    return SkillsMarketService().fetchSkills(query: query);
  }

  static Future<PromptItem> _fetchDefaultMarketSkillDetails(PromptItem item) {
    return SkillsMarketService().fetchSkillDetails(item);
  }

  static Future<SkillsCliInstallResult> _installDefaultMarketSkill({
    required PromptItem skill,
    required SkillInstallTarget target,
  }) {
    return SkillsCliService().installSkill(skill: skill, target: target);
  }

  @override
  State<PromptManagerScreen> createState() => _PromptManagerScreenState();
}

class _PromptManagerScreenState extends State<PromptManagerScreen> {
  final PromptStore _store = PromptStore();
  final ProjectPromptWriter _promptWriter = ProjectPromptWriter();
  final TextEditingController _searchController = TextEditingController();

  PromptSection _section = PromptSection.skills;
  SkillSourceTab _skillSourceTab = SkillSourceTab.mine;
  AppLanguage _language = AppLanguage.zh;
  AgentRuntime? _activeAgentScene;
  Future<List<PromptItem>>? _marketSkillsFuture;
  PromptItem? _selectedMarketSkill;
  Future<PromptItem>? _selectedMarketSkillDetailsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _searchController.addListener(_onSearchChanged);
    final firstSkill = _store.localSkills.firstOrNull;
    if (firstSkill != null) {
      _store.selectItem(firstSkill.id);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    setState(() {});
  }

  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text.trim();
      if (_skillSourceTab == SkillSourceTab.market) {
        _marketSkillsFuture = widget.fetchMarketSkills(query: _query);
        _selectedMarketSkill = null;
        _selectedMarketSkillDetailsFuture = null;
      }
    });
  }

  void _loadMarketSkills() {
    _marketSkillsFuture ??= widget.fetchMarketSkills(query: _query);
  }

  void _reloadMarketSkills() {
    _marketSkillsFuture = widget.fetchMarketSkills(query: _query);
    _selectedMarketSkill = null;
    _selectedMarketSkillDetailsFuture = null;
  }

  void _setLanguage(AppLanguage language) {
    setState(() {
      _language = language;
    });
    widget.onLocaleChanged(language.locale);
  }

  void _selectSection(PromptSection section) {
    setState(() {
      _activeAgentScene = null;
      _section = section;
      if (section == PromptSection.projects && _store.projects.isNotEmpty) {
        _store.setSelectedProjectSilently(_store.projects.first.id);
      }
      if (section != PromptSection.skills) {
        _selectedMarketSkill = null;
        _selectedMarketSkillDetailsFuture = null;
      }
    });
    if (section == PromptSection.projects) {
      _store.clearSelection();
      return;
    }

    final firstItem = section == PromptSection.rules
        ? _store.rules.firstOrNull
        : _store.localSkills.firstOrNull;
    if (firstItem != null) {
      _store.selectItem(firstItem.id);
    }
  }

  void _selectProject(AgentProject project) {
    setState(() {
      _activeAgentScene = null;
      _section = PromptSection.projects;
      _store.setSelectedProjectSilently(project.id);
    });
    _store.clearSelection();
  }

  Future<void> _showAddProjectDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: r'D:\_my\test-agent-manager',
    );
    final messenger = ScaffoldMessenger.of(context);

    try {
      final path = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add project'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Project path',
                hintText: r'D:\_my\test-agent-manager',
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );

      if (path == null || path.trim().isEmpty) {
        return;
      }

      final project = await _store.addProjectPath(path.trim());
      if (!mounted) {
        return;
      }

      setState(() {
        _activeAgentScene = null;
        _section = PromptSection.projects;
        _selectedMarketSkill = null;
        _selectedMarketSkillDetailsFuture = null;
      });
      _store.clearSelection();
      messenger.showSnackBar(
        SnackBar(content: Text('Added project ${project.name}')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      controller.dispose();
    }
  }

  void _selectSkillTab(SkillSourceTab tab) {
    setState(() {
      _activeAgentScene = null;
      _section = PromptSection.skills;
      _skillSourceTab = tab;
      if (tab == SkillSourceTab.market) {
        _loadMarketSkills();
        _store.clearSelection();
      } else {
        _selectedMarketSkill = null;
        _selectedMarketSkillDetailsFuture = null;
      }
    });
    if (tab == SkillSourceTab.mine) {
      final selectedSkillIsLocal = _store.localSkills.any(
        (skill) => skill.id == _store.selectedItemId,
      );
      final firstSkill = selectedSkillIsLocal
          ? null
          : _store.localSkills.firstOrNull;
      if (!selectedSkillIsLocal && firstSkill != null) {
        _store.selectItem(firstSkill.id);
      }
    }
  }

  Future<void> _writeProjectPrompts() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    try {
      final results = await _promptWriter.writeEnabledPrompts(
        store: _store,
        project: _store.selectedProject,
      );
      final summary = results
          .map((result) => '${result.agent.label}: ${result.promptCount}')
          .join(', ');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.wroteProjectPrompts(summary))),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.failedToWritePrompts(error))),
      );
    }
  }

  void _selectMarketSkill(PromptItem item) {
    setState(() {
      _activeAgentScene = null;
      _section = PromptSection.skills;
      _skillSourceTab = SkillSourceTab.market;
      _selectedMarketSkill = item;
      _selectedMarketSkillDetailsFuture = widget.fetchMarketSkillDetails(item);
      _store.clearSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Row(
          children: [
            _SideNavigation(
              section: _section,
              skillSourceTab: _skillSourceTab,
              language: _language,
              activeAgentScene: _activeAgentScene,
              store: _store,
              onSectionChanged: _selectSection,
              onSkillSourceChanged: _selectSkillTab,
              onProjectChanged: _selectProject,
              onAddProject: () => _showAddProjectDialog(context),
              onAgentChanged: _openAgentScene,
              onLanguageChanged: _setLanguage,
            ),
            Expanded(
              child: Column(
                children: [
                  _TopToolbar(
                    title: _toolbarTitle(l10n),
                    searchController: _searchController,
                    showSearch: _activeAgentScene == null,
                    onRefresh:
                        _activeAgentScene == null &&
                            _skillSourceTab == SkillSourceTab.market
                        ? () {
                            setState(_reloadMarketSkills);
                          }
                        : null,
                  ),
                  Expanded(child: _buildScene()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _toolbarTitle(AppLocalizations l10n) {
    final agent = _activeAgentScene;
    if (agent != null) {
      return agent.label;
    }

    return _section.localizedLabel(l10n);
  }

  Widget _buildScene() {
    final agent = _activeAgentScene;
    if (agent != null) {
      return const _AgentBlankScene();
    }

    if (_section == PromptSection.projects) {
      return _ProjectsScene(store: _store);
    }

    return Row(
      children: [
        SizedBox(
          width: 500,
          child: _RegistryListPane(
            section: _section,
            skillSourceTab: _skillSourceTab,
            store: _store,
            query: _query,
            marketSkillsFuture: _marketSkillsFuture,
            selectedMarketSkillId: _selectedMarketSkill?.id,
            onSkillSourceChanged: _selectSkillTab,
            onMarketSkillSelected: _selectMarketSkill,
            onRetryMarket: () {
              setState(_reloadMarketSkills);
            },
          ),
        ),
        Expanded(
          child: _PromptDetailPanel(
            store: _store,
            skillSourceTab: _skillSourceTab,
            selectedMarketSkill: _selectedMarketSkill,
            marketSkillDetailsFuture: _selectedMarketSkillDetailsFuture,
            onInstallMarketSkill: widget.installMarketSkill,
            onAddSkillToLibrary: _store.addSkillToLibrary,
            onWriteProjectPrompts: _writeProjectPrompts,
          ),
        ),
      ],
    );
  }

  void _openAgentScene(AgentRuntime agent) {
    setState(() {
      _activeAgentScene = agent;
      _selectedMarketSkill = null;
      _selectedMarketSkillDetailsFuture = null;
      _store.clearSelection();
    });
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.section,
    required this.skillSourceTab,
    required this.language,
    required this.activeAgentScene,
    required this.store,
    required this.onSectionChanged,
    required this.onSkillSourceChanged,
    required this.onProjectChanged,
    required this.onAddProject,
    required this.onAgentChanged,
    required this.onLanguageChanged,
  });

  final PromptSection section;
  final SkillSourceTab skillSourceTab;
  final AppLanguage language;
  final AgentRuntime? activeAgentScene;
  final PromptStore store;
  final ValueChanged<PromptSection> onSectionChanged;
  final ValueChanged<SkillSourceTab> onSkillSourceChanged;
  final ValueChanged<AgentProject> onProjectChanged;
  final VoidCallback onAddProject;
  final ValueChanged<AgentRuntime> onAgentChanged;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: 248,
      margin: const EdgeInsets.fromLTRB(10, 10, 0, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E4E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _WindowDots(),
            const SizedBox(height: 24),
            _NavGroupLabel(label: l10n.skills),
            const SizedBox(height: 8),
            _NavRow(
              icon: Icons.workspace_premium_outlined,
              label: l10n.mine,
              count: store.localSkills.length,
              selected:
                  activeAgentScene == null &&
                  section == PromptSection.skills &&
                  skillSourceTab == SkillSourceTab.mine,
              indent: 8,
              onTap: () => onSkillSourceChanged(SkillSourceTab.mine),
            ),
            _NavRow(
              icon: Icons.storefront_outlined,
              label: l10n.market,
              count: null,
              selected:
                  activeAgentScene == null &&
                  section == PromptSection.skills &&
                  skillSourceTab == SkillSourceTab.market,
              indent: 8,
              onTap: () => onSkillSourceChanged(SkillSourceTab.market),
            ),
            const SizedBox(height: 18),
            _NavGroupLabel(label: l10n.agents),
            const SizedBox(height: 8),
            _AgentCountRow(
              agent: AgentRuntime.codex,
              count: _agentCount(AgentRuntime.codex),
              selected: activeAgentScene == AgentRuntime.codex,
              indent: 8,
              onTap: () => onAgentChanged(AgentRuntime.codex),
            ),
            _AgentCountRow(
              agent: AgentRuntime.gemini,
              count: _agentCount(AgentRuntime.gemini),
              selected: activeAgentScene == AgentRuntime.gemini,
              indent: 8,
              onTap: () => onAgentChanged(AgentRuntime.gemini),
            ),
            _AgentCountRow(
              agent: AgentRuntime.claude,
              count: _agentCount(AgentRuntime.claude),
              selected: activeAgentScene == AgentRuntime.claude,
              indent: 8,
              onTap: () => onAgentChanged(AgentRuntime.claude),
            ),
            const SizedBox(height: 18),
            _NavGroupLabel(
              label: l10n.projects,
              action: IconButton(
                tooltip: 'Add project',
                onPressed: onAddProject,
                icon: const Icon(Icons.add_rounded, size: 18),
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(26),
                  fixedSize: const Size.square(26),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final project in store.projects)
              _NavRow(
                icon: Icons.folder_copy_outlined,
                label: project.name,
                count: _projectCount(project.id),
                selected:
                    activeAgentScene == null &&
                    section == PromptSection.projects &&
                    project.id == store.selectedProjectId,
                indent: 8,
                onTap: () => onProjectChanged(project),
              ),
            const Spacer(),
            _LanguageToggle(language: language, onChanged: onLanguageChanged),
          ],
        ),
      ),
    );
  }

  int _agentCount(AgentRuntime agent) {
    return store.allItems
        .where((item) => item.enabledAgents.contains(agent))
        .length;
  }

  int _projectCount(String projectId) {
    return store.allItems
        .where(
          (item) =>
              item.scope == PromptScope.project &&
              item.enabledProjectIds.contains(projectId),
        )
        .length;
  }
}

class _AgentCountRow extends StatelessWidget {
  const _AgentCountRow({
    required this.agent,
    required this.count,
    required this.selected,
    this.indent = 0,
    required this.onTap,
  });

  final AgentRuntime agent;
  final int count;
  final bool selected;
  final double indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NavRow(
      icon: _agentIcon(agent),
      label: agent.label,
      count: count,
      selected: selected,
      indent: indent,
      onTap: onTap,
    );
  }

  IconData _agentIcon(AgentRuntime agent) {
    switch (agent) {
      case AgentRuntime.codex:
        return Icons.terminal_rounded;
      case AgentRuntime.gemini:
        return Icons.auto_awesome_rounded;
      case AgentRuntime.claude:
        return Icons.code_rounded;
    }
  }
}

class _WindowDots extends StatelessWidget {
  const _WindowDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _WindowDot(color: Color(0xFFFF5F57)),
        SizedBox(width: 8),
        _WindowDot(color: Color(0xFFFFBD2E)),
        SizedBox(width: 8),
        _WindowDot(color: Color(0xFF28C840)),
      ],
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 13),
    );
  }
}

class _NavGroupLabel extends StatelessWidget {
  const _NavGroupLabel({required this.label, this.action});

  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    this.count,
    required this.selected,
    this.indent = 0,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool selected;
  final double indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: EdgeInsets.only(left: 8 + indent, right: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0E2E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade800),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count != null) _CountPill(count: count!),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          '$count',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.title,
    required this.searchController,
    required this.showSearch,
    required this.onRefresh,
  });

  final String title;
  final TextEditingController searchController;
  final bool showSearch;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Open',
            onPressed: () {},
            icon: const Icon(Icons.explore_outlined),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (showSearch)
            SizedBox(
              width: 310,
              height: 42,
              child: SearchBar(
                controller: searchController,
                hintText: 'Search skills.sh',
                leading: const Icon(Icons.search_rounded, size: 18),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(Colors.grey.shade100),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegistryListPane extends StatelessWidget {
  const _RegistryListPane({
    required this.section,
    required this.skillSourceTab,
    required this.store,
    required this.query,
    required this.marketSkillsFuture,
    required this.selectedMarketSkillId,
    required this.onSkillSourceChanged,
    required this.onMarketSkillSelected,
    required this.onRetryMarket,
  });

  final PromptSection section;
  final SkillSourceTab skillSourceTab;
  final PromptStore store;
  final String query;
  final Future<List<PromptItem>>? marketSkillsFuture;
  final String? selectedMarketSkillId;
  final ValueChanged<SkillSourceTab> onSkillSourceChanged;
  final ValueChanged<PromptItem> onMarketSkillSelected;
  final VoidCallback onRetryMarket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: _buildList(context, l10n),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (section == PromptSection.rules) {
      final items = _filter(store.rules);
      return _PromptList(
        items: items,
        selectedItemId: store.selectedItemId,
        selectedProjectId: store.selectedProjectId,
        onSelected: store.selectItem,
      );
    }

    if (skillSourceTab == SkillSourceTab.mine) {
      final items = _filter(store.localSkills);
      return _PromptList(
        items: items,
        selectedItemId: store.selectedItemId,
        selectedProjectId: store.selectedProjectId,
        onSelected: store.selectItem,
      );
    }

    final future = marketSkillsFuture;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<PromptItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.marketUnavailable,
            message: snapshot.error.toString(),
            actionLabel: l10n.retry,
            onAction: onRetryMarket,
          );
        }

        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.search_off_outlined,
            title: l10n.noSkillsFound,
            message: l10n.noSkillsMessage,
            actionLabel: l10n.refresh,
            onAction: onRetryMarket,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return _MarketSkillTile(
              item: item,
              selected: selectedMarketSkillId == item.id,
              onTap: () => onMarketSkillSelected(item),
            );
          },
        );
      },
    );
  }

  List<PromptItem> _filter(List<PromptItem> items) {
    if (query.isEmpty) {
      return items;
    }

    final normalizedQuery = query.toLowerCase();
    return items
        .where(
          (item) =>
              item.title.toLowerCase().contains(normalizedQuery) ||
              item.description.toLowerCase().contains(normalizedQuery) ||
              item.content.toLowerCase().contains(normalizedQuery),
        )
        .toList();
  }
}

class _AgentBlankScene extends StatelessWidget {
  const _AgentBlankScene();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Colors.white),
      child: SizedBox.expand(),
    );
  }
}

class _ProjectsScene extends StatelessWidget {
  const _ProjectsScene({required this.store});

  final PromptStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        SizedBox(
          width: 500,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    itemCount: store.projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final project = store.projects[index];
                      final promptCount = _projectPrompts(project.id).length;

                      return _ProjectTile(
                        project: project,
                        count: promptCount,
                        selected: project.id == store.selectedProjectId,
                        onTap: () => store.selectProject(project.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white),
            child: Builder(
              builder: (context) {
                final selectedProject = store.selectedProject;

                return _ProjectPromptDetails(
                  project: selectedProject,
                  prompts: _projectPrompts(selectedProject.id),
                  l10n: l10n,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<PromptItem> _projectPrompts(String projectId) {
    return store.allItems
        .where(
          (item) =>
              item.scope == PromptScope.project &&
              item.enabledProjectIds.contains(projectId),
        )
        .toList();
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final AgentProject project;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEDEFF2) : const Color(0xFFF8F8F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: selected ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.folder_copy_outlined, color: Colors.grey.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (project.detectedAgents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final agent in project.detectedAgents)
                            _StatusChip(label: agent.label, selected: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CountPill(count: count),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectPromptDetails extends StatelessWidget {
  const _ProjectPromptDetails({
    required this.project,
    required this.prompts,
    required this.l10n,
  });

  final AgentProject project;
  final List<PromptItem> prompts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) {
      return _EmptyState(
        icon: Icons.folder_off_outlined,
        title: project.name,
        message: l10n.noPromptsMessage,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
      children: [
        Text(
          project.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          project.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        const _Divider(),
        _SectionTitle(title: l10n.projects),
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProjectPromptCard(prompt: prompt, l10n: l10n),
          ),
      ],
    );
  }
}

class _ProjectPromptCard extends StatelessWidget {
  const _ProjectPromptCard({required this.prompt, required this.l10n});

  final PromptItem prompt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prompt.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(
                label: prompt.kind.localizedLabel(l10n),
                selected: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prompt.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final agent in prompt.enabledAgents)
                _StatusChip(label: agent.label, selected: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptList extends StatelessWidget {
  const _PromptList({
    required this.items,
    required this.selectedItemId,
    required this.selectedProjectId,
    required this.onSelected,
  });

  final List<PromptItem> items;
  final String? selectedItemId;
  final String selectedProjectId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.inbox_outlined,
        title: l10n.noPrompts,
        message: l10n.noPromptsMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return _PromptTile(
          item: item,
          selected: selectedItemId == item.id,
          enabledForProject: item.isEnabledForProject(selectedProjectId),
          onTap: () => onSelected(item.id),
        );
      },
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({
    required this.item,
    required this.selected,
    required this.enabledForProject,
    required this.onTap,
  });

  final PromptItem item;
  final bool selected;
  final bool enabledForProject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: selected ? const Color(0xFFEDEFF2) : const Color(0xFFF8F8F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: selected ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: enabledForProject ? l10n.on : l10n.off,
                          selected: enabledForProject,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.source == 'local'
                                ? '~/.agents/${item.kind.name}s/${item.id}'
                                : item.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _InstallCount(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketSkillTile extends StatelessWidget {
  const _MarketSkillTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PromptItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEDEFF2) : const Color(0xFFF8F8F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: selected ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _sourceDirectory(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (item.isVerified) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Verified safe skill',
                            child: Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _DownloadCount(item: item),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceDirectory(PromptItem item) {
    final source = item.marketSource?.trim();
    if (source != null && source.isNotEmpty) {
      final segments = source
          .split('/')
          .where((segment) => segment.trim().isNotEmpty)
          .toList();
      if (segments.length > 1) {
        return segments.take(segments.length - 1).join('/');
      }

      return source;
    }

    return item.author ?? item.source;
  }
}

class _DownloadCount extends StatelessWidget {
  const _DownloadCount({required this.item});

  final PromptItem item;

  @override
  Widget build(BuildContext context) {
    final installs = item.installs;
    if (installs == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.download_outlined, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(
          _formatCount(installs),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return '$value';
  }
}

class _InstallSkillMenu extends StatefulWidget {
  const _InstallSkillMenu({required this.projects, required this.onInstall});

  final List<AgentProject> projects;
  final Future<void> Function(SkillInstallTarget target) onInstall;

  @override
  State<_InstallSkillMenu> createState() => _InstallSkillMenuState();
}

class _InstallSkillMenuState extends State<_InstallSkillMenu> {
  bool _installing = false;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return FilledButton.tonalIcon(
          onPressed: _installing
              ? null
              : () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
          icon: _installing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 16),
          label: const Text('Install'),
        );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.workspace_premium_outlined),
          onPressed: () => _install(const SkillInstallTarget.library()),
          child: const Text('Add to Mine'),
        ),
        const Divider(height: 1),
        for (final agent in AgentRuntime.values)
          MenuItemButton(
            leadingIcon: Icon(_agentIcon(agent)),
            onPressed: () => _install(SkillInstallTarget.globalAgent(agent)),
            child: Text('${agent.label} global'),
          ),
        const Divider(height: 1),
        for (final project in widget.projects)
          MenuItemButton(
            leadingIcon: const Icon(Icons.folder_copy_outlined),
            onPressed: () =>
                _install(SkillInstallTarget.project(project: project)),
            child: Text(project.name),
          ),
      ],
    );
  }

  Future<void> _install(SkillInstallTarget target) async {
    setState(() {
      _installing = true;
    });

    try {
      await widget.onInstall(target);
    } finally {
      if (mounted) {
        setState(() {
          _installing = false;
        });
      }
    }
  }

  IconData _agentIcon(AgentRuntime agent) {
    switch (agent) {
      case AgentRuntime.codex:
        return Icons.terminal_rounded;
      case AgentRuntime.gemini:
        return Icons.auto_awesome_rounded;
      case AgentRuntime.claude:
        return Icons.code_rounded;
    }
  }
}

class _InstallCount extends StatelessWidget {
  const _InstallCount({required this.item});

  final PromptItem item;

  @override
  Widget build(BuildContext context) {
    final installs = item.installs;
    if (installs == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatCount(installs),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          'installs',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return '$value';
  }
}

class _PromptDetailPanel extends StatelessWidget {
  const _PromptDetailPanel({
    required this.store,
    required this.skillSourceTab,
    required this.selectedMarketSkill,
    required this.marketSkillDetailsFuture,
    required this.onInstallMarketSkill,
    required this.onAddSkillToLibrary,
    required this.onWriteProjectPrompts,
  });

  final PromptStore store;
  final SkillSourceTab skillSourceTab;
  final PromptItem? selectedMarketSkill;
  final Future<PromptItem>? marketSkillDetailsFuture;
  final InstallMarketSkill onInstallMarketSkill;
  final PromptItem Function(PromptItem skill) onAddSkillToLibrary;
  final Future<void> Function() onWriteProjectPrompts;

  @override
  Widget build(BuildContext context) {
    final item = store.selectedItem;
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: skillSourceTab == SkillSourceTab.market
          ? selectedMarketSkill == null
                ? const _EmptyState(
                    icon: Icons.touch_app_outlined,
                    title: 'Select a market skill',
                    message: 'Choose a skill to inspect its files.',
                  )
                : _MarketSkillDetails(
                    fallback: selectedMarketSkill!,
                    detailsFuture: marketSkillDetailsFuture,
                    store: store,
                    onInstallMarketSkill: onInstallMarketSkill,
                    onAddSkillToLibrary: onAddSkillToLibrary,
                  )
          : item == null
          ? _EmptyState(
              icon: Icons.touch_app_outlined,
              title: l10n.selectPrompt,
              message: l10n.selectPromptMessage,
            )
          : _PromptDetails(
              store: store,
              item: item,
              onInstallMarketSkill: onInstallMarketSkill,
              onWriteProjectPrompts: onWriteProjectPrompts,
            ),
    );
  }
}

class _PromptDetails extends StatelessWidget {
  const _PromptDetails({
    required this.store,
    required this.item,
    required this.onInstallMarketSkill,
    required this.onWriteProjectPrompts,
  });

  final PromptStore store;
  final PromptItem item;
  final InstallMarketSkill onInstallMarketSkill;
  final Future<void> Function() onWriteProjectPrompts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusChip(
                          label: item.kind.localizedLabel(l10n),
                          selected: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ID: ${item.id}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Registry: ${item.source}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onWriteProjectPrompts,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: Text(l10n.writeProjectPrompts),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _Divider(),
          _SectionTitle(title: 'Package Info'),
          _InfoRow(label: 'Source', value: item.source),
          _InfoRow(label: 'URL', value: _itemUrl(item)),
          _InfoRow(label: 'Kind', value: item.kind.localizedLabel(l10n)),
          _InfoRow(label: 'Scope', value: item.scope.localizedLabel(l10n)),
          if (item.installedPackageId != null)
            _InfoRow(label: 'Package', value: item.installedPackageId!),
          if (item.installTargetType != null)
            _InfoRow(label: 'Install target', value: _installTargetLabel(item)),
          if (item.installedSource != null)
            _InfoRow(label: 'Install source', value: item.installedSource!),
          if (item.installedPath != null)
            _InfoRow(label: 'Install path', value: item.installedPath!),
          const SizedBox(height: 24),
          const _Divider(),
          _SectionTitle(title: l10n.scope),
          _ScopeCard(store: store, item: item),
          if (_canMoveToGlobal(item)) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _moveToGlobal(context, item),
              icon: const Icon(Icons.public_outlined, size: 18),
              label: const Text('Move to global'),
            ),
          ],
          const SizedBox(height: 24),
          const _Divider(),
          _SectionTitle(title: 'Agents'),
          Text(
            'Choose which local agents should receive this prompt.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.3),
          ),
          const SizedBox(height: 12),
          _AgentsCard(store: store, item: item),
          const SizedBox(height: 24),
          const _Divider(),
          _SectionTitle(title: l10n.promptContent),
          _PromptContentCard(content: item.content),
        ],
      ),
    );
  }

  String _itemUrl(PromptItem item) {
    return item.source == 'skills.sh'
        ? 'https://skills.sh/${item.id.replaceFirst('market-', '')}'
        : '~/.agents/${item.kind.name}s/${item.id}';
  }

  String _installTargetLabel(PromptItem item) {
    switch (item.installTargetType!) {
      case SkillInstallTargetType.library:
        return 'My library';
      case SkillInstallTargetType.globalAgent:
        return '${item.installedAgent?.label ?? 'Agent'} global';
      case SkillInstallTargetType.project:
        final project = item.installedProjectPath ?? item.installedProjectId;
        return project == null ? 'Project' : 'Project: $project';
    }
  }

  bool _canMoveToGlobal(PromptItem item) {
    return item.kind == PromptKind.skill &&
        item.scope == PromptScope.project &&
        item.hasInstallSource;
  }

  Future<void> _moveToGlobal(BuildContext context, PromptItem item) async {
    final agent = item.enabledAgents.firstOrNull ?? AgentRuntime.codex;
    final target = SkillInstallTarget.globalAgent(agent);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await onInstallMarketSkill(skill: item, target: target);
      store.moveSkill(
        item,
        target: target,
        packageId: result.packageId,
        installedPath: result.outputPath ?? item.installedPath,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Moved ${item.title} to ${target.label}')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _MarketSkillDetails extends StatelessWidget {
  const _MarketSkillDetails({
    required this.fallback,
    required this.detailsFuture,
    required this.store,
    required this.onInstallMarketSkill,
    required this.onAddSkillToLibrary,
  });

  final PromptItem fallback;
  final Future<PromptItem>? detailsFuture;
  final PromptStore store;
  final InstallMarketSkill onInstallMarketSkill;
  final PromptItem Function(PromptItem skill) onAddSkillToLibrary;

  @override
  Widget build(BuildContext context) {
    final future = detailsFuture;
    if (future == null) {
      return _buildDetails(context, fallback, isLoading: false);
    }

    return FutureBuilder<PromptItem>(
      future: future,
      builder: (context, snapshot) {
        final item = snapshot.data ?? fallback;
        final isLoading = snapshot.connectionState != ConnectionState.done;

        return _buildDetails(
          context,
          item,
          isLoading: isLoading,
          error: snapshot.error,
        );
      },
    );
  }

  Widget _buildDetails(
    BuildContext context,
    PromptItem item, {
    required bool isLoading,
    Object? error,
  }) {
    final files = item.marketFiles;
    final skillFiles = _skillFiles(item);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const _StatusChip(label: 'Market', selected: true),
                        if (item.isVerified) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.verified_user_outlined,
                            color: Colors.green.shade700,
                            size: 19,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                _InstallSkillMenu(
                  projects: store.projects,
                  onInstall: (target) => _installSkill(context, item, target),
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 18),
            _InlineNotice(
              icon: Icons.cloud_off_outlined,
              message: 'Could not load skill details: $error',
            ),
          ],
          const SizedBox(height: 28),
          const _Divider(),
          _SectionTitle(title: 'Package Info'),
          _InfoRow(label: 'Source', value: item.marketSource ?? item.source),
          _InfoRow(label: 'URL', value: _itemUrl(item)),
          if (item.installs != null)
            _InfoRow(label: 'Installs', value: _formatCount(item.installs!)),
          if (item.hash != null) _InfoRow(label: 'Hash', value: item.hash!),
          const SizedBox(height: 24),
          const _Divider(),
          _SectionTitle(title: 'Sub skills'),
          _SubSkillsCard(item: item, files: skillFiles),
          const SizedBox(height: 24),
          const _Divider(),
          _SectionTitle(title: 'Files'),
          _SkillFilesCard(files: files),
          const SizedBox(height: 24),
          const _Divider(),
          _SectionTitle(title: 'SKILL.md'),
          _PromptContentCard(content: _primaryContent(item)),
        ],
      ),
    );
  }

  Future<void> _installSkill(
    BuildContext context,
    PromptItem item,
    SkillInstallTarget target,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (target.type == SkillInstallTargetType.library) {
        final localSkill = onAddSkillToLibrary(item);
        messenger.showSnackBar(
          SnackBar(content: Text('Added ${localSkill.title}')),
        );
        return;
      }

      final result = await onInstallMarketSkill(skill: item, target: target);
      store.installSkill(
        item,
        target: target,
        packageId: result.packageId,
        installedPath: result.outputPath,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Installed ${result.packageId} to ${target.label}'),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  List<SkillFile> _skillFiles(PromptItem item) {
    final skillFiles = item.marketFiles
        .where((file) => file.isSkillMarkdown)
        .toList();
    if (skillFiles.isNotEmpty) {
      return skillFiles;
    }

    return [SkillFile(path: 'SKILL.md', contents: item.content)];
  }

  String _primaryContent(PromptItem item) {
    for (final file in item.marketFiles) {
      if (file.path.toLowerCase() == 'skill.md') {
        return file.contents;
      }
    }

    return item.content;
  }

  String _itemUrl(PromptItem item) {
    if (item.marketUrl != null && item.marketUrl!.trim().isNotEmpty) {
      return item.marketUrl!;
    }

    final source = item.marketSource;
    if (source != null && source.trim().isNotEmpty) {
      return 'https://skills.sh/$source';
    }

    return 'https://skills.sh/${item.marketId ?? item.id.replaceFirst('market-', '')}';
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return '$value';
  }
}

class _SubSkillsCard extends StatelessWidget {
  const _SubSkillsCard({required this.item, required this.files});

  final PromptItem item;
  final List<SkillFile> files;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < files.length; index++) ...[
            if (index > 0) const Divider(height: 18),
            _SubSkillRow(file: files[index], fallbackTitle: item.title),
          ],
        ],
      ),
    );
  }
}

class _SubSkillRow extends StatelessWidget {
  const _SubSkillRow({required this.file, required this.fallbackTitle});

  final SkillFile file;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.extension_outlined, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                file.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (_summary().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  _summary(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _title() {
    final path = file.path.replaceAll('\\', '/');
    if (path.toLowerCase() == 'skill.md') {
      return fallbackTitle;
    }

    final segments = path
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.length <= 1) {
      return fallbackTitle;
    }

    final directory = segments.take(segments.length - 1).join('/');
    return directory
        .split(RegExp(r'[-_/]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _summary() {
    return file.contents
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }
}

class _SkillFilesCard extends StatelessWidget {
  const _SkillFilesCard({required this.files});

  final List<SkillFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const _PanelCard(child: Text('No file snapshot returned.'));
    }

    return _PanelCard(
      child: Column(
        children: [
          for (var index = 0; index < files.length; index++) ...[
            if (index > 0) const Divider(height: 18),
            _SkillFileRow(file: files[index]),
          ],
        ],
      ),
    );
  }
}

class _SkillFileRow extends StatelessWidget {
  const _SkillFileRow({required this.file});

  final SkillFile file;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_icon(), size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            file.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatBytes(file.byteLength),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  IconData _icon() {
    return file.isSkillMarkdown
        ? Icons.extension_outlined
        : Icons.insert_drive_file_outlined;
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF6D4C00), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({required this.store, required this.item});

  final PromptStore store;
  final PromptItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<PromptScope>(
            segments: [
              ButtonSegment(
                value: PromptScope.global,
                icon: const Icon(Icons.public_outlined),
                label: Text(l10n.global),
              ),
              ButtonSegment(
                value: PromptScope.project,
                icon: const Icon(Icons.folder_copy_outlined),
                label: Text(l10n.project),
              ),
            ],
            selected: {item.scope},
            onSelectionChanged: (selection) {
              store.updateScope(item, selection.first);
            },
          ),
          const SizedBox(height: 14),
          for (final project in store.projects)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(project.name),
              subtitle: Text(
                project.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              value: item.isEnabledForProject(project.id),
              onChanged: item.scope == PromptScope.global
                  ? null
                  : (enabled) {
                      store.toggleProject(item, project.id, enabled ?? false);
                    },
            ),
        ],
      ),
    );
  }
}

class _AgentsCard extends StatelessWidget {
  const _AgentsCard({required this.store, required this.item});

  final PromptStore store;
  final PromptItem item;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        children: [
          for (final agent in AgentRuntime.values)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(_agentIcon(agent), size: 18),
              title: Text(agent.label),
              value: item.enabledAgents.contains(agent),
              onChanged: (enabled) {
                store.toggleAgent(item, agent, enabled);
              },
            ),
        ],
      ),
    );
  }

  IconData _agentIcon(AgentRuntime agent) {
    switch (agent) {
      case AgentRuntime.codex:
        return Icons.terminal_rounded;
      case AgentRuntime.gemini:
        return Icons.auto_awesome_rounded;
      case AgentRuntime.claude:
        return Icons.code_rounded;
    }
  }
}

class _PromptContentCard extends StatelessWidget {
  const _PromptContentCard({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: SelectableText(content, style: const TextStyle(height: 1.5)),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Divider(color: Colors.grey.shade200, height: 1),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.language, required this.onChanged});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppLanguage>(
      segments: const [
        ButtonSegment(value: AppLanguage.zh, label: Text('中文')),
        ButtonSegment(value: AppLanguage.en, label: Text('EN')),
      ],
      selected: {language},
      onSelectionChanged: (selection) {
        onChanged(selection.first);
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE3F6EA) : const Color(0xFFEDEFF2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF16843B) : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.4, color: Colors.grey.shade600),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
