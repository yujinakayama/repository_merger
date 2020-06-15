require 'rspec/repository_merger/commit'

class RSpec::RepositoryMerger
  RSpec.describe Commit do
    let(:repo) do
      FixtureHelper.rspec_core_repo
    end

    describe '#merge_commit?' do
      subject do
        commit.merge_commit?
      end

      context 'with a root commit' do
        let(:commit) do
          repo.lookup('a3f941f465f640a09bce6c2e8e88b533b8202c12')
        end

        it { should be false }
      end

      context 'with a commit having only a single parent' do
        let(:commit) do
          repo.lookup('7b8b714f967c8f345ee88d10f0b61a78c1e95e49')
        end

        it { should be false }
      end

      context 'with a commit having two parents' do
        let(:commit) do
          repo.lookup('65e8d861384a6f587e20281691ce151cf95208a7')
        end

        it { should be true }
      end
    end
  end
end
