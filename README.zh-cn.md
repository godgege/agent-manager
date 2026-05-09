# Agent Manager

一个用于在不同项目间切换 AI Agent 工作流的提示词（Prompt）和技能（Skill）管理中心。

Agent Manager 是一款 Flutter 桌面应用，用于组织管理适用于编程 Agent（如 Codex、Claude 和 Gemini）的可复用提示词、规则和技能。它可以帮助您为每个项目选择合适的提示词，并将已启用的规则集写入到您的工具能够读取的 Agent 配置文件中。

## 技能源
https://skills.sh/docs
https://awesome-skills.com/

## 预览

> 在发布前请将此占位符替换为应用截图。

![Agent Manager 预览](docs/preview.png)

## 功能特性

- 在一个统一的桌面界面中管理可复用的规则和技能。
- 为不同项目或不同 Agent 开启或关闭特定的提示词。
- 将已启用的提示词写入到 `AGENTS.md`、`CLAUDE.md` 和 `GEMINI.md` 等文件中。
- 浏览并安装来自 `skills.sh` 的技能。
- 搜索本地提示词和应用市场中的技能。
- 支持中英文双语界面。

## 适用场景

- 保持各个项目特定的 Agent 指令一致性。
- 在不同的代码仓库之间共享提示词和技能预设。
- 快速切换 Agent 的行为模式，以适应编码、代码审查、文档编写或研究等不同任务。
- 探索并测试来自 skills.sh 市场的丰富技能。

## 快速开始

```bash
flutter pub get
flutter run -d windows
```

macOS 系统请运行：

```bash
flutter run -d macos
```

## 仓库标签 (Topics)

推荐的 GitHub 标签：

```text
prompt-hub
skill-hub
agent-hub
prompt-switch
skill-switch
ai-agents
agent-workflows
project-prompts
llm-tools
developer-tools
```

## 项目状态

Agent Manager 目前是一款处于早期开发阶段的桌面工具。当前的开发重点在于提示词和技能的组织管理、跨项目的规则切换以及与 skills.sh 的无缝集成。
