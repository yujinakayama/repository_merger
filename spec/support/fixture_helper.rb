module FixtureHelper
  module_function

  def rspec_core_repo
    clone_rspec_core_if_needed
    RSpec::RepositoryMerger::Repository.new(rspec_core_repo_path)
  end

  def clone_rspec_core_if_needed
    return if Dir.exist?(rspec_core_repo_path)
    system('git', 'clone', 'https://github.com/rspec/rspec-core.git', rspec_core_repo_path)
  end

  def rspec_core_repo_path
    File.join(tmp_dir, 'rspec-core')
  end

  def tmp_dir
    File.expand_path('tmp')
  end
end
