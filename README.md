# EctoDepMigrations

[![Hex Version](https://img.shields.io/hexpm/v/ecto_dep_migrations.svg)](https://hex.pm/packages/ecto_dep_migrations)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ecto_dep_migrations/)
[![License](https://img.shields.io/hexpm/l/ecto_dep_migrations.svg)](https://github.com/yourorg/ecto_dep_migrations/blob/main/LICENSE)

Enable Elixir dependencies to provide Ecto migrations that integrate seamlessly with Phoenix applications.

## Overview

`ecto_dep_migrations` solves a common problem in the Elixir ecosystem: libraries cannot easily distribute database migrations. This package provides Mix tasks that extend Ecto's standard migration functionality to automatically discover and run migrations from your dependencies.

### Key Features

- 🔍 **Automatic Discovery**: Finds migrations in dependencies without configuration
- 🔄 **Seamless Integration**: Drop-in replacement for standard Ecto migration tasks  
- 📦 **Zero Runtime Overhead**: Mix tasks only, no runtime dependencies
- 🔧 **Full Compatibility**: Supports all standard Ecto migration options
- 🏗️ **Convention-Based**: Uses `priv/ecto_migrations` for dependency migrations

## Installation

Add `ecto_dep_migrations` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_dep_migrations, "~> 0.1.0"}
  ]
end
```

## Usage

### For Phoenix Applications

Replace your standard Ecto migration aliases in `mix.exs`:

```elixir
defp aliases do
  [
    # Replace standard tasks with extended versions
    "ecto.migrate": "ecto.migrate.all",
    "ecto.rollback": "ecto.rollback.all",
    # Keep your other aliases
    "ecto.setup": ["ecto.create", "ecto.migrate.all", "run priv/repo/seeds.exs"],
    "ecto.reset": ["ecto.drop", "ecto.setup"],
    # ...
  ]
end
```

Now all your normal commands work with dependency migrations:

```bash
# Run all migrations (app + dependencies)
mix ecto.migrate

# Rollback one migration
mix ecto.rollback

# Rollback to a specific version
mix ecto.rollback --to 20210101120000

# Run migrations for a specific repo
mix ecto.migrate -r MyApp.OtherRepo
```

### For Library Authors

To provide migrations with your library:

1. Create the migrations directory in your library:
   ```bash
   mkdir -p priv/ecto_migrations
   ```

2. Generate migrations with timestamps:
   ```bash
   # Example: Creating a migration for your library
   touch priv/ecto_migrations/20210615120000_create_my_lib_tables.exs
   ```

3. Write your migration with a namespaced module:
   ```elixir
   defmodule MyLib.Migrations.CreateMyLibTables do
     use Ecto.Migration

     def change do
       create table(:my_lib_settings) do
         add :key, :string, null: false
         add :value, :text
         add :encrypted, :boolean, default: false
         
         timestamps()
       end

       create unique_index(:my_lib_settings, [:key])
     end
   end
   ```

4. That's it! Applications using your library will automatically run these migrations.

#### Best Practices for Library Migrations

- **Use Unique Timestamps**: Avoid conflicts by using precise timestamps
- **Namespace Modules**: Prefix with your library name (e.g., `MyLib.Migrations.CreateTable`)
- **Make Idempotent**: Use `if not exists` options where possible
- **Document Requirements**: Note any required configurations in your library docs
- **Version Carefully**: Consider migration compatibility across library versions

## Examples

### Example: Authentication Library

A library providing authentication might include migrations:

```elixir
# In deps/my_auth/priv/ecto_migrations/20210701000000_create_auth_tables.exs
defmodule MyAuth.Migrations.CreateAuthTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      
      timestamps()
    end

    create unique_index(:users, [:email])

    create table(:user_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      
      timestamps(updated_at: false)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])
  end
end
```

### Example: Multi-tenant Library

```elixir
# In deps/my_tenant/priv/ecto_migrations/20210801000000_create_tenant_tables.exs
defmodule MyTenant.Migrations.CreateTenantTables do
  use Ecto.Migration

  def change do
    create table(:tenants) do
      add :name, :string, null: false
      add :subdomain, :string, null: false
      add :active, :boolean, default: true
      
      timestamps()
    end

    create unique_index(:tenants, [:subdomain])

    # Add tenant_id to application tables
    alter table(:posts) do
      add :tenant_id, references(:tenants, on_delete: :delete_all)
    end

    create index(:posts, [:tenant_id])
  end
end
```

## Task Options

Both `mix ecto.migrate.all` and `mix ecto.rollback.all` support all standard Ecto options:

### Migration Options

- `--all` - Run all pending migrations (default for migrate)
- `--step N` / `-n N` - Run N migrations
- `--to VERSION` - Run all migrations up to and including VERSION
- `--to-exclusive VERSION` - Run all migrations up to but excluding VERSION
- `--quiet` - Do not log migration details
- `--prefix PREFIX` - The prefix to run migrations on
- `--log-level LEVEL` - The log level for migration logs
- `--log-migrations-sql` - Log SQL for migrations
- `--log-migrator-sql` - Log SQL for migrator operations
- `--repo REPO` / `-r REPO` - The repo to migrate

### Examples

```bash
# Run next 3 pending migrations
mix ecto.migrate.all --step 3

# Migrate up to specific version
mix ecto.migrate.all --to 20210615120000

# Rollback last 2 migrations
mix ecto.rollback.all --step 2

# Run on specific repo with SQL logging
mix ecto.migrate.all -r MyApp.Repo --log-migrations-sql

# Run quietly (only errors)
mix ecto.migrate.all --quiet
```

## How It Works

1. **Discovery Phase**: The tasks scan for migrations in:
   - Your application: `priv/repo/migrations/*.exs`
   - Each dependency: `_build/#{env}/lib/#{dep}/priv/ecto_migrations/*.exs`

2. **Timestamp Adjustment Phase**: If dependency migrations have timestamps older than existing application migrations, they are automatically adjusted:
   - Temporary migration files are created with current timestamps
   - This ensures dependencies run after existing application migrations
   - Original dependency files remain unchanged
   - The adjustment is logged unless `--quiet` is used

3. **Collection Phase**: All migration files are collected and sorted by timestamp

4. **Execution Phase**: Migrations are run through `Ecto.Migrator.run/4` with your options

5. **Cleanup Phase**: Temporary migration files are automatically removed

6. **Tracking**: Ecto's `schema_migrations` table tracks all migrations normally

### Migration Ordering

The package automatically handles migration ordering to prevent issues where dependency migrations with old timestamps would run before newer application migrations. When this situation is detected:

- **Problem**: Dependency provides `20220101000000_create_settings.exs` but your app has `20230201000000_create_users.exs`
- **Solution**: Dependency migration gets adjusted to run with a current timestamp (e.g., `20250726152000_create_settings.exs`)
- **Result**: Logical order is maintained - dependencies run after existing application migrations

This happens automatically and transparently. You'll see output like:
```
Adjusting dependency migration timestamps to maintain proper order...
  20220101000000_create_settings.exs -> 20250726152000_create_settings.exs
```

## Compatibility

- Elixir 1.15+
- Ecto SQL 3.10+
- Phoenix 1.7+ (or any Ecto-based application)

## Troubleshooting

### Migration Not Found

If dependency migrations aren't discovered:

1. Ensure the dependency is compiled: `mix deps.compile DEPENDENCY_NAME`
2. Check the migration exists: `ls _build/*/lib/DEPENDENCY_NAME/priv/ecto_migrations/`
3. Verify file naming: `YYYYMMDDHHMMSS_description.exs`

### Version Conflicts

If you get "migration already exists" errors:

1. Check for duplicate timestamps across dependencies
2. Use more precise timestamps (include seconds)
3. Coordinate with other library authors

### Module Conflicts

If you get module redefinition errors:

1. Ensure migration modules are uniquely named
2. Use library-specific prefixes: `MyLib.Migrations.CreateTable`

### Migration Ordering Issues

The package automatically handles most ordering issues, but if you encounter problems:

1. **Check migration timestamps**: Ensure your app migrations have reasonable timestamps
2. **Review adjustment messages**: Look for "Adjusting dependency migration timestamps" output
3. **Verify execution order**: Use `--log-migrations-sql` to see the actual execution order
4. **Manual override**: If needed, you can specify exact migration paths with `--migrations-path`

If timestamp adjustment is not working as expected:

1. Check that dependency migrations are in the correct location (`priv/ecto_migrations/`)
2. Verify migration file naming follows the pattern: `YYYYMMDDHHMMSS_description.exs`
3. Ensure your application has at least one existing migration for comparison

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.