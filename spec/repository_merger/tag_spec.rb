# frozen_string_literal: true

require 'repository_merger/repository'

class RepositoryMerger
  RSpec.describe Tag do
    let(:repo) do
      FixtureHelper.rspec_core_repo
    end

    describe '#target_commit' do
      context 'with a lightweight tag' do
        let(:tag) do
          repo.tag('v2.0.0.beta.1')
        end

        it 'returns the target commit properly' do
          expect(tag.target_commit).to have_attributes(
            id: 'dd11a4714dc51d78a8ba5fec42adaffc6c92ea39',
            message: "rename method and avoid collision with 'assignments'\n"
          )
        end
      end

      context 'with an annotated tag' do
        let(:tag) do
          repo.tag('v3.0.0')
        end

        it 'returns the target commit properly' do
          expect(tag.target_commit).to have_attributes(
            id: '91f428f609b37422c08306517e09d2466ab8e516',
            message: "Release 3.0.0\n"
          )
        end
      end
    end
  end
end
