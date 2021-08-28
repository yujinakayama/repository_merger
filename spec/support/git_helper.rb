require 'fileutils'
require 'open3'
require 'shellwords'

module GitHelper
  GitError = Class.new(StandardError)

  module_function

  def git_commit(message:)
    git(['commit', '--allow-empty', "--message=#{message}"])
  end

  def git_merge(branch_name)
    git(['merge', '--no-edit', branch_name])
  end

  def git_tag(name, message: nil)
    if message
      git(['tag', '--annotate', name, '--message', message])
    else
      git(['tag', name])
    end
  end

  def git_show(*args, path_prefix: 'PATH:')
    if args.first.respond_to?(:repo) && args.first.respond_to?(:revision_id)
      revision = args.first
      repo_path = revision.repo.path
      revision_id = revision.revision_id
    else
      repo_path, revision_id = *args
    end

    Dir.chdir(repo_path) do
      # By default `git show` outputs `index` lines (e.g. `index 00000000..ecf36731`)
      # in 7 or 8 digits (not sure what makes the difference though).
      # We need to spcify --full-index option is make the digits consistent.
      args = ['show', '--format=fuller', '--full-index']
      args.concat(["--src-prefix=#{path_prefix}", "--dst-prefix=#{path_prefix}"]) if path_prefix
      args << revision_id
      git(args)
    end
  end

  def git_graph(repo_path, branch_names = nil, format: nil)
    args = ['log', '--graph']
    args << "--format=#{format}" if format

    unless branch_names
      Dir.chdir(repo_path) do
        ref_names = git(['for-each-ref', '--format', '%(refname)']).each_line.map(&:chomp)
        branch_names = ref_names.grep(%r{\Arefs/heads/}).map { |ref| ref.sub(%r{\Arefs/heads/}, '') }
      end
    end

    args.concat(Array(branch_names))

    Dir.chdir(repo_path) do
      git(args)
    end
  end

  def git_init(repo_name)
    repo_path = File.join(PathHelper.tmp_path, repo_name)

    FileUtils.rm_rf(repo_path)
    FileUtils.mkdir_p(repo_path)

    Dir.chdir(repo_path) do
      git('init')
      yield if block_given?
    end

    repo_path
  end

  def git(arg)
    args = arg.is_a?(Array) ? arg : arg.shellsplit
    stdout, stderr, status = Open3.capture3('git', *args)
    raise GitError, stderr unless status.success?
    stdout.each_line.map { |line| line.sub(/ +$/, '') }.join
  end

  def with_git_date(date)
    original_env = ENV.to_h
    ENV['GIT_AUTHOR_DATE'] = ENV['GIT_COMMITTER_DATE'] = date
    yield
    ENV.replace(original_env)
  end
end
