# Contributing to Magic Scripts

Thank you for your interest in contributing to Magic Scripts! This document provides guidelines and information for contributors.

## Development Process

1. **Fork and Setup**
   ```bash
   git clone https://github.com/your-username/ms.git
   cd ms
   git checkout develop  # Start from develop branch
   ```

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

3. **Develop Your Changes**
   - Add scripts to `scripts/` directory with proper version info
   - Update documentation as needed
   - Follow existing code patterns and conventions

4. **Test Your Changes**
   ```bash
   # Test script functionality
   ./scripts/your-script.sh --version

   # Calculate and verify checksum
   ms pub pack checksum scripts/your-script.sh

   # Verify registry files
   ms pub pack verify registry/

   # Test with Magic Scripts (if applicable)
   ms install yourcommand
   yourcommand --version
   ```

5. **Update Registry (if adding new commands)**
   ```bash
   # Add entry to ms.msreg with correct checksum
   # Use develop branch URL for dev testing
   ```

6. **Submit Changes**
   ```bash
   git add .
   git commit -m 'feat: add amazing feature'
   git push origin feature/amazing-feature
   ```

7. **Create Pull Request**
   - Target: `develop` branch
   - Include clear description of changes
   - Reference any related issues

## Branch Guidelines

- **Feature branches**: `feature/feature-name` (from `develop`)
- **Bug fixes**: `fix/bug-description` (from `develop` or `main`)
- **Hotfixes**: `hotfix/critical-fix` (from `main`)
- **Release**: `release/v0.0.0` (from `develop`)

## Commit Message Format

```
type(scope): description

feat(installer): add version parameter support
fix(registry): resolve duplicate entry handling  
docs(readme): update branch strategy documentation
```

## Testing Requirements

- All scripts must include `--version` and `--help` options
- Checksum calculations must be accurate
- Registry format must be valid
- No breaking changes without major version bump
- Document any new configuration keys

## Release Process (Maintainers)

1. **Prepare Release**
   ```bash
   git checkout develop
   git checkout -b release/v0.0.2
   # Update versions, documentation, changelog
   ```

2. **Merge to Main**
   ```bash
   git checkout main
   git merge release/v0.0.2
   git tag v0.0.2
   ```

3. **Create Snapshot**
   ```bash
   git checkout -b release/v0.0.2
   git push origin release/v0.0.2
   ```

4. **Update Registry**
   ```bash
   # Update ms.msreg with new version entries
   # Point to release/v0.0.2 branch for immutable references
   ```

## Questions?

Feel free to open an issue or start a discussion if you have questions about contributing!