# Usage Rules for ecto_dep_migrations

## Purpose
`ecto_dep_migrations` enables Elixir dependencies to provide Ecto migrations that integrate seamlessly with Phoenix applications. It extends Ecto's standard migration functionality to automatically discover and run migrations from dependencies.

## Installation
Add to your dependencies in `mix.exs`:
```elixir
{:ecto_dep_migrations, github: "agoodway/ecto_dep_migrations", depth: 1}
```

## Core Concepts

### For Application Developers
- Replace standard Ecto migration aliases with extended versions in `mix.exs`
- Use `ecto.migrate.all` instead of `ecto.migrate`
- Use `ecto.rollback.all` instead of `ecto.rollback`
- All standard Ecto migration options are supported

### For Library Authors
- Place migrations in `priv/ecto_migrations/` directory
- Use timestamp-prefixed filenames: `YYYYMMDDHHMMSS_description.exs`
- Namespace migration modules with library name to avoid conflicts

## Key Rules

### DO
- ✅ Use unique timestamps for migration files to avoid conflicts
- ✅ Namespace migration modules (e.g., `MyLib.Migrations.CreateTable`)
- ✅ Place dependency migrations in `priv/ecto_migrations/`
- ✅ Use the Release module for production deployments without Mix
- ✅ Test migrations with `mix ecto.migrate.all --quiet`

### DON'T
- ❌ Place dependency migrations in `priv/repo/migrations/` (reserved for apps)
- ❌ Use duplicate timestamps across different dependencies
- ❌ Forget to compile dependencies before running migrations
- ❌ Use non-namespaced module names in library migrations

## Mix Tasks

### Running Migrations
```bash
# Run all migrations (app + dependencies)
mix ecto.migrate.all

# With options
mix ecto.migrate.all --step 3
mix ecto.migrate.all --to 20210615120000
mix ecto.migrate.all --repo MyApp.Repo
```

### Rolling Back
```bash
# Rollback last migration
mix ecto.rollback.all

# Rollback multiple
mix ecto.rollback.all --step 2
mix ecto.rollback.all --to 20210615120000
```

## Production Releases

### Basic Release Module
```elixir
defmodule MyApp.Release do
  def migrate do
    EctoDepMigrations.Release.migrate(:my_app)
  end
  
  def rollback(version) do
    EctoDepMigrations.Release.rollback(:my_app, version)
  end
end
```

### Deployment Commands
```bash
# Run migrations
./bin/my_app eval "MyApp.Release.migrate()"

# Check status
./bin/my_app eval "MyApp.Release.migrations(:my_app)"

# Rollback
./bin/my_app eval "MyApp.Release.rollback(20210101120000)"
```

## Migration Discovery

The package discovers migrations in this order:
1. Application migrations: `priv/repo/migrations/*.exs`
2. Dependency migrations (Mix): `_build/#{env}/lib/#{dep}/priv/ecto_migrations/*.exs`
3. Dependency migrations (Release): `priv/ecto_migrations/*.exs`

## Common Issues and Solutions

### Migration Not Found
- Ensure dependency is compiled: `mix deps.compile DEPENDENCY_NAME`
- Check migration location: `ls _build/*/lib/DEPENDENCY_NAME/priv/ecto_migrations/`
- Verify file naming: `YYYYMMDDHHMMSS_description.exs`

### Version Conflicts
- Use precise timestamps including seconds
- Coordinate with other library authors
- Consider using microsecond precision if needed

### Module Conflicts
- Always namespace migration modules
- Use format: `LibraryName.Migrations.MigrationName`

## Example Library Migration

```elixir
# In deps/my_auth/priv/ecto_migrations/20210701000000_create_auth_tables.exs
defmodule MyAuth.Migrations.CreateAuthTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
```

## Advanced Options

### Multiple Repositories
```elixir
# Migrate specific repos
EctoDepMigrations.Release.migrate(:my_app, 
  repos: [MyApp.Repo, MyApp.ReadOnlyRepo])

# Rollback specific repo
EctoDepMigrations.Release.rollback(:my_app, version, 
  repo: MyApp.Repo)
```

### Quiet Mode
```elixir
# Suppress output
EctoDepMigrations.Release.migrate(:my_app, quiet: true)
```

## Integration Patterns

### Docker
```dockerfile
CMD ["sh", "-c", "./bin/my_app eval 'MyApp.Release.migrate()' && ./bin/my_app start"]
```

### Kubernetes
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-database
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: my-app:latest
        command: ["./bin/my_app", "eval", "MyApp.Release.migrate()"]
```

## Important Notes
- This package is a Mix task extension and Release module, not a runtime dependency
- All migrations are tracked in Ecto's standard `schema_migrations` table
- Compatible with Elixir 1.15+ and Ecto SQL 3.10+
- Works with any Ecto-based application, not just Phoenix