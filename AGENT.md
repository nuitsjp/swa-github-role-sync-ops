# Project Context
This repository `swa-github-workflows` is a management repository for GitHub Actions related to SWA (Static Web Apps) role synchronization and discussion cleanup.
It manages submodules:
- `swa-github-role-sync`
- `swa-github-discussion-cleanup`

## Primary Directive

- Think in English, interact with the user in Japanese.
- Can execute GitHub CLI/Azure CLI. Will execute and verify them personally
  whenever possible.
- When modifying the implementation, strictly adhere to the t-wada style of
  Test-Driven Development (TDD). RED-GREEN-REFACTOR cycle must be followed
  without exception.

# Coding Guidelines
- Use TypeScript for actions.
- Follow GitHub Actions best practices.
- Documentation should be in Japanese (as per README).

# Architecture
- Centralized workflow management in this repository.
- Actions are implemented in submodules.
