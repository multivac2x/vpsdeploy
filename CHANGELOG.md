# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of vps-deploy toolkit

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

## [1.0.0] - 2025-02-19

### Added
- `setup-vps.sh`: Main script for provisioning VPS infrastructure
- `deploy.sh`: Build and deploy script for code deployment
- Support for both static and dynamic (Next.js) applications
- Central domain registry (`/etc/caddy/domains.json`) for multi-domain management
- Automatic SSL certificate provisioning via Caddy
- Dry-run and verbose modes for safe operations
- Comprehensive error handling and validation
- Phase-based architecture for setup-vps.sh
- Library modules: config.sh, logging.sh, ssh.sh

### Documentation
- Complete README with quick start guide
- Manual setup guide (docs/manual-setup-guide.md)
- Product requirements document (docs/PRD.md)
- 60+ test stories covering all functionality (docs/stories/)
- Epic overview and story management (docs/EPICS.md)
- Contributing guidelines (CONTRIBUTING.md)
- Security policy (SECURITY.md)

### Testing
- Unit tests for all scripts (shellcheck, bash -n)
- Integration test plans
- Error scenario tests
- Deployment scenario validation

[Unreleased]: https://github.com/pescatoreluca/vps-deploy/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/pescatoreluca/vps-deploy/releases/tag/v1.0.0
