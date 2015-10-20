class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :github
  skip_filter :set_redirect_url_in_cookie
  before_filter :verify_request_from_github!

  def github
    # We listen for 'push' and 'delete' events
    # https://developer.github.com/v3/repos/hooks/#webhook-headers
    if request.headers['HTTP_X_GITHUB_EVENT'] == 'delete' &&
      params[:ref_type] == 'branch'
      handle_delete
    elsif request.headers['HTTP_X_GITHUB_EVENT'] == 'push' &&
      params[:head_commit].present?
      handle_push
    end

    head :ok
  end

  private

  def handle_push
    repository_id = params[:repository][:id]
    projects = Project.where(repository_provider: 'github',
      repository_id: repository_id)
    projects.each do |project|
      branch_name = params[:ref].split('/').last
      if (tracked_branch = project.tracked_branches.find_by_branch_name(branch_name))
        # TODO : Duplicated in WebhooksController. DRY
        test_run = tracked_branch.
          test_runs.build(commit_sha: params[:head_commit][:id])
        test_run.build_test_jobs
        test_run.save!
      end
    end
  end

  def handle_delete
    repository_id = params[:repository][:id]
    branch_name = params[:ref]
    # TODO Do any pre-branch removal tasks
    projects = Project.where(repository_provider: 'github',
      repository_id: repository_id)
    projects.each do |project|
      if (tracked_branch = project.tracked_branches.find_by_branch_name(branch_name))
        tracked_branch.destroy!
      end
    end
  end

  def verify_request_from_github!(request_body=request.body.read)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha1'),
      ENV['GITHUB_WEBHOOK_SECRET'],
      request_body
    )
    unless Rack::Utils.secure_compare(signature, request.headers['HTTP_X_HUB_SIGNATURE'])
      head :unauthorized
    end
  end
end
