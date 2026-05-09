# Agent Manager

A prompt and skill hub for switching AI agent workflows across projects.

Agent Manager is a Flutter desktop app for organizing reusable prompts, rules,
and skills for coding agents such as Codex, Claude, and Gemini. It helps you
choose which prompts apply to each project and write the enabled set into the
agent files your tools already read.

## Skill Source
https://skills.sh/docs
https://awesome-skills.com/

## Preview

> Replace this placeholder with an app screenshot before publishing.

![Agent Manager preview](docs/preview.png)

## Features

- Manage reusable rules and skills in one desktop UI.
- Switch prompts on or off per project and per agent.
- Write enabled prompts to `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md`.
- Browse and install skills from `skills.sh`.
- Search local prompts and marketplace skills.
- Supports English and Chinese UI text.

## Use Cases

- Keep project-specific agent instructions consistent.
- Share prompt and skill presets across repositories.
- Quickly switch agent behavior for coding, review, docs, or research tasks.
- Experiment with skills from the skills.sh marketplace.

## Getting Started

```bash
flutter pub get
flutter run -d windows
```

For macOS:

```bash
flutter run -d macos
```

## Repository Topics

Suggested GitHub topics:

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

## Status

Agent Manager is an early desktop tool. The current focus is prompt and skill
organization, per-project switching, and skills.sh integration.
