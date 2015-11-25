class DashboardController < ApplicationController
  layout "dashboard"
  rescue_from Octokit::Unauthorized, with: :redirect_reconnect_to_github
  before_filter :authenticate_user!
  before_filter :check_for_active_providers, except: [:create]

  def index
    @projects = current_user.participating_projects.
      includes(tracked_branches: { test_runs: :test_jobs })
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, current_project)
  end

  protected

  def check_for_active_providers
    unless current_user.github_client
      redirect_to_reconnect_to_github_page and return
    end
  end

  def redirect_reconnect_to_github
    if request.xhr?
      render text: reconnect_message and return
    end

    redirect_to_reconnect_to_github_page and return
  end

  private

  def redirect_to_reconnect_to_github_page
    path = request.env['PATH_INFO']
    if path != root_path
      flash[:alert] = reconnect_message.html_safe
      redirect_to root_path
    end
  end

  def reconnect_message
    "Your Testributor account is not connected to GitHub. "\
    "Please #{view_context.link_to 'Connect to Github',
    view_context.github_oauth_authorize_url}.".
      html_safe
  end
end
