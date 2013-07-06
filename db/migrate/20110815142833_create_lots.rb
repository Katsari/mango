include MigrationHelper

class CreateLots < ActiveRecord::Migration
  def self.up
    create_table :lots do |t|
      t.string :code
      t.date :date
      t.string :location
      t.references :ingredient
      t.timestamps
    end
    add_foreign_key 'lots', 'ingredient_id', 'ingredients'
  end

  def self.down
    drop_foreign_key 'lots', 'ingredient_id'
    drop_table :lots
  end
end
