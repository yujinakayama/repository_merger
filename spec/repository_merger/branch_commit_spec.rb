require 'repository_merger/branch_commit'

class RepositoryMerger
  RSpec.describe BranchCommit do
    let(:branch_commits) do
      repo.branches['origin/master'].topologically_ordered_commits_from_root
    end

    let(:repo) do
      FixtureHelper.rspec_core_repo
    end

    describe '#mainline?' do
      subject do
        commit.mainline?
      end

      # git log --graph --oneline | tail -40
      # * 80afa7fe more S2R
      # * a2e6be1d Spec to Rspec
      # * 7a5ee1b8 Now with 100% more functionality in Rspec::Core.warn/deprecate
      # *   9d6f06e0 Merge branch 'master' of git@github.com:rspec/core
      # |\
      # | * 5b2298f0 Spec > Rspec in mock adapter for rspec
      # * | 99fd5829 Adding in deprecation as Rspec::Core.deprecate
      # |/
      # *   65e8d861 Merge branch 'master' of git@github.com:rspec/core
      # |\
      # | *   4a61721f Merge branch 'master' of git@github.com:rspec/core
      # | |\
      # | * \   c03ee4c3 Merge branch 'master' of git@github.com:rspec/core
      # | |\ \
      # | * | | 5144ef0e all failures are just failures
      # * | | | 447fbcb6 Changing rcov task :coverage to :rcov, to bring unity to the projects rake tasks
      # * | | | 4c37c385 Spec->Rspec.   Refactoring complete
      # | |_|/
      # |/| |
      # * | | 6785d2b5 Fixing the coverage task for the current setup
      # | |/
      # |/|
      # * | f82fc660 Adding a TODO
      # * | a7c96c12 Aliasing context to describe
      # |/
      # * de5b5e0b Alias example as specify
      # * d151524e ignore tmp
      # * f821e957 add pending features from rspec
      # * c53aa111 use spec-expectations and add hook for spec-mocks
      # * 77cbfe20 Adding bin/rspec for simple CLI runner
      # * cf7e2561 Removing an errant print statement
      # * 4d7ec6e1 Adding a treasure map to enable beholder support
      # * ee9d1d58 Updating the coverage rake task to correctly allow the spec folder
      # * 23865c6d Adding in a script/console for local work
      # * afca7282 Initial migration of Micronaut to Spec/Core
      # * 5c3e49c6 Adding in gemspec
      # * f9ea4ecf Correcting the spelling of my name
      # * b5402369 Initial jeweler repository creation
      # * 7b8b714f Version bump to 0.0.0
      # * a3f941f4 Initial commit to rspec-core.

      context 'with a root commit' do
        let(:commit) do
          branch_commits.first
        end

        it { should be true }
      end

      context 'with a commit directly created on the branch' do
        let(:commit) do
          branch_commits.find { |commit| commit.id.start_with?('4c37c385') }
        end

        it { should be true }
      end

      context 'with a commit created on a topic branch and then merged into the mainline' do
        let(:commit) do
          branch_commits.find { |commit| commit.id.start_with?('5144ef0e') }
        end

        it { should be false }
      end

      context 'with a merge commit that merges a topic branch into the mainline' do
        let(:commit) do
          branch_commits.find { |commit| commit.id.start_with?('65e8d861') }
        end

        it { should be true }
      end

      context 'with a merge commit that merges a topic branch into another topic branch' do
        let(:commit) do
          branch_commits.find { |commit| commit.id.start_with?('4a61721f') }
        end

        it { should be false }
      end
    end
  end
end
