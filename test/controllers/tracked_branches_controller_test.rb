require 'test_helper'

class TrackedBranchesControllerTest < ActionController::TestCase
  let(:branch_name) { "master" }
  let(:project)  { FactoryGirl.create(:project) }
  let(:owner) { project.user }
  let(:branch_params) do
    { tracked_branch: { branch_name: branch_name } }.
      merge(project_id: project.id)
  end
  let(:filename_1) { "test/models/user_test.rb" }
  let(:filename_2) { "test/models/hello_test.rb" }
  let(:commit_sha) { "034df43" }
  let(:branch_github_response) do
    { name: branch_name, commit: { sha: commit_sha }, project_id: project.id }
  end

  describe "POST#create" do
    before do
      project
      @controller.stubs(:fetch_branch).returns(branch_github_response)
      @controller.stubs(:github_client).
        returns(Octokit::Client.new)
      TestRun.any_instance.stubs(:test_file_names).returns(
        [filename_1, filename_2 ])
      sign_in :user, owner
      post :create, branch_params
    end

    it "creates tracked branch" do
      TrackedBranch.last.branch_name.must_equal branch_name
    end

    it "creates TestJobs" do
      _test_run = TestRun.last

      _test_run.test_jobs.first.file_name.must_equal filename_1
      _test_run.test_jobs.last.file_name.must_equal filename_2
    end

    it "creates a TestRun with correct attributes" do
      _test_run = TestRun.last

      _test_run.commit_sha.must_equal commit_sha
      _test_run.status.must_equal TestStatus::PENDING
    end

    it "displays flash notice" do
      flash[:notice].wont_be :empty?
    end
  end
end
