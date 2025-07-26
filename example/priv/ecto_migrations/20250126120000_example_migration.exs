defmodule ExampleDep.Migrations.CreateExampleTable do
  @moduledoc """
  Example migration showing how dependencies should structure their migrations.
  
  This migration would be automatically discovered and run by applications
  using the ecto_dep_migrations package.
  """
  use Ecto.Migration

  def change do
    create table(:example_settings, comment: "Settings table for ExampleDep") do
      add :key, :string, null: false, comment: "Configuration key"
      add :value, :text, comment: "Configuration value"
      add :type, :string, default: "string", comment: "Value type"
      add :description, :text, comment: "Setting description"
      
      timestamps()
    end

    create unique_index(:example_settings, [:key])
    
    # Example of creating an enum type (PostgreSQL specific)
    execute(
      "CREATE TYPE example_status AS ENUM ('active', 'inactive', 'pending')",
      "DROP TYPE example_status"
    )
    
    create table(:example_entities, comment: "Main entities for ExampleDep") do
      add :name, :string, null: false
      add :status, :example_status, default: "pending"
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create index(:example_entities, [:status])
    create index(:example_entities, [:inserted_at])
  end
end