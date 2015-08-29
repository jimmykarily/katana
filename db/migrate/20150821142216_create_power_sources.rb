class CreatePowerSources < ActiveRecord::Migration
  def change
    create_table :power_sources do |t|
      t.integer :user_id, null: false
      t.integer :power_provider_id
      t.string :power_provider_type
    end
  end
end
