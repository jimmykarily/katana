module Power
  module Sources
    class Amazon < ActiveRecord::Base
      self.table_name = "amazon_power_providers"

      has_one :power_source, as: :power_provider, class_name: "Power::Source"

      before_destroy :cleanup
      before_validation :setup_defaults

      validate :cluster_exists_validator, :service_exists_validator, on: :create
      validates :docker_image, presence: true

      def self.client
        @client ||= Aws::ECS::Client.new
      end

      def self.list_clusters
        @list_clusters ||= client.list_clusters.cluster_arns
      end

      def self.list_services(cluster)
        @list_services ||= client.list_services(cluster: cluster).service_arns
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
      
      def service_exists?
        service_arn.present? &&
          self.class.list_services(cluster_arn).include?(service_arn)
      end

      def task_definition_exists?
        task_arn.present? &&
          self.class.list_task_definitions.include?(task_arn)
      end

      def registered_task_definition
        return nil unless task_arn
        self.class.client.describe_task_definition(task_definition: task_arn).
          tksk_definition
      end

      def scale(number_of_instances)
        # TODO: this methods should change the associated service so that
        # number_of_instances container instances are used
      end

      def number_of_workers
        # TODO: Return the number of tasks set in the associated service
      end

      # TODO: Move the task definition template to a setting
      def task_definition_json
        path = Rails.root.join('app/templates/amazon/task_definitions/default.json.erb')
        user_id = power_source.user_id

        ERB.new(File.read(path)).result(binding)
      end

      def update_task_definition
        deregister_task_definition if task_definition_exists?
        register_task_definition
      end

      private

      def cluster_exists_validator
        errors.add(:base, "cluster does not exist") unless self.cluster_exists?
      end

      def service_exists_validator
        errors.add(:base, "service does not exist") unless self.service_exists?
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
