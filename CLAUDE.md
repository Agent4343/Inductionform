# CLAUDE.md - AI Assistant Guide for Inductionform

## Project Overview

**Inductionform** is a new project repository. This document serves as the primary reference for AI assistants working with this codebase.

> **Status**: This is a newly initialized repository. Update this document as the project structure develops.

---

## Repository Structure

```
Inductionform/
├── CLAUDE.md          # This file - AI assistant guide
└── .git/              # Git version control
```

*As the project grows, update this section with the actual directory structure.*

---

## Development Workflow

### Branch Strategy

- **Main branch**: Production-ready code
- **Feature branches**: Use `feature/<description>` naming convention
- **Bug fix branches**: Use `fix/<description>` naming convention
- **Claude branches**: AI-assisted work uses `claude/` prefix

### Commit Conventions

Follow conventional commit format:
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Pull Request Process

1. Create a feature branch from main
2. Make changes with clear, atomic commits
3. Ensure all tests pass
4. Create PR with descriptive title and body
5. Address review feedback
6. Squash and merge when approved

---

## Code Conventions

### General Principles

1. **Simplicity**: Keep solutions simple and focused on the task
2. **Readability**: Write clear, self-documenting code
3. **Consistency**: Follow existing patterns in the codebase
4. **Security**: Never commit secrets, API keys, or credentials

### File Organization

- Group related functionality together
- Use clear, descriptive file and folder names
- Keep files focused on a single responsibility

---

## Commands Reference

*Add commonly used commands as the project develops:*

```bash
# Example placeholders - update with actual commands
# npm install          # Install dependencies
# npm run dev          # Start development server
# npm run build        # Build for production
# npm run test         # Run tests
# npm run lint         # Run linter
```

---

## Testing

*Document testing approach when tests are added:*

- Unit tests: *TBD*
- Integration tests: *TBD*
- E2E tests: *TBD*

---

## Environment Setup

### Prerequisites

*List required tools and versions as they are established:*

- Node.js / Python / etc.: *TBD*
- Package manager: *TBD*

### Getting Started

```bash
# Clone the repository
git clone <repository-url>
cd Inductionform

# Install dependencies (when applicable)
# npm install

# Start development (when applicable)
# npm run dev
```

---

## Key Files

*Document important files as the project grows:*

| File | Purpose |
|------|---------|
| `CLAUDE.md` | AI assistant reference guide |
| *TBD* | *Add key files as created* |

---

## AI Assistant Guidelines

### When Working on This Repository

1. **Read First**: Always read relevant files before making changes
2. **Understand Context**: Check existing patterns and conventions
3. **Minimal Changes**: Make only the changes necessary for the task
4. **No Over-Engineering**: Avoid adding unnecessary complexity
5. **Security Aware**: Never expose secrets or add vulnerable code

### Things to Avoid

- Creating unnecessary files or documentation
- Adding features beyond what's requested
- Guessing at code you haven't read
- Making breaking changes without discussion
- Committing generated files that should be ignored

### Best Practices

- Use existing utilities and patterns when available
- Keep commits atomic and well-described
- Update this CLAUDE.md when significant changes are made
- Test changes before committing when tests exist

---

## Project-Specific Notes

*Add project-specific information, gotchas, and important context here as the project develops.*

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-04 | Initial CLAUDE.md created for empty repository |

---

*Last updated: 2026-02-04*
