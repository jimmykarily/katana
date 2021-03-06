FactoryGirl.define do
  factory :worker_group do
    association :oauth_application, factory: :doorkeeper_application
    sequence(:friendly_name) { |n| "Worker Group #{n}" }
    ssh_key_private <<-KEY
-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----
    KEY

    after(:build) do |worker_group, evaluator|
      if worker_group.project.blank?
        worker_group.project = evaluator.oauth_application.try(:owner)
      end
    end
  end
end
