require 'test_helper'

class RetryOrCancelTestRunFeatureTest < Capybara::Rails::TestCase
  let(:_test_job) { FactoryGirl.create(:testributor_job) }
  let(:_test_run) { _test_job.test_run }
  let(:branch) { _test_run.tracked_branch }
  let(:project) { _test_run.project }
  let(:owner) { project.user }

  before do
    GithubRepositoryManager.any_instance.stubs(:project_file_names).
      returns(['test/controllers/shitty_test.rb'])
    _test_job.test_run.project.
      project_files << FactoryGirl.create(:project_file,
                                          path: ProjectFile::JOBS_YML_PATH)
    yaml = <<-YAML
      each:
        pattern: ".*"
        command: "bin/rake test %{file}"
    YAML
    Octokit::Client.any_instance.
      stubs(:contents).with(project.repository_id,
                            path: ProjectFile::JOBS_YML_PATH,
                            ref: _test_run.commit_sha).
      returns(OpenStruct.new(content: Base64.encode64(yaml)))
    tree = OpenStruct.new(
      tree: [OpenStruct.new({path: 'test/models/stub_test_1.rb'}),
             OpenStruct.new({path: 'test_models/stub_test_2.rb'})])
    Octokit::Client.any_instance.stubs(:tree).returns(tree)
    login_as owner, scope: :user
  end

  it "user is be able to retry a successful test_run", js: true do
    _test_job.update_column(:status, TestStatus::PASSED)
    _test_job.reload
    _test_run.update_column(:status, TestStatus::PASSED)
    _test_run.reload
    visit project_test_runs_path(project, branch: branch.branch_name)
    page.must_have_content "Passed"
    page.wont_have_selector(".disabled.js-remote-submission")
    find(".btn-primary", text: "RETRY").click
    page.must_have_content "Setup"
  end

  it "user is able to retry a failed test_run", js: true do
    _test_job.update_column(:status, TestStatus::FAILED)
    _test_job.reload
    _test_run.update_column(:status, TestStatus::FAILED)
    _test_run.reload
    visit project_test_runs_path(project, branch: branch.branch_name)
    page.must_have_content "Failed"
    page.wont_have_selector(".disabled.js-remote-submission")
    find(".btn-primary").click
    page.must_have_content "Setup"
  end

  it "user is able to retry an error test_run", js: true do
    _test_job.update_column(:status, TestStatus::ERROR)
    _test_job.reload
    _test_run.update_column(:status, TestStatus::ERROR)
    _test_run.reload
    visit project_test_runs_path(project, branch: branch.branch_name)
    page.wont_have_selector(".disabled.js-remote-submission")
    page.must_have_content "Error"
    find(".btn-primary", text: "RETRY").click
    page.must_have_content "Setup"
  end

  it "user won't be able to retry a cancelled test_run", js: true do
    _test_run.update_column(:status, TestStatus::CANCELLED)
    _test_run.reload
    visit project_test_runs_path(project, branch: branch.branch_name)
    page.must_have_content "Cancelled"
    page.must_have_content "Cancelled"
    page.wont_have_selector ".btn-primary", text: "RETRY"
  end

  it "user is able to cancel a queued test_run", js: true do
    _test_job.update_column(:status, TestStatus::QUEUED)
    _test_job.reload
    _test_run.update_column(:status, TestStatus::QUEUED)
    _test_run.reload
    visit project_test_runs_path(project, branch: branch.branch_name)
    page.must_have_content "Queued"
    page.wont_have_selector(".disabled.js-remote-submission")
    within "#test-run-#{_test_run.id}" do
      find(".btn-danger").click
    end
    page.must_have_content "Cancelled"
  end

  it "user is able to cancel a running test_run", js: true do
    _test_job.update_column(:status, TestStatus::RUNNING)
    _test_job.reload
    _test_run.update_column(:status, TestStatus::RUNNING)
    _test_run.reload
    visit project_test_runs_path(project, branch: branch.branch_name)
    page.must_have_content "Running"
    page.wont_have_selector(".disabled.js-remote-submission")
    within "#test-run-#{_test_run.id}" do
      find(".btn-danger").click
    end
    page.must_have_content "Cancelled"
  end
end
