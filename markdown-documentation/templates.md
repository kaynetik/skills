# Documentation Templates

## README Template

```markdown
# Project Name

Brief description of what this project does and who it is for.

[![Build](https://img.shields.io/github/actions/workflow/status/user/repo/ci.yml)](https://github.com/user/repo/actions)
[![License](https://img.shields.io/github/license/user/repo)](LICENSE)

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [License](#license)

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

### Prerequisites

- Node.js 18+
- npm or yarn

```bash
npm install package-name
```

### From Source

```bash
git clone https://github.com/user/repo.git
cd repo
npm install
npm run build
```

## Usage

```javascript
import { Package } from 'package-name';

const instance = new Package({
  option1: 'value1',
});

instance.doSomething();
```

## API Reference

### `Class.method(param1, param2)`

Description of what this method does.

**Parameters:**
- `param1` (string): Description
- `param2` (number): Description

**Returns:** Description of return value

## Configuration

Create a `.configrc` file:

```json
{
  "setting1": "value1",
  "setting2": true
}
```

## Testing

```bash
npm test
npm run test:coverage
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/thing`)
3. Commit changes (`git commit -m 'Add thing'`)
4. Push to branch (`git push origin feature/thing`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for full details.

## License

MIT -- see [LICENSE](LICENSE).
```

## CONTRIBUTING Template

```markdown
# Contributing

## Getting Started

1. Fork and clone the repository
2. Install dependencies: `npm install`
3. Create a branch: `git checkout -b feature/your-feature`

## Development

```bash
npm run dev       # Start dev server
npm test          # Run tests
npm run lint      # Lint code
```

## Pull Request Process

1. Update documentation for any changed behavior
2. Add tests for new functionality
3. Ensure all tests pass
4. Update CHANGELOG.md under "Unreleased"
5. Request review from a maintainer

## Commit Messages

Use conventional commits:

```
type(scope): short description

Optional longer description.

Refs: #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Code Style

- Follow existing patterns in the codebase
- Run the linter before committing
- Write tests for new code
```

## CHANGELOG Template

```markdown
# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security

## [1.0.0] - YYYY-MM-DD

### Added

- Initial release
- Feature description

[Unreleased]: https://github.com/user/repo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

## API Documentation Template

```markdown
# API Reference

## Authentication

All requests require an API key in the `Authorization` header:

```
Authorization: Bearer YOUR_API_KEY
```

## Endpoints

### GET /api/resource

Retrieve a list of resources.

**Query Parameters:**

| Parameter | Type   | Required | Description          |
|-----------|--------|----------|----------------------|
| limit     | number | No       | Max results (default 20) |
| offset    | number | No       | Pagination offset    |

**Response:**

```json
{
  "data": [...],
  "total": 100,
  "limit": 20,
  "offset": 0
}
```

**Status Codes:**

| Code | Description           |
|------|-----------------------|
| 200  | Success               |
| 401  | Unauthorized          |
| 500  | Internal server error |

### POST /api/resource

Create a new resource.

**Request Body:**

```json
{
  "name": "string (required)",
  "description": "string"
}
```

**Response:** `201 Created`

```json
{
  "id": "abc123",
  "name": "Example",
  "createdAt": "2025-01-01T00:00:00Z"
}
```
```

## Architecture Decision Record (ADR) Template

```markdown
# ADR-NNN: Title

## Status

Proposed | Accepted | Deprecated | Superseded by [ADR-NNN](NNN-title.md)

## Context

What is the issue that we are seeing that is motivating this decision or change?

## Decision

What is the change that we are proposing and/or doing?

## Consequences

What becomes easier or more difficult to do because of this change?
```
