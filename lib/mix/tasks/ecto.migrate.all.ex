defmodule Mix.Tasks.Ecto.Migrate.All do
  @moduledoc """
  Runs migrations for repositories including migrations from dependencies.

  This task extends the functionality of `mix ecto.migrate` by also discovering
  and running migrations provided by dependencies in their `priv/ecto_migrations`
  directories.

  ## Examples

      $ mix ecto.migrate.all

      $ mix ecto.migrate.all -r MyApp.Repo

      $ mix ecto.migrate.all --step 3

      $ mix ecto.migrate.all --to 20210101120000

  The repositories to migrate are the ones specified under the
  `:ecto_repos` option in the current app configuration. However,
  if the `-r` option is given, it replaces the `:ecto_repos` config.

  This task runs all pending migrations by default. To migrate up to a
  specific version number, supply `--to version_number`. To migrate a
  specific number of times, use `--step n`.

  The `--log-level` option configures the log level for migration logs.
  Defaults to `:info`.

  The `--log-migrations-sql` option, when set to true, outputs every migration's
  SQL to the log. Defaults to `false`.

  The `--log-migrator-sql` option, when set to true, outputs every DDL operation
  performed by Ecto's migrator. Defaults to `false`.

  The `--strict-version-order` option, when set to true, will require that all
  migrations are in order of their version number. This helps to ensure that
  migrations are not accidentally skipped. Defaults to `false`.

  The `--quiet` option suppresses all output except errors.
  """

  use Mix.Task
  import Mix.Ecto
  import Mix.EctoSQL

  @shortdoc "Runs all repos migrations including dependency migrations"

  @aliases [
    n: :step,
    r: :repo
  ]

  @switches [
    all: :boolean,
    step: :integer,
    to: :integer,
    to_exclusive: :integer,
    quiet: :boolean,
    prefix: :string,
    pool_size: :integer,
    log_level: :string,
    log_migrations_sql: :boolean,
    log_migrator_sql: :boolean,
    strict_version_order: :boolean,
    repo: [:keep, :string],
    no_compile: :boolean,
    no_deps_check: :boolean,
    migrations_path: :keep
  ]

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    # Convert log level from string to atom first to catch errors early
    opts = parse_log_level(opts)

    # Ensure we have a migration strategy
    opts =
      if opts[:to] || opts[:to_exclusive] || opts[:step] do
        opts
      else
        Keyword.put(opts, :all, true)
      end

    repos = parse_repo(args)

    Enum.each(repos, fn repo ->
      ensure_repo(repo, args)
      migrate_repo(repo, opts)
    end)
  end

  defp migrate_repo(repo, opts) do
    # Get all migration paths (local + dependencies)
    paths = get_all_migration_paths(repo, opts)

    # Validate we have at least one path
    if Enum.empty?(paths) do
      Mix.shell().error("No migration paths found for #{inspect(repo)}")
      unless opts[:quiet] do
        Mix.shell().info("Expected locations:")
        Mix.shell().info("  - #{Path.join(source_repo_priv(repo), "migrations")}")
        Mix.shell().info("  - Dependencies: priv/ecto_migrations")
      end
    else
      unless opts[:quiet] do
        Mix.shell().info("Running migrations for #{inspect(repo)}")
        Mix.shell().info("Migration paths: #{inspect(paths)}")
      end

      # Run migrations
      case Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, paths, :up, opts)
      end) do
        {:ok, _repo, migrated} ->
          unless opts[:quiet] do
            if length(migrated) == 0 do
              Mix.shell().info("Repo #{inspect(repo)} is already up")
            else
              Mix.shell().info("Migrated #{length(migrated)} migrations")
            end
          end

        {:error, error} ->
          Mix.raise("Could not run migrations: #{inspect(error)}")
      end
    end
  end

  defp get_all_migration_paths(repo, opts) do
    # Get local migration paths
    local_paths = 
      case opts[:migrations_path] do
        nil -> 
          [Path.join(source_repo_priv(repo), "migrations")]
        paths when is_list(paths) -> 
          paths
        path -> 
          [path]
      end

    # Get dependency migration paths
    dep_paths = collect_dep_migration_paths()

    # Filter out non-existent paths and combine
    all_paths = local_paths ++ dep_paths
    Enum.filter(all_paths, &File.dir?/1)
  end

  defp collect_dep_migration_paths do
    # Load all dependencies
    deps = Mix.Dep.load_and_cache()

    # Map to migration paths
    deps
    |> Enum.map(fn dep ->
      # Use the build path where the dependency is compiled
      app_path = Path.join([Mix.Project.build_path(), "lib", to_string(dep.app)])
      Path.join(app_path, "priv/ecto_migrations")
    end)
    |> Enum.filter(&File.dir?/1)
  rescue
    e ->
      # If dependency loading fails, continue without dep migrations
      Mix.shell().error("Warning: Could not load dependencies: #{inspect(e)}")
      []
  end

  defp parse_log_level(opts) do
    case opts[:log_level] do
      nil -> opts
      level_str -> 
        level = String.to_existing_atom(level_str)
        Keyword.put(opts, :log_level, level)
    end
  rescue
    ArgumentError ->
      Mix.raise("Invalid log level: #{opts[:log_level]}")
  end
end