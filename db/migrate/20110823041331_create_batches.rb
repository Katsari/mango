include MigrationHelper

class CreateBatches < ActiveRecord::Migration
  def self.up
    create_table :batches do |t|
      t.references :order
      t.references :schedule
      t.references :user
      t.integer :number
      t.timestamp :start_date
      t.timestamp :end_date
      t.timestamps
    end
    add_foreign_key 'batches', 'order_id', 'orders'
    add_foreign_key 'batches', 'schedule_id', 'schedules'
    add_foreign_key 'batches', 'user_id', 'users'
  end

  def self.down
    drop_foreign_key 'batches', 'order_id'
    drop_foreign_key 'batches', 'schedule_id'
    drop_foreign_key 'batches', 'user_id'
    drop_table :batches
  end
end
