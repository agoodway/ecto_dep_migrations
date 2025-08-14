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
    {:ecto_dep_migrations, github: "agoodway/ecto_dep_migrations", depth: 1}
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

## Production Releases

When deploying to production where Mix is not available, use the `EctoDepMigrations.Release` module to run migrations:

### Basic Setup

Create a release module in your application:

```elixir
defmodule MyApp.Release do
  @app :my_app
  
  def migrate do
    EctoDepMigrations.Release.migrate(@app)
  end
  
  def rollback(version) do
    EctoDepMigrations.Release.rollback(@app, version)
  end
  
  def migrations_status do
    EctoDepMigrations.Release.migrations(@app)
  end
end
```

### Using with Elixir Releases

Configure your `rel/env.sh.eex` or runtime commands:

```bash
# Run migrations on deployment
./bin/my_app eval "MyApp.Release.migrate()"

# Check migration status
./bin/my_app eval "MyApp.Release.migrations_status()"

# Rollback to specific version if needed
./bin/my_app eval "MyApp.Release.rollback(20210101120000)"
```

### Using with Docker

In your Dockerfile or docker-entrypoint.sh:

```dockerfile
# Dockerfile
CMD ["sh", "-c", "./bin/my_app eval 'MyApp.Release.migrate()' && ./bin/my_app start"]
```

Or with a separate migration step:

```yaml
# docker-compose.yml
services:
  migrate:
    image: my_app:latest
    command: ./bin/my_app eval "MyApp.Release.migrate()"
    environment:
      DATABASE_URL: ${DATABASE_URL}
  
  app:
    image: my_app:latest
    depends_on:
      migrate:
        condition: service_completed_successfully
    command: ./bin/my_app start
```

### Advanced Options

The release module supports several options:

```elixir
# Migrate specific repositories
EctoDepMigrations.Release.migrate(:my_app, repos: [MyApp.Repo, MyApp.ReadOnlyRepo])

# Run migrations quietly (no output)
EctoDepMigrations.Release.migrate(:my_app, quiet: true)

# Rollback specific repo
EctoDepMigrations.Release.rollback(:my_app, 20210101120000, repo: MyApp.Repo)

# Check status for specific repos
EctoDepMigrations.Release.migrations(:my_app, repos: [MyApp.Repo])
```

### Kubernetes Jobs

For Kubernetes deployments, use a Job or initContainer:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-database
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: my-app:latest
        command: ["./bin/my_app", "eval", "MyApp.Release.migrate()"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
```

### Error Handling

The release module will raise exceptions on errors. Wrap calls for custom handling:

```elixir
defmodule MyApp.Release do
  require Logger
  
  def migrate do
    try do
      EctoDepMigrations.Release.migrate(:my_app)
      Logger.info("Migrations completed successfully")
      :ok
    rescue
      e ->
        Logger.error("Migration failed: #{inspect(e)}")
        {:error, e}
    end
  end
end
```

## How It Works

1. **Discovery Phase**: The tasks scan for migrations in:
   - Your application: `priv/repo/migrations/*.exs`
   - Each dependency: `_build/#{env}/lib/#{dep}/priv/ecto_migrations/*.exs` (Mix)
   - Each dependency: `priv/ecto_migrations/*.exs` (Release mode)

2. **Collection Phase**: All migration files are collected and sorted by timestamp

3. **Execution Phase**: Migrations are run through `Ecto.Migrator.run/4` with your options

4. **Tracking**: Ecto's `schema_migrations` table tracks all migrations normally

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
