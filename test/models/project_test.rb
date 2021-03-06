require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  let(:project) { FactoryGirl.build(:project) }
  let(:owner) { project.user }
  let(:new_owner) { FactoryGirl.create(:user) }

  describe "validations" do
    describe "#technologies" do
      subject { FactoryGirl.create(:project) }

      let(:postgres_9_3) do
        FactoryGirl.create(:docker_image,
                           standardized_name: "postgres", version: "9.3")
      end

      let(:postgres_9_4) do
        FactoryGirl.create(:docker_image,
                           standardized_name: "postgres", version: "9.4")
      end

      it "validates uniqueness of technology standardized names" do
        ->{ subject.technologies = [postgres_9_3, postgres_9_4] }.
          must_raise(ActiveRecord::RecordInvalid)
      end
    end

    describe "repository_url presence validation" do
      subject { Project.new }
      it "is invalid when repository_provider is bare_repo and repository_url is nil" do
        subject.repository_provider = "bare_repo"
        subject.wont_be :valid?
        subject.errors[:repository_url].must_equal ["can't be blank"]
      end

      it "has valid (nil) repository_url when repository_provider is not bare_repo" do
        subject.repository_provider = "github"
        subject.valid?
        subject.errors[:repository_url].must_equal []
      end
    end

    describe "#check_user_limit" do
      it "doesn't get called when user id hasn't changed" do
        owner.update_column(:projects_limit, 2)
        owner.reload
        project.save!
        project.expects(:check_user_limit).never
        project.save!
      end

      it "gets called when user id has changed" do
        owner.update_column(:projects_limit, 2)
        owner.reload
        project.user = new_owner
        project.expects(:check_user_limit).once
        project.save!
      end

      it "gets called when project is created" do
        project = Project.new(name: "Test", user: owner)
        project.expects(:check_user_limit).once
        project.save!
      end
    end

    describe "#projects_limit" do
      it "is valid if projects limit is greater than user's projects" do
        owner.update_column(:projects_limit, 2)
        owner.reload

        project.valid?.must_equal true
      end

      it "is valid if projects limit is equal to user's projects" do
        owner.update_column(:projects_limit, 1)
        owner.reload

        project.valid?.must_equal true
      end

      it "is invalid if projects limit is less than user's projects" do
        owner.update_column(:projects_limit, 0)
        owner.reload

        project.valid?.must_equal false
        project.errors.keys.must_include :base
      end
    end

    describe "#name" do
      subject { FactoryGirl.build(:project, repository_provider: 'github') }

      describe "when #repository_provider is different" do
        let(:another_project) do
          subject.user.update_column(:projects_limit, 2)
          FactoryGirl.create(:project,
            repository_provider: 'bitbucket', user: subject.user)
        end

        it "is valid when another project with same name exists" do
          subject.name = another_project.name
          subject.valid?.must_equal true
        end
      end

      describe "when #user is different" do
        let(:another_project) do
          FactoryGirl.create(:project, repository_provider: 'github')
        end

        it "is valid when another project with same name exists" do
          subject.name = another_project.name
          subject.valid?.must_equal true
        end
      end

      describe "when #repository_provider and #user are the same" do
        let(:another_project) do
          subject.user.update_column(:projects_limit, 2)
          FactoryGirl.create(:project,
            repository_provider: subject.repository_provider, user: subject.user)
        end

        it "is invalid when another project with same name exists" do
          subject.name = another_project.name
          subject.valid?.must_equal false
        end
      end
    end

    describe "#custom_docker_compose_yml" do
      it "is valid when the custom_docker_compose_yml contents are valid YAML" do
        project.custom_docker_compose_yml = "test: 4"
        project.must_be :valid?
      end

      it "is valid when the custom_docker_compose_yml contents are valid empty" do
        project.custom_docker_compose_yml = ""
        project.must_be :valid?
      end

      it "is invalid when the custom_docker_compose_yml contents are not valid YAML" do
        project.custom_docker_compose_yml = "test: 34, other_test: 234"
        project.wont_be :valid?
        project.errors[:custom_docker_compose_yml].must_equal ["syntax error"]
      end
    end
  end

  describe "custom_docker_compose_yml_as_hash" do
    it "returns the YAML as a Hash" do
      project.custom_docker_compose_yml = <<-YML
        first_key: 3
        second_key:
          third_key: 4
          other_key:
            other_key_deep_nested: 4
      YML

      project.custom_docker_compose_yml_as_hash.must_equal({
        "first_key" => 3,
        "second_key" => {
          "third_key" => 4,
          "other_key" => { "other_key_deep_nested" => 4 }
        }
      })
    end

    it "returns false when custom_docker_compose_yml is empty string" do
      project.custom_docker_compose_yml = ""

      project.custom_docker_compose_yml_as_hash.must_equal false
    end

    it "returns false when custom_docker_compose_yml is nil" do
      project.custom_docker_compose_yml = nil

      project.custom_docker_compose_yml_as_hash.must_equal false
    end

    it "raises error when the custom_docker_compose_yml is invalid YAML" do
      project.custom_docker_compose_yml = "this: 'is', invalid: 'yaml'"

      ->{ project.custom_docker_compose_yml_as_hash }.must_raise Psych::SyntaxError
    end
  end

  describe "invited_users association" do
    let(:invited_user) do
      FactoryGirl.create(:user_invitation, project: project).user
    end

    before { invited_user }

    it "returns users with invitations" do
      project.invited_users.must_equal [invited_user]
    end

    describe "after user accepting the invitation" do
      before do
        invited_user.user_invitations.first.accept!(invited_user)
      end

      it "still returns the invited user" do
        project.reload.invited_users.must_equal [invited_user]
      end
    end
  end

  describe 'creation of build_commands file' do
    it "creates a build commands file after creation" do
      user = FactoryGirl.create(:user)
      project = Project.create(name: "Test project", user: user)
      project.reload.project_files.pluck(:path).
        must_equal [ProjectFile::BUILD_COMMANDS_PATH]
    end
  end

  describe "to_param" do
    it "generates a simple/valid name for urls" do
      project = Project.new(name: "This.is|an|ugly.and^complex(name)@*&^*&^*for'a`project")
      project.to_param.must_equal "-this-is-an-ugly-and-complex-name-for-a-project"
    end
  end

  describe '#destroy_oauth_application!' do
    let(:project_1) do
      FactoryGirl.create(:doorkeeper_application).owner
    end
    let(:project_2) do
      FactoryGirl.create(:doorkeeper_application).owner
    end

    it 'must destroy an associated #oauth_application record' do
      oauth_application_1 = project_1.oauth_applications.take
      project_1.destroy_oauth_application!(oauth_application_1.id)

      oauth_application_2 = project_2.oauth_applications.take
      -> { project_1.destroy_oauth_application!(oauth_application_2.id) }.
        must_raise ActiveRecord::RecordNotFound
    end
  end
end
