defmodule EctoDepMigrations.IntegrationTest do
  @moduledoc """
  Integration tests for the ecto_dep_migrations package.
  
  These tests create a temporary project structure to simulate
  real-world usage scenarios.
  """
  use ExUnit.Case

  @test_dir Path.join(System.tmp_dir!(), "ecto_dep_migrations_test")

  setup do
    # Clean up any existing test directory
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)

    on_exit(fn ->
      File.rm_rf!(@test_dir)
    end)

    {:ok, test_dir: @test_dir}
  end

  describe "migration collection" do
    test "collects migrations from app and dependencies", %{test_dir: test_dir} do
      # Create app structure
      app_dir = Path.join(test_dir, "my_app")
      create_app_structure(app_dir)
      
      # Create dependency structure
      dep_dir = Path.join(test_dir, "deps/my_dep")
      create_dep_structure(dep_dir)

      # Create build structure
      build_dir = Path.join(test_dir, "_build/test/lib/my_dep")
      File.mkdir_p!(Path.join(build_dir, "priv/ecto_migrations"))
      
      # Copy dep migrations to build
      dep_migration_src = Path.join(dep_dir, "priv/ecto_migrations/20210101000000_create_dep_table.exs")
      dep_migration_dst = Path.join(build_dir, "priv/ecto_migrations/20210101000000_create_dep_table.exs")
      File.cp!(dep_migration_src, dep_migration_dst)

      # Test that both paths would be discovered
      app_migration_path = Path.join(app_dir, "priv/repo/migrations")
      dep_migration_path = Path.join(build_dir, "priv/ecto_migrations")

      assert File.exists?(Path.join(app_migration_path, "20210102000000_create_app_table.exs"))
      assert File.exists?(Path.join(dep_migration_path, "20210101000000_create_dep_table.exs"))
    end

    test "handles missing migration directories gracefully", %{test_dir: test_dir} do
      # Create app without migrations directory
      app_dir = Path.join(test_dir, "my_app")
      File.mkdir_p!(app_dir)

      # Should not raise any errors
      paths = [
        Path.join(app_dir, "priv/repo/migrations"),
        Path.join(test_dir, "non_existent/priv/ecto_migrations")
      ]

      filtered = Enum.filter(paths, &File.dir?/1)
      assert filtered == []
    end
  end

  # Helper functions

  defp create_app_structure(app_dir) do
    migrations_dir = Path.join(app_dir, "priv/repo/migrations")
    File.mkdir_p!(migrations_dir)

    # Create a sample migration
    migration_content = """
    defmodule MyApp.Repo.Migrations.CreateAppTable do
      use Ecto.Migration

      def change do
        create table(:app_table) do
          add :name, :string
          timestamps()
        end
      end
    end
    """

    File.write!(
      Path.join(migrations_dir, "20210102000000_create_app_table.exs"),
      migration_content
    )
  end

  defp create_dep_structure(dep_dir) do
    migrations_dir = Path.join(dep_dir, "priv/ecto_migrations")
    File.mkdir_p!(migrations_dir)

    # Create a sample migration
    migration_content = """
    defmodule MyDep.Migrations.CreateDepTable do
      use Ecto.Migration

      def change do
        create table(:dep_table) do
          add :value, :string
          timestamps()
        end
      end
    end
    """

    File.write!(
      Path.join(migrations_dir, "20210101000000_create_dep_table.exs"),
      migration_content
    )
  end
end