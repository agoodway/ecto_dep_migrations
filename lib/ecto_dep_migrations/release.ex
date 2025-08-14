defmodule EctoDepMigrations.Release do
  @moduledoc """
  Release module for running migrations in production without Mix.
  
  This module provides functions to run database migrations from both your 
  application and its dependencies when deployed in production environments
  where Mix is not available.
  
  ## Usage
  
  In your application's release module:
  
      defmodule MyApp.Release do
        def migrate do
          EctoDepMigrations.Release.migrate(:my_app)
        end
        
        def rollback(version) do
          EctoDepMigrations.Release.rollback(:my_app, version)
        end
      end
  
  Or use this module directly in your release configuration.
  """
  
  @doc """
  Runs all pending migrations for the given application.
  
  This function will:
  1. Load the application
  2. Discover all migration paths (local + dependencies)
  3. Run all pending migrations
  
  ## Parameters
  
    * `app` - The OTP application name as an atom
    * `opts` - Optional keyword list of options:
      * `:repos` - List of repositories to migrate (defaults to all configured repos)
      * `:quiet` - Suppress output when true (defaults to false)
  
  ## Examples
  
      EctoDepMigrations.Release.migrate(:my_app)
      EctoDepMigrations.Release.migrate(:my_app, repos: [MyApp.Repo])
  """
  def migrate(app, opts \\ []) do
    load_app(app)
    
    repos = opts[:repos] || Application.fetch_env!(app, :ecto_repos)
    quiet = opts[:quiet] || false
    
    for repo <- repos do
      unless quiet do
        IO.puts("Running migrations for #{inspect(repo)}")
      end
      
      paths = get_migration_paths(app, repo)
      
      unless quiet do
        IO.puts("Migration paths: #{inspect(paths)}")
      end
      
      case Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, paths, :up, all: true)) do
        {:ok, _repo, migrations} ->
          unless quiet do
            if length(migrations) == 0 do
              IO.puts("#{inspect(repo)} is already up")
            else
              IO.puts("Migrated #{length(migrations)} migrations")
            end
          end
          
        {:error, error} ->
          raise "Could not run migrations: #{inspect(error)}"
      end
    end
  end
  
  @doc """
  Rolls back migrations to a specific version.
  
  ## Parameters
  
    * `app` - The OTP application name as an atom
    * `version` - The target version to rollback to
    * `opts` - Optional keyword list of options:
      * `:repo` - The specific repository to rollback (required if multiple repos)
      * `:quiet` - Suppress output when true (defaults to false)
  
  ## Examples
  
      EctoDepMigrations.Release.rollback(:my_app, 20210101120000)
      EctoDepMigrations.Release.rollback(:my_app, 20210101120000, repo: MyApp.Repo)
  """
  def rollback(app, version, opts \\ []) do
    load_app(app)
    
    repo = determine_repo(app, opts)
    quiet = opts[:quiet] || false
    
    unless quiet do
      IO.puts("Rolling back #{inspect(repo)} to version #{version}")
    end
    
    paths = get_migration_paths(app, repo)
    
    case Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, paths, :down, to: version)) do
      {:ok, _repo, migrations} ->
        unless quiet do
          if length(migrations) == 0 do
            IO.puts("No migrations to rollback")
          else
            IO.puts("Rolled back #{length(migrations)} migrations")
          end
        end
        
      {:error, error} ->
        raise "Could not rollback migrations: #{inspect(error)}"
    end
  end
  
  @doc """
  Lists all migrations and their status for the given application.
  
  ## Parameters
  
    * `app` - The OTP application name as an atom
    * `opts` - Optional keyword list of options:
      * `:repos` - List of repositories to check (defaults to all configured repos)
  
  ## Examples
  
      EctoDepMigrations.Release.migrations(:my_app)
      EctoDepMigrations.Release.migrations(:my_app, repos: [MyApp.Repo])
  """
  def migrations(app, opts \\ []) do
    load_app(app)
    
    repos = opts[:repos] || Application.fetch_env!(app, :ecto_repos)
    
    for repo <- repos do
      IO.puts("\nMigrations for #{inspect(repo)}:")
      IO.puts(String.duplicate("-", 50))
      
      paths = get_migration_paths(app, repo)
      
      {:ok, _repo, migrations} = 
        Ecto.Migrator.with_repo(repo, fn repo ->
          migrations = Ecto.Migrator.migrations(repo, paths)
          {:ok, repo, migrations}
        end)
      
      Enum.each(migrations, fn
        {:up, version, name} ->
          IO.puts("  UP   #{version} #{name}")
        {:down, version, name} ->
          IO.puts("  DOWN #{version} #{name}")
      end)
    end
  end
  
  # Private functions
  
  defp load_app(app) do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(app)
    
    # Start the app to ensure all dependencies are loaded
    {:ok, _} = Application.ensure_all_started(app)
  end
  
  defp determine_repo(app, opts) do
    case opts[:repo] do
      nil ->
        repos = Application.fetch_env!(app, :ecto_repos)
        case repos do
          [repo] -> repo
          _ -> raise "Multiple repos configured, please specify which one to rollback with repo: option"
        end
        
      repo ->
        repo
    end
  end
  
  defp get_migration_paths(app, repo) do
    # Get the application's migration path
    repo_config = Application.get_env(app, repo, [])
    otp_app = repo_config[:otp_app] || app
    
    # Standard migration path for the main application
    local_path = Path.join([
      :code.priv_dir(otp_app),
      "repo",
      "migrations"
    ])
    
    # Get dependency migration paths
    dep_paths = get_dep_migration_paths()
    
    # Combine and filter existing paths
    all_paths = [local_path | dep_paths]
    Enum.filter(all_paths, &File.dir?/1)
  end
  
  defp get_dep_migration_paths do
    # Get all loaded applications
    :application.loaded_applications()
    |> Enum.map(fn {app, _desc, _vsn} ->
      case :code.priv_dir(app) do
        {:error, _} -> nil
        priv_dir -> Path.join([priv_dir, "ecto_migrations"])
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&File.dir?/1)
  end
end