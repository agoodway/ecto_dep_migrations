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
end