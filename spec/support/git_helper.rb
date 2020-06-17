require 'fileutils'
require 'shellwords'

module GitHelper
  module_function

  def git_show(commit, path_prefix = 'PATH:')
    Dir.chdir(commit.repo.path) do
      # By default `git show` outputs `index` lines (e.g. `index 00000000..ecf36731`)
      # in 7 or 8 digits (not sure what makes the difference though).
      # We need to spcify --full-index option is make the digits consistent.
      command = ['git', 'show', '--format=fuller', '--full-index']
      command.concat(["--src-prefix=#{path_prefix}", "--dst-prefix=#{path_prefix}"]) if path_prefix
      command << commit.id
      `#{command.shelljoin}`
    end
  end

  def git_log(repo, branch_name)
    Dir.chdir(repo.path) do
      `git log --format=%s --graph #{branch_name}`
    end
  end

  def git_init(repo_name)
    repo_path = File.join(PathHelper.tmp_path, repo_name)

    FileUtils.rm_rf(repo_path)
    FileUtils.mkdir_p(repo_path)

    Dir.chdir(repo_path) do
      `git init`
      yield if block_given?
    end

    repo_path
  end
end
