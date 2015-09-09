class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable
  has_many :test_jobs
  has_one :power_source, class_name: "Power::Source"

  after_create :setup_power_source

  private

  def setup_power_source
    # TODO: add a worker and a background job to setup the source
  end
end
