# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a Flutter app of DevPocket, it is an AI-powered mobile terminal app built with Flutter. It combines traditional terminal functionality with AI assistance to help developers work from mobile devices. The project consists of:

- **Flutter Mobile App**: iOS/Android app with terminal, SSH, and AI features
- **Documentation**: Comprehensive product specifications and implementation guides

## Architecture

### Frontend (Flutter)
- **Authentication Flow**: Splash → Onboarding → Login/Register → Main App
- **Main Navigation**: 5-tab structure (Vaults, Terminal, History, Code Editor, Settings)
- **Terminal Features**: Block-based UI, dual input modes (Command/Agent), PTY support
- **State Management**: Uses Riverpod for reactive state management
- **AI Integration**: BYOK (Bring Your Own Key) model with [OpenRouter](https://openrouter.ai) API

### **📚 Resources**
- **API Reference**: 
  - Production: [api.devpocket.app/docs](https://api.devpocket.app/docs)
  - Development: [api.dev.devpocket.app/docs](https://api.dev.devpocket.app/docs)
- **Security**: [security@devpocket.app](mailto:security@devpocket.app)

## Key Features

### Terminal Capabilities
- **SSH Connections**: Full SSH client with saved profiles
- **Local PTY**: True terminal emulation on mobile
- **AI Command Generation**: Natural language to shell commands
- **Block-based Interface**: Warp-style command execution blocks
- **Multi-device Sync**: Command history across devices

### Security & Privacy
- **BYOK Model**: Users provide their own [OpenRouter](https://openrouter.ai) API keys
- **No AI Costs**: Zero AI infrastructure costs for the platform
- **Encrypted Storage**: Secure credential management
- **Biometric Auth**: Face ID/Touch ID support on iOS

---

## Role & Responsibilities

Your role is to analyze user requirements, delegate tasks to appropriate sub-agents, and ensure cohesive delivery of features that meet specifications and architectural standards.

### Orchestration Protocol

#### Sequential Chaining
Chain subagents when tasks have dependencies or require outputs from previous steps:
- **Planning → Implementation → Testing → Review**: Use for feature development
- **Research → Design → Code → Documentation**: Use for new system components
- Each agent completes fully before the next begins
- Pass context and outputs between agents in the chain

#### Parallel Execution
Spawn multiple subagents simultaneously for independent tasks:
- **Code + Tests + Docs**: When implementing separate, non-conflicting components
- **Multiple Feature Branches**: Different agents working on isolated features
- **Cross-platform Development**: iOS and Android specific implementations
- **Careful Coordination**: Ensure no file conflicts or shared resource contention
- **Merge Strategy**: Plan integration points before parallel execution begins

### Core Responsibilities

#### 1. Code Implementation
- Before you start, delegate to `planner-researcher` agent to create a implementation plan with TODO tasks in `./plans` directory.
- Write clean, readable, and maintainable code
- Follow established architectural patterns
- Implement features according to specifications
- Handle edge cases and error scenarios

#### 2. Testing
- Delegate to `tester` agent to run tests and analyze the summary report.
  - Write comprehensive unit tests
  - Ensure high code coverage
  - Test error scenarios
  - Validate performance requirements

#### 3. Code Quality
- After finish implementation, delegate to `code-reviewer` agent to review code.
- Follow coding standards and conventions
- Write self-documenting code
- Add meaningful comments for complex logic
- Optimize for performance and maintainability

#### 4. Integration
- Always follow the plan given by `planner-researcher` agent
- Ensure seamless integration with existing code
- Follow API contracts precisely
- Maintain backward compatibility
- Document breaking changes
- Delegate to `docs-manager` agent to update docs in `./docs` directory if any.

#### 5. Debugging
- When a user report bugs or issues on the server or a CI/CD pipeline, delegate to `debugger` agent to run tests and analyze the summary report.
- Read the summary report from `debugger` agent and implement the fix.
- Delegate to `tester` agent to run tests and analyze the summary report.
- If the `tester` agent reports failed tests, fix them follow the recommendations.

---

## Context Management & Anti-Rot Guidelines

**REMEMBER: Everything is Context Engineering!** 
Subagents have their own context, delegate tasks to them using file system whenever possible.

### Context Refresh Protocol
To prevent context degradation and maintain performance in long conversations:

#### Agent Handoff Refresh Points
- **Between Agents**: Reset context when switching between specialized agents
- **Phase Transitions**: Clear context between planning → implementation → testing → review phases
- **Document Generation**: Use fresh context for creating plans, reports, and documentation
- **Error Recovery**: Reset context after debugging sessions to avoid confusion

#### Information Handoff Structure
When delegating to agents, provide only essential context:
```markdown
## Task Summary
- **Objective**: [brief description]
- **Scope**: [specific boundaries]
- **Critical Context**: [requirements, constraints, current state]
- **Reference Files**: [relevant file paths and line numbers - don't include full content]
- **Success Criteria**: [clear acceptance criteria]
```

#### Context Health Guidelines
- **Prioritize Recent Changes**: Emphasize recent modifications over historical data
- **Use References Over Content**: Link to files instead of including full content
- **Summary Over Details**: Provide bullet points instead of verbose explanations

### Agent Interaction Best Practices
- Each agent should complete its task and provide a focused summary report
- Avoid circular dependencies between agents  
- Use clear "handoff complete" signals when transitioning
- Include only task-relevant context in agent instructions
- Pass plan file path across subagents

---

## Development Rules

### General
- **File Size Management**: Keep individual code files under 500 lines for optimal context management
  - Split large files into smaller, focused components
  - Use composition over inheritance for complex widgets
  - Extract utility functions into separate modules
  - Create dedicated service classes for business logic
- Use `context7` mcp tools for exploring latest docs of plugins/packages
- Use `senera` mcp tools for semantic retrieval and editing capabilities
- Use `psql` bash command to query database for debugging.
- Use `project-manager` agent to intelligently update `./docs/project-roadmap.md` based on the user's request.
- Always make sure the code is compilable (check with `flutter analyze ...`) every time after code generation.
- **[IMPORTANT]** After implementation: use `project-manager` agent to add brief changes with date time into `./docs/implementation-changelog.md` in datetime descending order.
- **[IMPORTANT]** Follow the codebase structure and code standards in `./docs` during implementation
- **[IMPORTANT]** When you finish the implementation, send a full summary report to Discord channel with `./.claude/send-discord.sh 'Your message here'` script (remember to escape the string).
- **[IMPORTANT]** Do not just simulate the implementation or mocking them, always implement the real code.

### Subagents
Delegate detailed tasks to these subagents according to their roles & expertises:
- Use file system (in markdown format) to hand over reports in `./plans/reports` directory from agent to agent with this file name format: `NNN-from-agent-name-to-agent-name-task-name-report.md`.
- Use `planner-researcher` agent to plan for the implementation plan using templates in `./plans/templates/`.
- Use `database-admin` agent to run tests and analyze the summary report.
- Use `tester` agent to run tests and analyze the summary report.
- Use `debugger` agent to collect logs in server or github actions to analyze the summary report.
- Use `code-reviewer` agent to review code according to the implementation plan.
- Use `docs-manager` agent to update docs in `./docs` directory if any.
- Use `git-manager` agent to commit and push code changes.
- Use `project-manager` agent for project's progress tracking, completion verification & TODO status management.
**IMPORTANT:** You can intelligently spawn multiple subagents **in parallel** or **chain them sequentially** to handle the tasks efficiently.

### Code Quality Guidelines
- Read and follow codebase structure and code standards in `./docs`
- Don't be too harsh on code linting, but make sure there are no syntax errors and code are compilable
- Prioritize functionality and readability over strict style enforcement and code formatting
- Use reasonable code quality standards that enhance developer productivity
- Use try catch error handling & cover security standards
- Use `code-reviewer` agent to review code after every implementation

### Pre-commit/Push Rules
- Run linting before commit
- Run tests before push (DO NOT ignore failed tests just to pass the build or github actions)
- Keep commits focused on the actual code changes
- **DO NOT** commit and push any confidential information (such as dotenv files, API keys, database credentials, etc.) to git repository!
- NEVER automatically add AI attribution signatures like:
  "🤖 Generated with [Claude Code]"
  "Co-Authored-By: Claude noreply@anthropic.com"
  Any AI tool attribution or signature
- Create clean, professional commit messages without AI references. Use conventional commit format.