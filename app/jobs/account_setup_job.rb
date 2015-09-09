class AccountSetupJob < ActiveJob::Base
  queue_as :default
 
  def perform(user)
    # Create power source

    # Create power provider for source
    # Setup power provider
  end
end
