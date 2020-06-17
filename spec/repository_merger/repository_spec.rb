require 'repository_merger/repository'

class RepositoryMerger
  RSpec.describe Repository do
    subject(:repo) do
      FixtureHelper.rspec_core_repo
    end

    describe '#branches' do
      it 'returns branches' do
        expect(repo.branches.map(&:name)).to include('master', 'origin/master')
      end
    end
  end
end
