# This module wraps all the logic behind our communication with the
# workers infrastructure. To make it easier to try different cloud
# resource providers, we implement the "Strategy" design pattern
# and delegate the infrastructure specific methods to the strategy
# object (called "@provider" to make more sense).
module Power 
  class Source < ActiveRecord::Base
    self.table_name = "power_sources"

    belongs_to :user
    belongs_to :power_provider, polymorphic: true

    delegate :scale, :number_of_workers, to: :power_provider

    def run_task
    end
  end
end
