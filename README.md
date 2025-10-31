# Development Container Utilities

A modular development container template builder system that simplifies creating and managing development environments with Docker and VS Code Dev Containers.

## 🚀 Overview

This project provides a flexible, component-based approach to building development container configurations. Instead of maintaining multiple complete devcontainer setups, you can compose environments from reusable components and templates.

## ✨ Key Features

- **🧩 Modular Components**: Mix and match components (Node.js, MongoDB, Chrome tools, etc.)
- **📋 Template System**: Pre-configured templates for common development stacks
- **🔄 File Sync Integration**: Built-in Mutagen sync for fast file synchronization
- **🐳 Docker Management**: Automated container lifecycle management
- **⚙️ Bash Utilities**: Enhanced command-line experience with custom aliases
- **🔧 VS Code Integration**: Automatic extension installation and workspace configuration

## 📁 Project Structure

```
development-container-utilities/
├── src/
│   ├── components/          # Reusable container components
│   │   ├── common/         # Base configuration (Docker, Git, VS Code)
│   │   ├── node/           # Node.js development setup
│   │   ├── mongodb/        # MongoDB database component
│   │   └── chrome_and_tools/ # Browser and testing tools
│   └── templates/          # Pre-built template combinations
│       ├── node_and_mongo.json
│       └── nodejs_mongodb_mongoexpress.json
├── template_builder_helpers.sh  # Core template building logic
├── dctm                    # Interactive template manager
├── cleanupcontainers.sh    # Docker cleanup utilities
└── .github/                # Issue templates and workflows
```

## 🛠️ Components

### Common Component
Base development environment with:
- Docker-in-Docker support
- Git configuration and GitHub CLI
- VS Code extensions (Docker, GitHub Copilot, etc.)
- Mutagen file synchronization
- Custom bash aliases and utilities

### Node.js Component
JavaScript/TypeScript development with:
- Node.js runtime and npm/yarn support
- ESLint, Prettier, and TypeScript extensions
- Development tools (Babel REPL, npm intellisense)
- Package management utilities

### MongoDB Component
Database development with:
- MongoDB server container
- MongoDB shell (mongosh) installation
- VS Code MongoDB extension
- Pre-configured connection strings
- Database management aliases

### Chrome and Tools Component
Browser testing and automation with:
- Chromium browser and WebDriver
- Testing framework support
- Browser automation tools

## 🚀 Quick Start

### 1. Build a Template

```bash
# Build a Node.js + MongoDB development environment
./template_builder_helpers.sh build node_and_mongo.json

# This creates a .devcontainer/ directory with the combined configuration
```

### 2. Start Development Environment

```bash
# Open in VS Code Dev Containers
code .

# Or use Dev Container CLI
devcontainer up
```

### 3. Interactive Template Manager

```bash
# Launch the interactive template selection interface
./dctm
```

## 📋 Available Templates

### Node.js with MongoDB
**File**: `node_and_mongo.json`
- Node.js development environment
- MongoDB database server
- Chrome browser and testing tools
- Full-stack JavaScript development

### Node.js with MongoDB and Mongo Express
**File**: `nodejs_mongodb_mongoexpress.json`
- Everything from Node.js + MongoDB template
- Mongo Express web interface
- Database administration tools

## 🔧 Template Builder

The `template_builder_helpers.sh` script provides the core functionality:

```bash
# Build a template
./template_builder_helpers.sh build <template-name.json>

# Convert between JSON and YAML
./template_builder_helpers.sh jsontoyaml input.json output.yaml
./template_builder_helpers.sh yamltojson input.yaml output.json
```

### Template Structure

Templates are JSON files that define component combinations:

```json
{
    "name": "Development Stack",
    "description": "Multi-container development environment",
    "components": [
        {
            "component": "common",
            "build-order": 1
        },
        {
            "component": "node",
            "build-order": 2
        },
        {
            "component": "mongodb",
            "build-order": 3
        }
    ]
}
```

## 🧹 Container Management

### Cleanup Containers

```bash
# Clean up all containers for current project
./cleanupcontainers.sh

# The script automatically detects project name and cleans up:
# - Containers
# - Images
# - Networks
# - Volumes
```

### Mutagen File Sync

Built-in file synchronization for performance:

```bash
# Start sync (automatically handled by devcontainer)
.devcontainer/mutagen_start.sh

# Stop sync
.devcontainer/mutagen_stop.sh
```

## 🎯 Use Cases

### Full-Stack Web Development
- Node.js backend with Express/Fastify
- MongoDB database
- React/Vue/Angular frontend
- Browser testing capabilities

### API Development
- Node.js runtime
- Database connectivity
- API testing tools
- Documentation generation

### Database Development
- MongoDB server
- Database administration tools
- Data modeling and migration scripts
- Performance monitoring

## 🔧 Customization

### Creating Custom Components

1. Create a new directory in `src/components/`
2. Add component files:
   - `devcontainer.json` - VS Code configuration
   - `docker-compose.yaml` - Container services
   - `container-post-create.sh` - Setup scripts
   - `.bash_aliases` - Custom aliases

### Creating Custom Templates

1. Create a JSON template file in `src/templates/`
2. Reference your components with build order
3. Build and test the template

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your components or templates
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🆘 Support

- 🐛 [Report Issues](https://github.com/tonydail/development-container-utilities/issues)
- 💡 [Request Features](https://github.com/tonydail/development-container-utilities/issues/new?template=2-enhancement_issue.md)
- 📖 [Documentation](https://github.com/tonydail/development-container-utilities/wiki)

---

**Made with ❤️ for developers who love containerized development environments**