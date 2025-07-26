defmodule ExampleDep.Migrations.CreateSettingsUpdated do
  @moduledoc """
  Example migration showing how old dependency migrations get timestamp adjusted.
  
  Original timestamp: 20220101000000
  This would be adjusted to run after existing app migrations.
  """
  use Ecto.Migration

  def change do
    create table(:example_settings_updated, comment: "Updated settings table for ExampleDep") do
      add :key, :string, null: false, comment: "Configuration key"
      add :value, :text, comment: "Configuration value"
      add :type, :string, default: "string", comment: "Value type"
      add :description, :text, comment: "Setting description"
      add :updated_at_field, :naive_datetime, comment: "Additional timestamp field"
      
      timestamps()
    end

    create unique_index(:example_settings_updated, [:key])
  end
end