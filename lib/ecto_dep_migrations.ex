defmodule EctoDepMigrations do
  @moduledoc """
  Enables Elixir dependencies to provide Ecto migrations that integrate seamlessly
  with Phoenix applications.

  ## Overview

  This package allows library authors to distribute database migrations alongside
  their packages. These migrations are automatically discovered and run when using
  the provided Mix tasks.

  ## For Library Authors

  To provide migrations with your library:

  1. Place migration files in `priv/ecto_migrations/` in your library
  2. Follow standard Ecto migration naming: `YYYYMMDDHHMMSS_description.exs`
  3. Namespace your migration modules to avoid conflicts (e.g., `MyLib.Migrations.CreateTable`)

  ## For Application Developers

  To use this package in your Phoenix application:

  1. Add to your dependencies:

      ```elixir
      defp deps do
        [
          {:ecto_dep_migrations, "~> 0.1.0"}
        ]
      end
      ```

  2. Replace the standard migration aliases in `mix.exs`:

      ```elixir
      defp aliases do
        [
          "ecto.migrate": "ecto.migrate.all",
          "ecto.rollback": "ecto.rollback.all",
          # ... other aliases
        ]
      end
      ```

  Now when you run `mix ecto.migrate`, it will include migrations from all
  dependencies that provide them.

  ## How It Works

  The package scans for migrations in two locations:

  1. Your application's standard migration path: `priv/repo/migrations/`
  2. Each dependency's migration path: `priv/ecto_migrations/`

  All migrations are collected, sorted by timestamp, and run in order.
  Ecto's standard version tracking ensures each migration runs only once.
  """

  @doc """
  Returns the migration directory path for dependencies.

  This is the conventional path where dependencies should place their migrations.
  """
  def dep_migrations_path do
    "priv/ecto_migrations"
  end

  @doc """
  Returns the version number of this package.
  """
  def version do
    {:ok, vsn} = :application.get_key(:ecto_dep_migrations, :vsn)
    List.to_string(vsn)
  end
end
