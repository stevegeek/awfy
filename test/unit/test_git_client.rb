# frozen_string_literal: true

require "test_helper"
require "awfy/git_client"

class TestGitClient < Minitest::Test
  def setup
    # Create a temporary directory for testing
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    # Clean up temporary directory
    FileUtils.remove_entry(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def create_test_git_client
    mock_git = Minitest::Mock.new
    yield mock_git
    mock_lib = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)
    {mock_git:, mock_lib:}
  end

  def with_mock_client(mocks)
    # Stub the Git.open method to return our mock
    Git.stub(:open, mocks[:mock_git]) do
      git_client = Awfy::GitClient.new(path: @temp_dir)
      git_client.instance_variable_set(:@client, mocks[:mock_git])
      git_client.instance_variable_set(:@client_lib, mocks[:mock_lib])

      yield git_client
    end

    mocks[:mock_git].verify
  end

  def test_current_branch
    mocks = create_test_git_client do |mock_git|
      mock_git.expect(:current_branch, "main")
    end
    with_mock_client(mocks) do |git_client|
      assert_equal "main", git_client.current_branch
    end
  end

  def test_checkout
    mocks = create_test_git_client do |mock_git|
      mock_git.expect(:checkout, nil, ["feature-branch"])
    end
    with_mock_client(mocks) do |git_client|
      git_client.checkout!("feature-branch")
    end
  end
end
