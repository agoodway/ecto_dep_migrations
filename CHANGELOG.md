# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-26

### Added

- Initial release of ecto_dep_migrations
- Mix task `mix ecto.migrate.all` for running migrations from app and dependencies
- Mix task `mix ecto.rollback.all` for rolling back migrations from app and dependencies
- Support for all standard Ecto migration options
- Automatic discovery of migrations in dependency `priv/ecto_migrations` directories
- Comprehensive documentation and examples
- Test suite with unit and integration tests

### Features

- Zero configuration required - works by convention
- Full compatibility with existing Ecto migration workflows
- Support for multiple repositories
- Detailed logging and quiet mode options
- Migration ordering across app and dependencies

[0.1.0]: https://github.com/yourorg/ecto_dep_migrations/releases/tag/v0.1.0