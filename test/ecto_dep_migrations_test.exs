defmodule EctoDepMigrationsTest do
  use ExUnit.Case
  doctest EctoDepMigrations

  describe "dep_migrations_path/0" do
    test "returns the correct path" do
      assert EctoDepMigrations.dep_migrations_path() == "priv/ecto_migrations"
    end
  end

  describe "version/0" do
    test "returns a version string" do
      version = EctoDepMigrations.version()
      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+/
    end
  end
end
