require 'rspec/repository_merger/repository'

class RSpec::RepositoryMerger
  RSpec.describe Repository do
    subject(:repo) do
      FixtureHelper.rspec_core_repo
    end

    describe '#branches' do
      it 'returns branches keyed by name' do
        expect(repo.branches).to include(
          'master'        => an_object_having_attributes(name: 'master'),
          'origin/master' => an_object_having_attributes(name: 'origin/master'),
        )
      end
    end
  end
end
