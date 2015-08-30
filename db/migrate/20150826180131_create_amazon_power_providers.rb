class CreateAmazonPowerProviders < ActiveRecord::Migration
  def change
    create_table :amazon_power_providers do |t|
      t.string :cluster_arn
      t.string :task_arn
      t.string :service_arn
      t.string :docker_image, null: false
      t.integer :number_of_workers, null: false, default: 0
    end
  end
end
