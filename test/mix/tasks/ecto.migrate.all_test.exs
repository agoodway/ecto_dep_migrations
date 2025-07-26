defmodule Mix.Tasks.Ecto.Migrate.AllTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Mix.Tasks.Ecto.Migrate.All, as: MigrateAll

  setup do
    # Reset Mix state between tests
    on_exit(fn ->
      Mix.Shell.Process.flush()
      Mix.Task.clear()
    end)
  end

  describe "run/1" do
    test "warns when no repo is configured" do
      output = capture_io(:stderr, fn ->
        MigrateAll.run([])
      end)
      assert output =~ "could not find Ecto repos"
    end

    test "accepts repo option" do
      assert_raise Mix.Error, ~r/Could not load/, fn ->
        capture_io(fn ->
          MigrateAll.run(["-r", "NonExistent.Repo"])
        end)
      end
    end

    test "accepts step option" do
      output = capture_io(:stderr, fn ->
        MigrateAll.run(["--step", "3"])
      end)
      assert output =~ "could not find Ecto repos"
    end

    test "accepts to option" do
      output = capture_io(:stderr, fn ->
        MigrateAll.run(["--to", "20210101120000"])
      end)
      assert output =~ "could not find Ecto repos"
    end

    test "parses log level correctly" do
      output = capture_io(:stderr, fn ->
        MigrateAll.run(["--log-level", "debug"])
      end)
      assert output =~ "could not find Ecto repos"
    end

    test "raises on invalid log level" do
      assert_raise Mix.Error, ~r/Invalid log level/, fn ->
        capture_io(fn ->
          MigrateAll.run(["--log-level", "not_a_real_log_level_12345"])
        end)
      end
    end

    test "accepts quiet option" do
      output = capture_io(:stderr, fn ->
        MigrateAll.run(["--quiet"])
      end)
      assert output =~ "could not find Ecto repos"
    end
  end

  describe "timestamp adjustment" do
    test "extract_timestamp_from_filename extracts correct timestamp" do
      # Use the private function by calling it via the module
      # This requires making the function public for testing
      assert MigrateAll.extract_timestamp_from_filename_test("20230101120000_create_users.exs") == 20230101120000
      assert MigrateAll.extract_timestamp_from_filename_test("20220515093000_add_settings.exs") == 20220515093000
      assert MigrateAll.extract_timestamp_from_filename_test("invalid_name.exs") == nil
      assert MigrateAll.extract_timestamp_from_filename_test("") == nil
    end

    test "get_latest_app_timestamp handles empty migrations" do
      assert MigrateAll.get_latest_app_timestamp_test([]) == 20200101000000
    end

    test "get_latest_app_timestamp finds latest timestamp" do
      migrations = [
        {"/path/20230101000000_create_users.exs", 20230101000000},
        {"/path/20230201000000_add_fields.exs", 20230201000000},
        {"/path/20220101000000_create_settings.exs", 20220101000000}
      ]
      
      assert MigrateAll.get_latest_app_timestamp_test(migrations) == 20230201000000
    end

    test "needs_timestamp_adjustment detects problematic timestamps" do
      dep_migrations = [
        {"/dep/20220101000000_create_dep_table.exs", 20220101000000},
        {"/dep/20240101000000_update_dep_table.exs", 20240101000000}
      ]
      
      # Should need adjustment when dep timestamp is older than app timestamp
      assert MigrateAll.needs_timestamp_adjustment_test(dep_migrations, 20230101000000) == true
      
      # Should not need adjustment when all dep timestamps are newer
      assert MigrateAll.needs_timestamp_adjustment_test(dep_migrations, 20210101000000) == false
    end
  end
end