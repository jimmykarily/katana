module Power
  module Providers
    # [TBD] Maybe all our application needs only one instance of this provider
    # This way we can memoize things for everybody and avoid multiple calls to
    # the Amazon API for the same data
    # This might not play well with threaded servers like Puma
    # ("global" variables don't play well with threads, but maybe it is not an
    # issue. Just saying).
    # In any case, a global memoization might lead to caching errors that can
    # only be fixed by restarting the application.
    class Amazon
      def initialize
        @client = Aws::ECS::Client.new
      end

      def list_clusters
        @list_clusters ||= @client.list_clusters.cluster_arns
      end

      def create_cluster(name)
        result = @client.create_cluster({cluster_name: name})

        result.cluster.cluster_arn
      end
    end
  end
end
