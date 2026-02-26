# Primary Decision Framework: Rails Doctrine vs Sandi Metz

*Use Rails Doctrine (Convention) when:*
- Simple CRUD operations (1-3 lines)
- Single model operations with basic validation
- Standard Rails patterns exist (callbacks, scopes, associations)
- Writing generalized code (keep things simple)

*Extract to Other Object Types (Sandi Metz) when:*
- Multi-model coordination (User + Order + EmailService)
- Complex business workflows (feedback creation + history tracking)
- Cross-cutting concerns (permissions + notifications + logging)
- Operations that don't belong to any single model or object
- Code becomes hard to test due to multiple dependencies

# Project Context: My Rails 8 Application

This document provides context for the Claude Code assistant. Keep this file concise and use references to specific files or directories for detailed information.

## Technology Stack
*   **Ruby Version:** 3.3.x
*   **Rails Version:** 8.0.x (using the new `bin/rails generate script` command)
*   **Database:** PostgreSQL
*   **Testing Library:** Rspec, VCR, and rswag

## Architecture & Design Patterns
*   We use a service object pattern for complex business logic.
*   We avoid placing excessive logic in controllers or models (fat model, skinny controller is **discouraged**).
*   We use Sandi Metz' rules for developers. Refer to [`./docs/SANDI_METZ_RULES.md`](./docs/SANDI_METZ_RULES.md) for details.

### Use Rails Doctrine (Convention) when:
* Simple CRUD operations (1-3 lines)
* Single model operations with basic validation
* Standard Rails patterns exist (callbacks, scopes, associations)
* Writing generalized code (keep things simple)

### Extract to Other Object Types (Sandi Metz) when:
* Multi-model coordination (User + Order + EmailService)
* Complex business workflows (feedback creation + history tracking)
* Cross-cutting concerns (permissions + notifications + logging)
* Operations that don't belong to any single model or object
* Code becomes hard to test due to multiple dependencies

## Development Workflow
* All new features **must** include tests (`TDD` is a must).
* Folow the code guideline. Refer to [`./docs/CODE_GUIDELINE.md`](./docs/CODE_GUIDELINE.md) for details.

## Key Instructions for Claude
*   Before starting any task, analyze the relevant files mentioned in this document.
*   If you need more context on a specific feature, first check the files in the `./docs/` directory.
*   Always propose a plan before implementing complex features.
*   Ensure all code adheres to the defined testing requirements.