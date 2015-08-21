# This module wraps all the logic behind our communication with the
# workers infrastructure. To make it easier to try different cloud
# resource providers, we implement the "Strategy" design pattern
# and delegate the infrastructure specific methods to the strategy
# object (called "@provider" to make more sense).

# TODO: Add the user id in the initializer. Every method we call
# should return results only for that user. E.g. list_clusters should
# return the clusters assigned to that specific user not all our
# clusters.
module Power 
  VALID_PROVIDERS = ["Amazon"]

  class Source < ActiveRecord::Base
    self.table_name = "power_sources"

    belongs_to :user

    extend Forwardable
    def_delegators :@provider, :list_clusters, :create_cluster

    def self.create_for_user_with_provider!(user, provider="Amazon")
      Power::VALID_PROVIDERS.include?(provider) || raise("Unknown provider")
      unless user.persisted?
        raise "Cannot create power source for not persisted User"
      end
      return false if self.where(user_id: user.id).exists?

      power_source = self.new(user_id: user.id, power_provider: provider)
      power_source.setup
      power_source.save!
    end

    def provider
      @provider ||= 
        case power_provider
        when "Amazon"
          Power::Providers::Amazon.new
        else
          raise "Unknown provider"
        end
    end

    def setup
      unless cluster_exists?
        self.cluster_name = provider.create_cluster(user.id.to_s)
      end
    end

    private

    def cluster_exists?
      cluster_name.present? &&
        provider.list_clusters.include?(cluster_name)
    end
  end
end
