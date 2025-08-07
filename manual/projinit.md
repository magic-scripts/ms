# Project Initializer (`projinit`)

Initialize new projects with common frameworks.

## Usage

```bash
# Initialize various project types
projinit node myapp
projinit react frontend
projinit python myservice
projinit express api
```

## Supported Project Types

- `node` - Node.js project with package.json
- `python` - Python project with requirements.txt
- `go` - Go project with go.mod
- `react` - React application with create-react-app
- `next` - Next.js application
- `express` - Express.js server
- `fastapi` - FastAPI Python server

## Options

- Project type (required) - The framework/runtime to initialize
- Project name (required) - Name of the project directory
- `-h, --help` - Show help message
- `-v, --version` - Show version

## Configuration

- `AUTHOR_NAME` - Your name for generated files
- `AUTHOR_EMAIL` - Your email for generated files
- `DEFAULT_NODE_VERSION` - Default Node.js version for new projects (default: 18)
- `DEFAULT_PYTHON_VERSION` - Default Python version for new projects (default: 3.11)
- `DEFAULT_LICENSE` - Default license type for new projects (default: mit)

## Features

- Creates project directory structure
- Generates appropriate configuration files
- Sets up development dependencies
- Includes README.md template
- Configures .gitignore automatically

## Examples

```bash
# Node.js project
projinit node my-api
# Creates: package.json, .gitignore, README.md, src/ directory

# React application
projinit react my-frontend
# Creates full React app with all dependencies

# Python service
projinit python my-service
# Creates: requirements.txt, main.py, .gitignore, README.md
```

## Installation

```bash
ms install projinit
```