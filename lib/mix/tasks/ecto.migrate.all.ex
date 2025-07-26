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

    # Ensure proper migration order by adjusting dependency timestamps if needed
    adjusted_temp_dir = ensure_proper_migration_order(repo, paths, opts)
    final_paths = if adjusted_temp_dir, do: paths ++ [adjusted_temp_dir], else: paths

    # Validate we have at least one path
    if Enum.empty?(final_paths) do
      Mix.shell().error("No migration paths found for #{inspect(repo)}")
      unless opts[:quiet] do
        Mix.shell().info("Expected locations:")
        Mix.shell().info("  - #{Path.join(source_repo_priv(repo), "migrations")}")
        Mix.shell().info("  - Dependencies: priv/ecto_migrations")
      end
    else
      unless opts[:quiet] do
        Mix.shell().info("Running migrations for #{inspect(repo)}")
        Mix.shell().info("Migration paths: #{inspect(final_paths)}")
      end

      # Run migrations
      result = case Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, final_paths, :up, opts)
      end) do
        {:ok, _repo, migrated} ->
          unless opts[:quiet] do
            if length(migrated) == 0 do
              Mix.shell().info("Repo #{inspect(repo)} is already up")
            else
              Mix.shell().info("Migrated #{length(migrated)} migrations")
            end
          end
          :ok

        {:error, error} ->
          Mix.raise("Could not run migrations: #{inspect(error)}")
      end
      
      # Clean up temporary directory if it was created
      cleanup_temp_migrations()
      
      result
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

  @doc """
  Ensures dependency migrations run after existing application migrations by
  adjusting their timestamps when necessary.
  
  This prevents dependency migrations with old timestamps from running before
  newer application migrations, which would break the logical migration order.
  """
  defp ensure_proper_migration_order(repo, all_paths, opts) do
    # Get local migration paths to identify app vs dependency migrations
    local_paths = 
      case opts[:migrations_path] do
        nil -> 
          [Path.join(source_repo_priv(repo), "migrations")]
        paths when is_list(paths) -> 
          paths
        path -> 
          [path]
      end
    
    # Collect all migration files with their sources
    {app_migrations, dep_migrations} = collect_migration_files(local_paths, all_paths)
    
    # Find the latest timestamp from existing application migrations
    latest_app_timestamp = get_latest_app_timestamp(app_migrations)
    
    # Check if any dependency migrations need timestamp adjustment
    if needs_timestamp_adjustment?(dep_migrations, latest_app_timestamp) do
      unless opts[:quiet] do
        Mix.shell().info("Adjusting dependency migration timestamps to maintain proper order...")
      end
      
      adjust_dep_migration_timestamps(repo, dep_migrations, latest_app_timestamp, opts)
    end
    
    all_paths
  end
  
  defp collect_migration_files(local_paths, all_paths) do
    # Get all migration files from local (app) paths
    app_migrations = 
      local_paths
      |> Enum.filter(&File.dir?/1)
      |> Enum.flat_map(fn path ->
        Path.wildcard(Path.join(path, "*.exs"))
        |> Enum.map(&{&1, extract_timestamp_from_filename(&1)})
      end)
      |> Enum.filter(fn {_path, timestamp} -> timestamp != nil end)
    
    # Get dependency paths (exclude local paths)
    dep_paths = all_paths -- local_paths
    
    # Get all migration files from dependency paths
    dep_migrations = 
      dep_paths
      |> Enum.flat_map(fn path ->
        Path.wildcard(Path.join(path, "*.exs"))
        |> Enum.map(&{&1, extract_timestamp_from_filename(&1)})
      end)
      |> Enum.filter(fn {_path, timestamp} -> timestamp != nil end)
    
    {app_migrations, dep_migrations}
  end
  
  defp extract_timestamp_from_filename(filename) do
    case Regex.run(~r/(\d{14})_/, Path.basename(filename)) do
      [_, timestamp_str] -> 
        case Integer.parse(timestamp_str) do
          {timestamp, ""} -> timestamp
          _ -> nil
        end
      _ -> nil
    end
  end
  
  defp get_latest_app_timestamp(app_migrations) do
    case app_migrations do
      [] -> 
        # No existing app migrations, use a base timestamp from 2020
        20200101000000
      migrations ->
        migrations
        |> Enum.map(fn {_path, timestamp} -> timestamp end)
        |> Enum.max()
    end
  end
  
  defp needs_timestamp_adjustment?(dep_migrations, latest_app_timestamp) do
    Enum.any?(dep_migrations, fn {_path, timestamp} ->
      timestamp <= latest_app_timestamp
    end)
  end
  
  defp adjust_dep_migration_timestamps(repo, dep_migrations, latest_app_timestamp, opts) do
    # Create a temporary directory for adjusted migrations
    temp_dir = Path.join(System.tmp_dir(), "ecto_dep_migrations_#{:erlang.phash2(make_ref())}")
    File.mkdir_p!(temp_dir)
    
    # Generate new timestamps starting after the latest app timestamp
    # Use current time but ensure it's after the latest app timestamp
    now = DateTime.utc_now()
    current_timestamp = now.year * 10000000000 + 
                       now.month * 100000000 + 
                       now.day * 1000000 + 
                       now.hour * 10000 + 
                       now.minute * 100 + 
                       now.second
    
    base_timestamp = max(latest_app_timestamp + 1, current_timestamp)
    
    adjusted_migrations = 
      dep_migrations
      |> Enum.filter(fn {_path, timestamp} -> timestamp <= latest_app_timestamp end)
      |> Enum.with_index()
      |> Enum.map(fn {{original_path, original_timestamp}, index} ->
        # Generate new timestamp with index offset to maintain relative order
        new_timestamp = base_timestamp + index
        new_filename = String.replace(
          Path.basename(original_path),
          ~r/^\d{14}/,
          Integer.to_string(new_timestamp)
        )
        new_path = Path.join(temp_dir, new_filename)
        
        # Copy the migration file with adjusted timestamp in the content
        adjust_migration_file(original_path, new_path, original_timestamp, new_timestamp)
        
        unless opts[:quiet] do
          Mix.shell().info("  #{Path.basename(original_path)} -> #{Path.basename(new_path)}")
        end
        
        {original_path, new_path, new_timestamp}
      end)
    
    # Update the migration discovery to use adjusted paths
    # This is handled by returning the temp directory path for inclusion
    if length(adjusted_migrations) > 0 do
      # Store temp directory for cleanup later
      Process.put(:ecto_dep_migrations_temp_dir, temp_dir)
      temp_dir
    else
      nil
    end
  end
  
  defp adjust_migration_file(source_path, dest_path, old_timestamp, new_timestamp) do
    content = File.read!(source_path)
    
    # Update the timestamp in the module name if it exists
    updated_content = 
      String.replace(content, Integer.to_string(old_timestamp), Integer.to_string(new_timestamp))
    
    File.write!(dest_path, updated_content)
  end
  
  defp cleanup_temp_migrations do
    case Process.get(:ecto_dep_migrations_temp_dir) do
      nil -> :ok
      temp_dir -> 
        File.rm_rf(temp_dir)
        Process.delete(:ecto_dep_migrations_temp_dir)
    end
  end

  # Test wrapper functions (only compiled in test environment)
  if Mix.env() == :test do
    def extract_timestamp_from_filename_test(filename), do: extract_timestamp_from_filename(filename)
    def get_latest_app_timestamp_test(migrations), do: get_latest_app_timestamp(migrations)
    def needs_timestamp_adjustment_test(dep_migrations, latest_timestamp), do: needs_timestamp_adjustment?(dep_migrations, latest_timestamp)
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