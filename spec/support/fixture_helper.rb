module FixtureHelper
  module_function

  def rspec_core_repo
    clone_rspec_core_if_needed
    RepositoryMerger::Repository.new(rspec_core_repo_path)
  end

  def clone_rspec_core_if_needed
    return if Dir.exist?(rspec_core_repo_path)
    system('git', 'clone', 'https://github.com/rspec/rspec-core.git', rspec_core_repo_path)
  end

  def rspec_core_repo_path
    File.join(PathHelper.project_root_path, 'tmp/rspec-core')
  end
end
