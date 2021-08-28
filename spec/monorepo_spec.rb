require 'digest'
require 'find'

destination_directory = "dest/#{`git rev-parse --abbrev-ref HEAD`.chomp}"

RSpec.describe 'merged RSpec monorepo', if: Dir.exist?("#{destination_directory}/monorepo") do
  include FileHelper
  include GitHelper

  around do |example|
    Dir.chdir(destination_directory) do
      example.run
    end
  end

  %w[
    main
    2-0-stable
    2-2-maintenance
    2-3-maintenance
    2-5-maintenance
    2-6-maintenance
    2-7-maintenance
    2-9-maintenance
    2-10-maintenance
    2-11-maintenance
    2-13-maintenance
    2-14-maintenance
    2-99-maintenance
    3-0-maintenance
    3-1-maintenance
    3-2-maintenance
    3-3-maintenance
    3-4-maintenance
    3-5-maintenance
    3-6-maintenance
    3-7-maintenance
    3-8-maintenance
    3-9-maintenance
  ].each do |branch_name|
    describe "#{branch_name} branch" do
      def commit_fingerprints_in(repo_path, revision_id)
        log = Dir.chdir(repo_path) do
          git(['log', '--format=%ai %ae, %ci %ce: %s', revision_id])
        end

        log.split("\n")
      end

      let(:commit_fingerprints_in_monorepo) do
        commit_fingerprints_in('monorepo', branch_name)
      end

      let(:commit_fingerprints_in_original_repos) do
        fingerprints = %w[rspec rspec-core rspec-expectations rspec-mocks rspec-support].sum([]) do |repo_name|
          commit_fingerprints_in("original_repos/#{repo_name}", "origin/#{branch_name}").map do |fingerprint|
            # Some commits have wrongly quoted author/committer emails
            fingerprint
              .sub(': ', ": [#{repo_name.sub(/\Arspec-/, '')}] ")
              .gsub("'raysanchez1979@gmail.com'", 'raysanchez1979@gmail.com')
          end
        rescue GitHelper::GitError
          []
        end

        raise if fingerprints.empty?

        fingerprints
      end

      before do
        repo_paths = %w[rspec rspec-core rspec-expectations rspec-mocks rspec-support].map { |name| "original_repos/#{name}" }
        repo_paths << 'monorepo'

        repo_paths.each do |repo_path|
          Dir.chdir(repo_path) do
            git("switch --discard-changes #{branch_name}")
            git('clean --force -d -x')
          end
        end
      end

      pending 'contains all the original commits' do
        expect(commit_fingerprints_in_monorepo.sort.join("\n"))
          .to eq(commit_fingerprints_in_original_repos.sort.join("\n"))
      end

      it 'has same contents as the original branch' do
        expect(list_of_files_with_digest('monorepo')).to eq(list_of_files_with_digest('original_repos'))
      end
    end
  end
end
