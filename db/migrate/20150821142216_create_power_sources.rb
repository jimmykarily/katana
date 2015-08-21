class CreatePowerSources < ActiveRecord::Migration
  def change
    create_table :power_sources do |t|
      t.integer :user_id, null: false
      t.string :power_provider, limit: 255 # TODO make this an enum
      t.string :cluster_name
    end
  end
end
