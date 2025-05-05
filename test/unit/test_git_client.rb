# frozen_string_literal: true

require "test_helper"
require "awfy/git_client"

class TestGitClient < Minitest::Test
  def test_current_branch
    mock_git = Minitest::Mock.new
    mock_git.expect(:current_branch, "main")

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")
      assert_equal "main", git_client.current_branch
    end

    mock_git.verify
  end

  def test_checkout
    mock_git = Minitest::Mock.new
    mock_git.expect(:checkout, nil, ["feature-branch"])

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")
      git_client.checkout("feature-branch")
    end

    mock_git.verify
  end

  def test_object
    mock_object = Minitest::Mock.new
    mock_object.expect(:sha, "abcd1234")
    mock_object.expect(:message, "Test commit message")

    mock_git = Minitest::Mock.new
    mock_git.expect(:object, mock_object, ["HEAD"])

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")
      git_object = git_client.object("HEAD")
      assert_equal "abcd1234", git_object.sha
      assert_equal "Test commit message", git_object.message
    end

    mock_git.verify
    mock_object.verify
  end

  def test_lib_command
    # Create a mock Git::Lib object
    mock_lib = Minitest::Mock.new
    mock_lib.expect(:send, "mocked output", [:command, "rev-parse", "HEAD"])

    # Create a mock Git object
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")
      # Execute the command through the wrapper
      result = git_client.lib.command("rev-parse", "HEAD")
      assert_equal "mocked output", result
    end

    mock_git.verify
    mock_lib.verify
  end

  def test_lib_stash_save
    # Create a mock Git::Lib object
    mock_lib = Minitest::Mock.new
    mock_lib.expect(:send, "stashed changes", [:command, "stash", "save", "test message"])

    # Create a mock Git object
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")
      # Execute the stash save through the wrapper
      result = git_client.lib.stash_save("test message")
      assert_equal "stashed changes", result
    end

    mock_git.verify
    mock_lib.verify
  end

  def test_lib_stash_save_without_message
    # Create a mock Git::Lib object
    mock_lib = Minitest::Mock.new
    mock_lib.expect(:send, "stashed changes", [:command, "stash", "save"])

    # Create a mock Git object
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")
      # Execute the stash save through the wrapper without a message
      result = git_client.lib.stash_save
      assert_equal "stashed changes", result
    end

    mock_git.verify
    mock_lib.verify
  end

  def test_rev_parse
    # Create a mock for the lib wrapper that simulates a command result
    mock_lib_wrapper = Minitest::Mock.new
    mock_lib_wrapper.expect(:command, "abcd1234567890\n", ["rev-parse", "HEAD"])

    # Create mock Git object with mock lib
    mock_lib = Minitest::Mock.new
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")

      # Stub the lib method to return our mock lib wrapper
      git_client.stub(:lib, mock_lib_wrapper) do
        # Call rev_parse (which should call lib.command internally)
        result = git_client.rev_parse("HEAD")
        assert_equal "abcd1234567890", result
      end
    end

    mock_lib_wrapper.verify
  end

  def test_rev_list
    # Create a mock for the lib wrapper that simulates a command result
    mock_lib_wrapper = Minitest::Mock.new
    mock_lib_wrapper.expect(:command, "abc123\ndef456\nghi789\n", ["rev-list", "--reverse", "main..feature"])

    # Create mock Git object with mock lib
    mock_lib = Minitest::Mock.new
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")

      # Stub the lib method to return our mock lib wrapper
      git_client.stub(:lib, mock_lib_wrapper) do
        # Call rev_list (which should call lib.command internally)
        result = git_client.rev_list("--reverse", "main..feature")
        assert_equal ["abc123", "def456", "ghi789"], result
      end
    end

    mock_lib_wrapper.verify
  end

  def test_log
    # Create a mock for the lib wrapper that simulates a log command result
    mock_lib_wrapper = Minitest::Mock.new
    mock_lib_wrapper.expect(:command, "Test commit message\n", ["log", "-1", "--pretty=%s", "HEAD"])

    # Create mock Git object with mock lib
    mock_lib = Minitest::Mock.new
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")

      # Stub the lib method to return our mock lib wrapper
      git_client.stub(:lib, mock_lib_wrapper) do
        # Call log (which should call lib.command internally)
        result = git_client.log("-1", "--pretty=%s", "HEAD")
        assert_equal "Test commit message\n", result
      end
    end

    mock_lib_wrapper.verify
  end

  def test_commit_message
    # Create mock lib wrapper for the log call
    mock_lib_wrapper = Minitest::Mock.new
    mock_lib_wrapper.expect(:command, "Test commit message\n", ["log", "-1", "--pretty=%s", "HEAD"])

    # Create mock Git object with mock lib
    mock_lib = Minitest::Mock.new
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")

      # Stub the lib method to return our mock lib wrapper
      git_client.stub(:lib, mock_lib_wrapper) do
        result = git_client.commit_message("HEAD")
        assert_equal "Test commit message", result
      end
    end

    mock_lib_wrapper.verify
  end

  def test_commit_message_with_custom_format
    # Create mock lib wrapper for the log call with custom format
    mock_lib_wrapper = Minitest::Mock.new
    mock_lib_wrapper.expect(
      :command,
      "Author Name <email@example.com>\n",
      ["log", "-1", "--pretty=%an <%ae>", "abcd1234"]
    )

    # Create mock Git object with mock lib
    mock_lib = Minitest::Mock.new
    mock_git = Minitest::Mock.new
    mock_git.expect(:lib, mock_lib)

    Git.stub(:open, mock_git) do
      git_client = Awfy::GitClient.new("/path/to/repo")

      # Stub the lib method to return our mock lib wrapper
      git_client.stub(:lib, mock_lib_wrapper) do
        result = git_client.commit_message("abcd1234", "%an <%ae>")
        assert_equal "Author Name <email@example.com>", result
      end
    end

    mock_lib_wrapper.verify
  end
end
