module Power
  module Sources
    class Amazon < ActiveRecord::Base
      self.table_name = "amazon_power_providers"

      has_one :power_source, as: :power_provider, class_name: "Power::Source"

      before_destroy :cleanup
      before_validation :setup_defaults

      validate :cluster_exists_validator, on: :create
      validates :docker_image, presence: true

      delegate :user_id, to: :power_source

      def self.client
        @client ||= Aws::ECS::Client.new
      end

      def self.list_clusters
        @list_clusters ||= client.list_clusters.cluster_arns
      end

      def self.list_services(cluster)
        @list_services ||= client.list_services(cluster: cluster).service_arns
      end

      def self.describe_service(service_arn)
        client.describe_services(services: [service_arn])
      end

      def self.list_task_definitions
        @list_task_definitions ||= client.list_task_definitions.task_definition_arns
      end

      # TODO: Remove this method. We should not need to create clusters
      # programatically unless we reach some limit. It's too early to say.
      def self.create_cluster(name)
        result = client.create_cluster({cluster_name: name})

        result.cluster.cluster_arn
      end

      # TODO: Remove this method. It only exists to test the API. If we need
      # to remove clusters we can always do that from the webui
      def self.delete_cluster(name)
        result = client.delete_cluster({cluster: name})

        result.cluster.cluster_arn if result.present?
      end

      def cluster_exists?
        cluster_arn.present? &&
          self.class.list_clusters.include?(cluster_arn)
      end
      
      def task_definition_exists?
        task_arn.present? &&
          self.class.list_task_definitions.include?(task_arn)
      end

      def registered_task_definition
        return nil unless task_arn
        self.class.client.describe_task_definition(task_definition: task_arn).
          task_definition
      end

      # TODO: Move the task definition template to a setting
      def task_definition_json
        path = Rails.root.join('app/templates/amazon/task_definitions/default.json.erb')

        ERB.new(File.read(path)).result(binding)
      end

      # This method deregisters the user's task and registers again using the
      # task_definition_json. It should be run whenever we update the json
      # template.
      def update_task_definition
        deregister_task_definition if task_definition_exists?
        register_task_definition
      end

      # Returns the actual workers in the existing service.
      # This should be the same number as number_of_workers attribute.
      def current_number_of_workers
        return false unless service_exists?

        describe_service.what # TODO fix this
      end

      def service_exists?
        service_arn.present? &&
          self.class.list_services(cluster_arn).include?(service_arn)
      end

      def describe_service
        return nil unless service_exists?

        self.class.describe_service(service_arn)
      end

      def create_service
        return false if !task_arn || service_exists?

        # This one needs further investigation.
        # https://aws.amazon.com/blogs/aws/new-amazon-ec2-feature-idempotent-instance-creation/
        client_token = "ServiceCreation::#{user_id}"

        result = self.class.client.create_service({
          cluster: cluster_arn,
          service_name: user_id.to_s,
          task_definition: task_arn,
          desired_count: number_of_workers,
          client_token: client_token
        })

        self.update_column(:service_arn, result.service.service_arn)
      end

      def delete_service
        return false unless service_exists?

        if scale(0)
          self.class.client.delete_service(
            service: service_arn,
            cluster: cluster_arn
          )
          update_column(:service_arn, nil)
        else
          raise "could not scale service to zero"
        end
      end

      def scale(desired_count)
        return false unless service_exists?

        self.class.client.update_service({
          cluster: cluster_arn,
          service: service_arn,
          desired_count: desired_count,
          task_definition: task_arn
        })

        self.update_column(:number_of_workers, desired_count)
      end

      private

      def cluster_exists_validator
        errors.add(:base, "cluster does not exist") unless self.cluster_exists?
      end

      def deregister_task_definition
        self.class.client.deregister_task_definition(task_definition: task_arn)
        self.update_column(:task_arn, nil)
      end

      def register_task_definition
        task_definition = JSON.parse(task_definition_json).deep_symbolize_keys
        resp = self.class.client.register_task_definition(task_definition)
        self.update_column(:task_arn, resp.task_definition.task_definition_arn)
      end

      def cleanup
        # TODO: Perform all cleanup actions:
        # - Delete services
        # - Delete tasks
      end

      def setup_defaults
        self.cluster_arn = self.class.list_clusters.last if self.cluster_arn.nil?
        # This default probably makes no sense. Remove this when a UI is implemented
        # for user account setup.
        self.docker_image = 'testributor/default' if self.cluster_arn.nil?
      end
    end
  end
end
