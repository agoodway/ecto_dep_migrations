# Example Dependency Structure

This directory demonstrates how a dependency should structure its migrations to work with `ecto_dep_migrations`.

## Directory Structure

```
my_dependency/
├── lib/
│   └── ... (your library code)
├── priv/
│   └── ecto_migrations/       # ← Place migrations here
│       └── YYYYMMDDHHMMSS_migration_name.exs
└── mix.exs
```

## Key Points

1. **Directory**: Migrations must be in `priv/ecto_migrations/`
2. **Naming**: Use standard Ecto naming: `YYYYMMDDHHMMSS_description.exs`
3. **Modules**: Namespace your modules to avoid conflicts (e.g., `MyLib.Migrations.CreateTable`)
4. **No Dependencies**: Your library doesn't need to depend on `ecto_dep_migrations`

## Migration Example

See `priv/ecto_migrations/20250126120000_example_migration.exs` for a complete example showing:

- Table creation with comments
- Unique indexes
- Custom enum types (PostgreSQL)
- JSON/map columns
- Proper namespacing

## Usage

When an application uses your library AND has `ecto_dep_migrations` installed, your migrations will automatically be discovered and run with `mix ecto.migrate`.