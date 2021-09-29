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

  {
    'main'             => { graph: true,  contents: true  },
    '2-2-maintenance'  => { graph: false, contents: false },
    '2-3-maintenance'  => { graph: false, contents: false },
    '2-5-maintenance'  => { graph: false, contents: false },
    '2-6-maintenance'  => { graph: false, contents: false },
    '2-7-maintenance'  => { graph: false, contents: false },
    '2-9-maintenance'  => { graph: false, contents: false },
    '2-10-maintenance' => { graph: false, contents: false },
    '2-11-maintenance' => { graph: false, contents: false },
    '2-13-maintenance' => { graph: false, contents: false },
    '2-14-maintenance' => { graph: true,  contents: true  },
    '2-99-maintenance' => { graph: true,  contents: true  },
    '3-0-maintenance'  => { graph: true,  contents: true  },
    '3-1-maintenance'  => { graph: true,  contents: true  },
    '3-2-maintenance'  => { graph: true,  contents: true  },
    '3-3-maintenance'  => { graph: true,  contents: true  },
    '3-4-maintenance'  => { graph: true,  contents: true  },
    '3-5-maintenance'  => { graph: true,  contents: true  },
    '3-6-maintenance'  => { graph: true,  contents: true  },
    '3-7-maintenance'  => { graph: true,  contents: true  },
    '3-8-maintenance'  => { graph: false, contents: true  },
    '3-9-maintenance'  => { graph: false, contents: true  },
  }.each do |branch_name, expected_results|
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
        original_repo_names.sum([]) do |repo_name|
          commit_fingerprints_in("original_repos/#{repo_name}", "origin/#{branch_name}").map do |fingerprint|
            # Some commits have wrongly quoted author/committer emails
            fingerprint
              .sub(': ', ": [#{repo_name.sub(/\Arspec-/, '')}] ")
              .gsub("'raysanchez1979@gmail.com'", 'raysanchez1979@gmail.com')
          end
        end
      end

      let(:original_repo_names) do
        if branch_name.start_with?('2')
          %w[rspec rspec-core rspec-expectations rspec-mocks]
        else
          %w[rspec rspec-core rspec-expectations rspec-mocks rspec-support]
        end
      end

      before do
        repo_paths = original_repo_names.map { |name| "original_repos/#{name}" }
        repo_paths << 'monorepo'

        repo_paths.each do |repo_path|
          Dir.chdir(repo_path) do
            git("switch --discard-changes #{branch_name}")
            git('clean --force -d -x')
          end
        end
      end

      it 'contains all the original commits', pending: !expected_results[:graph] do
        expect(commit_fingerprints_in_monorepo.sort.join("\n"))
          .to eq(commit_fingerprints_in_original_repos.sort.join("\n"))
      end

      it 'has same contents as the original branch', pending: !expected_results[:contents] do
        expect(list_of_files_with_digest('monorepo'))
          .to eq(list_of_files_with_digest('original_repos', only: original_repo_names))
      end
    end
  end
end
