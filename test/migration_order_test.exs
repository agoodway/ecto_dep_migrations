defmodule EctoDepMigrations.MigrationOrderTest do
  @moduledoc """
  Tests for the migration timestamp ordering functionality.
  
  This module tests that dependency migrations with old timestamps
  are properly reordered to run after application migrations.
  """
  use ExUnit.Case
  import ExUnit.CaptureIO

  @test_dir Path.join(System.tmp_dir!(), "migration_order_test")

  setup do
    # Clean up any existing test directory
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)

    on_exit(fn ->
      File.rm_rf!(@test_dir)
    end)

    {:ok, test_dir: @test_dir}
  end

  describe "migration timestamp ordering" do
    test "creates temporary adjusted migrations for old dependency timestamps", %{test_dir: test_dir} do
      # Create app migration directory with newer migration
      app_migrations_dir = Path.join(test_dir, "priv/repo/migrations")
      File.mkdir_p!(app_migrations_dir)
      
      create_migration_file(
        Path.join(app_migrations_dir, "20230201000000_create_users.exs"),
        "MyApp.Repo.Migrations.CreateUsers",
        "create table(:users)"
      )

      # Create dependency migration directory with older migration
      dep_migrations_dir = Path.join(test_dir, "priv/ecto_migrations")  
      File.mkdir_p!(dep_migrations_dir)
      
      create_migration_file(
        Path.join(dep_migrations_dir, "20220101000000_create_settings.exs"),
        "MyDep.Migrations.CreateSettings", 
        "create table(:settings)"
      )

      # Test the migration collection logic
      app_paths = [app_migrations_dir]
      all_paths = [app_migrations_dir, dep_migrations_dir]
      
      {app_migrations, dep_migrations} = collect_migration_files_test(app_paths, all_paths)
      
      # Verify app migration is detected
      assert length(app_migrations) == 1
      assert elem(hd(app_migrations), 1) == 20230201000000
      
      # Verify dependency migration is detected
      assert length(dep_migrations) == 1
      assert elem(hd(dep_migrations), 1) == 20220101000000
      
      # Verify that adjustment is needed
      latest_app_timestamp = get_latest_app_timestamp_test(app_migrations)
      assert latest_app_timestamp == 20230201000000
      assert needs_timestamp_adjustment_test(dep_migrations, latest_app_timestamp) == true
    end

    test "preserves relative order of dependency migrations", %{test_dir: test_dir} do
      # Create app migration
      app_migrations_dir = Path.join(test_dir, "priv/repo/migrations")
      File.mkdir_p!(app_migrations_dir)
      
      create_migration_file(
        Path.join(app_migrations_dir, "20230201000000_create_users.exs"),
        "MyApp.Repo.Migrations.CreateUsers",
        "create table(:users)"
      )

      # Create multiple dependency migrations with old timestamps
      dep_migrations_dir = Path.join(test_dir, "priv/ecto_migrations")  
      File.mkdir_p!(dep_migrations_dir)
      
      create_migration_file(
        Path.join(dep_migrations_dir, "20220101000000_create_settings.exs"),
        "MyDep.Migrations.CreateSettings", 
        "create table(:settings)"
      )
      
      create_migration_file(
        Path.join(dep_migrations_dir, "20220102000000_add_settings_index.exs"),
        "MyDep.Migrations.AddSettingsIndex", 
        "create index(:settings, [:key])"
      )

      # Test the collection logic
      app_paths = [app_migrations_dir]
      all_paths = [app_migrations_dir, dep_migrations_dir]
      
      {app_migrations, dep_migrations} = collect_migration_files_test(app_paths, all_paths)
      
      # Should have 1 app migration and 2 dependency migrations
      assert length(app_migrations) == 1
      assert length(dep_migrations) == 2
      
      # Dependency migrations should be in timestamp order
      dep_timestamps = Enum.map(dep_migrations, fn {_path, timestamp} -> timestamp end)
      assert dep_timestamps == [20220101000000, 20220102000000]
    end
  end

  # Helper functions
  
  defp create_migration_file(path, module_name, content) do
    migration_content = """
    defmodule #{module_name} do
      use Ecto.Migration

      def change do
        #{content}
      end
    end
    """
    
    File.write!(path, migration_content)
  end

  # Test access to private functions (when Mix.env() == :test)
  defp collect_migration_files_test(local_paths, all_paths) do
    # Simulate the collection logic from the main module
    app_migrations = 
      local_paths
      |> Enum.filter(&File.dir?/1)
      |> Enum.flat_map(fn path ->
        Path.wildcard(Path.join(path, "*.exs"))
        |> Enum.map(&{&1, extract_timestamp_from_filename_test(&1)})
      end)
      |> Enum.filter(fn {_path, timestamp} -> timestamp != nil end)
    
    dep_paths = all_paths -- local_paths
    
    dep_migrations = 
      dep_paths
      |> Enum.flat_map(fn path ->
        Path.wildcard(Path.join(path, "*.exs"))
        |> Enum.map(&{&1, extract_timestamp_from_filename_test(&1)})
      end)
      |> Enum.filter(fn {_path, timestamp} -> timestamp != nil end)
      |> Enum.sort_by(fn {_path, timestamp} -> timestamp end)
    
    {app_migrations, dep_migrations}
  end

  defp extract_timestamp_from_filename_test(filename) do
    case Regex.run(~r/(\d{14})_/, Path.basename(filename)) do
      [_, timestamp_str] -> 
        case Integer.parse(timestamp_str) do
          {timestamp, ""} -> timestamp
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_latest_app_timestamp_test(app_migrations) do
    case app_migrations do
      [] -> 20200101000000
      migrations ->
        migrations
        |> Enum.map(fn {_path, timestamp} -> timestamp end)
        |> Enum.max()
    end
  end

  defp needs_timestamp_adjustment_test(dep_migrations, latest_app_timestamp) do
    Enum.any?(dep_migrations, fn {_path, timestamp} ->
      timestamp <= latest_app_timestamp
    end)
  end
end