# frozen_string_literal: true

require 'repository_merger/github_issue_reference'

RSpec.describe 'merged RSpec monorepo', if: Dir.exist?(PathHelper.dest_path.join('monorepo')) do
  include FileHelper
  include GitHelper

  around do |example|
    Dir.chdir(PathHelper.dest_path) do
      example.run
    end
  end

  {
    'main'             => { graph: true,  contents: true  },
    '2-2-maintenance'  => { graph: true,  contents: true  },
    '2-3-maintenance'  => { graph: true,  contents: true  },
    '2-5-maintenance'  => { graph: true,  contents: true  },
    '2-6-maintenance'  => { graph: true,  contents: true  },
    '2-7-maintenance'  => { graph: true,  contents: true  },
    '2-9-maintenance'  => { graph: true,  contents: true  },
    '2-10-maintenance' => { graph: true,  contents: true  },
    '2-11-maintenance' => { graph: true,  contents: true  },
    '2-13-maintenance' => { graph: true,  contents: true  },
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
    '3-8-maintenance'  => { graph: true,  contents: true  },
    '3-9-maintenance'  => { graph: true,  contents: true  },
    '3-10-maintenance' => { graph: true,  contents: true  }
  }.each do |branch_name, expected_results|
    describe "#{branch_name} branch" do
      def commit_fingerprints_in(repo_path, revision_id)
        Dir.chdir(repo_path) do
          git(['log', '--format=%ci %ce, %ai %ae: %s', revision_id]).split("\n")
        end
      end

      let(:commit_fingerprints_in_monorepo) do
        commit_fingerprints_in('monorepo', branch_name)
      end

      let(:commit_fingerprints_in_original_repos) do
        original_repo_names.sum([]) do |repo_name|
          commit_fingerprints_in("original_repos/#{repo_name}", "origin/#{branch_name}").map do |fingerprint|
            convert_original_commit_fingerprint(fingerprint, repo_name)
          end
        end
      end

      def convert_original_commit_fingerprint(fingerprint, repo_name)
        fingerprint = fingerprint.sub(': ', ": [#{repo_name.sub(/\Arspec-/, '')}] ")

        fingerprint = RepositoryMerger::GitHubIssueReference.convert_repo_local_references_to_absolute_ones_in(
          fingerprint,
          username: 'rspec',
          repo_name: repo_name
        )

        # Some commits have wrongly quoted author/committer emails
        fingerprint.gsub("'raysanchez1979@gmail.com'", 'raysanchez1979@gmail.com')
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

  def self.tag_name_in_monorepo_for(original_tag_name, repo_name)
    tag_name = original_tag_name
    tag_name = "v#{tag_name}" if tag_name.match?(/\A\d+\.\d+\.\d+/)

    scope = repo_name.sub(/\Arspec-/, '')

    "#{tag_name}-#{scope}"
  end

  {
    'rspec' => {
      'v2.0.0.a1'      => true,
      '2.0.0.a2'       => true,
      '2.0.0.a3'       => true,
      'v2.0.0.a4'      => true,
      'v2.0.0.a5'      => true,
      'v2.0.0.a6'      => true,
      'v2.0.0.a7'      => true,
      'v2.0.0.a8'      => true,
      'v2.0.0.a9'      => true,
      'v2.0.0.a10'     => true,
      'v2.0.0.beta.1'  => true,
      'v2.0.0.beta.2'  => true,
      'v2.0.0.beta.3'  => true,
      'v2.0.0.beta.4'  => true,
      'v2.0.0.beta.5'  => true,
      'v2.0.0.beta.6'  => true,
      'v2.0.0.beta.7'  => true,
      'v2.0.0.beta.8'  => true,
      'v2.0.0.beta.9'  => true,
      'v2.0.0.beta.10' => true,
      'v2.0.0.beta.11' => true,
      'v2.0.0.beta.12' => true,
      'v2.0.0.beta.13' => true,
      'v2.0.0.beta.14' => true,
      'v2.0.0.beta.15' => true,
      'v2.0.0.beta.16' => true,
      'v2.0.0.beta.17' => true,
      'v2.0.0.beta.18' => true,
      'v2.0.0.beta.19' => true,
      'v2.0.0.beta.20' => true,
      'v2.0.0.beta.21' => true,
      'v2.0.0.beta.22' => true,
      'v2.0.0.rc'      => true,
      'v2.0.0'         => true,
      'v2.0.1'         => true,
      'v2.1.0'         => true,
      'v2.2.0'         => true,
      'v2.3.0'         => true,
      'v2.4.0'         => true,
      'v2.5.0'         => true,
      'v2.6.0.rc1'     => true,
      'v2.6.0.rc2'     => true,
      'v2.6.0.rc3'     => true,
      'v2.6.0.rc4'     => true,
      'v2.6.0.rc5'     => true,
      'v2.6.0.rc6'     => true,
      'v2.6.0'         => true,
      'v2.7.0.rc1'     => true,
      'v2.7.0'         => true,
      'v2.8.0.rc1'     => true,
      'v2.8.0.rc2'     => true,
      'v2.8.0'         => true,
      'v2.9.0.rc1'     => true,
      'v2.9.0.rc2'     => true,
      'v2.9.0'         => true,
      'v2.10.0'        => true,
      'v2.11.0'        => true,
      'v2.12.0'        => true,
      'v2.13.0'        => true,
      'v2.14.0.rc1'    => true,
      'v2.14.0'        => true,
      'v2.14.1'        => true,
      'v2.99.0.beta1'  => true,
      'v2.99.0.beta2'  => true,
      'v2.99.0.rc1'    => true,
      'v2.99.0'        => true,
      'v3.0.0.beta1'   => true,
      'v3.0.0.beta2'   => true,
      'v3.0.0.rc1'     => true,
      'v3.0.0'         => true,
      'v3.1.0'         => true,
      'v3.2.0'         => true,
      'v3.3.0'         => true,
      'v3.4.0'         => true,
      'v3.5.0.beta1'   => true,
      'v3.5.0.beta2'   => true,
      'v3.5.0.beta3'   => true,
      'v3.5.0.beta4'   => true,
      'v3.5.0'         => true,
      'v3.6.0.beta1'   => true,
      'v3.6.0.beta2'   => true,
      'v3.6.0'         => true,
      'v3.7.0'         => true,
      'v3.8.0'         => true,
      'v3.9.0'         => true,
      'v3.10.0'        => true
    },
    'rspec-core' => {
      'v0.0.0'         => true,
      'v2.0.0.a1'      => true,
      '2.0.0.a2'       => true,
      '2.0.0.a3'       => true,
      'v2.0.0.a4'      => true,
      'v2.0.0.a5'      => true,
      'v2.0.0.a6'      => true,
      'v2.0.0.a7'      => true,
      'v2.0.0.a8'      => true,
      'v2.0.0.a9'      => true,
      'v2.0.0.a10'     => true,
      'v2.0.0.beta.1'  => true,
      'v2.0.0.beta.2'  => true,
      'v2.0.0.beta.3'  => true,
      'v2.0.0.beta.4'  => true,
      'v2.0.0.beta.5'  => true,
      'v2.0.0.beta.6'  => true,
      'v2.0.0.beta.7'  => true,
      'v2.0.0.beta.8'  => true,
      'v2.0.0.beta.9'  => true,
      'v2.0.0.beta.10' => true,
      'v2.0.0.beta.11' => true,
      'v2.0.0.beta.12' => true,
      'v2.0.0.beta.13' => true,
      'v2.0.0.beta.14' => true,
      'v2.0.0.beta.15' => true,
      'v2.0.0.beta.16' => true,
      'v2.0.0.beta.17' => true,
      'v2.0.0.beta.18' => true,
      'v2.0.0.beta.19' => true,
      'v2.0.0.beta.20' => true,
      'v2.0.0.beta.21' => true,
      'v2.0.0.beta.22' => true,
      'v2.0.0.rc'      => true,
      'v2.0.0'         => true,
      'v2.0.1'         => true,
      'v2.1.0'         => true,
      'v2.2.0'         => true,
      'v2.2.1'         => true,
      'v2.3.0'         => true,
      'v2.3.1'         => true,
      'v2.4.0'         => true,
      'v2.5.0'         => true,
      'v2.5.1'         => true,
      'v2.5.2'         => true,
      'v2.6.0.rc1'     => true,
      'v2.6.0.rc2'     => true,
      'v2.6.0.rc3'     => true,
      'v2.6.0.rc4'     => true,
      'v2.6.0.rc5'     => true,
      'v2.6.0.rc6'     => true,
      'v2.6.0'         => true,
      'v2.6.1'         => true,
      'v2.6.2.rc'      => true,
      'v2.6.2'         => true,
      'v2.6.3.beta1'   => true,
      'v2.6.3'         => true,
      'v2.6.4'         => true,
      'v2.7.0.rc1'     => true,
      'v2.7.0'         => true,
      'v2.7.1'         => true,
      'v2.8.0.rc1'     => true,
      'v2.8.0.rc2'     => true,
      'v2.8.0'         => true,
      'v2.9.0.rc1'     => true,
      'v2.9.0.rc2'     => true,
      'v2.9.0'         => true,
      'v2.10.0'        => true,
      'v2.10.1'        => true,
      'v2.11.0'        => true,
      'v2.11.1'        => true,
      'v2.11.2'        => false,
      'v2.11.3'        => false,
      'v2.12.0'        => true,
      'v2.12.1'        => true,
      'v2.12.2'        => true,
      'v2.13.0'        => true,
      'v2.13.1'        => true,
      'v2.14.0.rc1'    => true,
      'v2.14.0'        => true,
      'v2.14.1'        => true,
      'v2.14.2'        => true,
      'v2.14.3'        => true,
      'v2.14.4'        => true,
      'v2.14.5'        => true,
      'v2.14.6'        => true,
      'v2.14.7'        => true,
      'v2.14.8'        => true,
      'v2.99.0.beta1'  => true,
      'v2.99.0.beta2'  => true,
      'v2.99.0.rc1'    => true,
      'v2.99.0'        => true,
      'v2.99.1'        => true,
      'v2.99.2'        => true,
      'v3.0.0.beta1'   => true,
      'v3.0.0.beta2'   => true,
      'v3.0.0.rc1'     => true,
      'v3.0.0'         => true,
      'v3.0.1'         => true,
      'v3.0.2'         => true,
      'v3.0.3'         => true,
      'v3.0.4'         => true,
      'v3.1.0'         => true,
      'v3.1.1'         => true,
      'v3.1.2'         => true,
      'v3.1.3'         => true,
      'v3.1.4'         => true,
      'v3.1.5'         => true,
      'v3.1.6'         => true,
      'v3.1.7'         => true,
      'v3.2.0'         => true,
      'v3.2.1'         => true,
      'v3.2.2'         => true,
      'v3.2.3'         => true,
      'v3.3.0'         => true,
      'v3.3.1'         => true,
      'v3.3.2'         => true,
      'v3.4.0'         => true,
      'v3.4.1'         => true,
      'v3.4.2'         => true,
      'v3.4.3'         => true,
      'v3.4.4'         => true,
      'v3.5.0.beta1'   => true,
      'v3.5.0.beta2'   => true,
      'v3.5.0.beta3'   => true,
      'v3.5.0.beta4'   => true,
      'v3.5.0'         => true,
      'v3.5.1'         => true,
      'v3.5.2'         => true,
      'v3.5.3'         => true,
      'v3.5.4'         => true,
      'v3.6.0.beta1'   => true,
      'v3.6.0.beta2'   => true,
      'v3.6.0'         => true,
      'v3.7.0'         => true,
      'v3.7.1'         => true,
      'v3.8.0'         => true,
      'v3.8.1'         => true,
      'v3.8.2'         => true,
      'v3.9.0'         => true,
      'v3.9.1'         => true,
      'v3.9.2'         => true,
      'v3.9.3'         => true,
      'v3.10.0'        => true,
      'v3.10.1'        => true
    },
    'rspec-expectations' => {
      'v0.0.0'         => true,
      'v2.0.0.a1'      => true,
      '2.0.0.a2'       => true,
      '2.0.0.a3'       => true,
      'v2.0.0.a4'      => true,
      'v2.0.0.a5'      => true,
      'v2.0.0.a6'      => true,
      'v2.0.0.a7'      => true,
      'v2.0.0.a8'      => true,
      'v2.0.0.a9'      => true,
      'v2.0.0.a10'     => true,
      'v2.0.0.beta.1'  => true,
      'v2.0.0.beta.2'  => true,
      'v2.0.0.beta.3'  => true,
      'v2.0.0.beta.4'  => true,
      'v2.0.0.beta.5'  => true,
      'v2.0.0.beta.6'  => true,
      'v2.0.0.beta.7'  => true,
      'v2.0.0.beta.8'  => true,
      'v2.0.0.beta.9'  => true,
      'v2.0.0.beta.10' => true,
      'v2.0.0.beta.11' => true,
      'v2.0.0.beta.12' => true,
      'v2.0.0.beta.13' => true,
      'v2.0.0.beta.14' => true,
      'v2.0.0.beta.15' => true,
      'v2.0.0.beta.16' => true,
      'v2.0.0.beta.17' => true,
      'v2.0.0.beta.18' => true,
      'v2.0.0.beta.19' => true,
      'v2.0.0.beta.20' => true,
      'v2.0.0.beta.21' => true,
      'v2.0.0.beta.22' => true,
      'v2.0.0.rc'      => true,
      'v2.0.0'         => true,
      'v2.0.1'         => true,
      'v2.1.0'         => true,
      'v2.2.0'         => true,
      'v2.3.0'         => true,
      'v2.4.0'         => true,
      'v2.5.0'         => true,
      'v2.6.0.rc1'     => true,
      'v2.6.0.rc2'     => true,
      'v2.6.0.rc3'     => true,
      'v2.6.0.rc4'     => true,
      'v2.6.0.rc5'     => true,
      'v2.6.0.rc6'     => true,
      'v2.6.0'         => true,
      'v2.7.0.rc1'     => true,
      'v2.7.0'         => true,
      'v2.8.0.rc1'     => true,
      'v2.8.0.rc2'     => true,
      'v2.8.0'         => true,
      'v2.9.0.rc1'     => true,
      'v2.9.0.rc2'     => true,
      'v2.9.0'         => true,
      'v2.9.1'         => true,
      'v2.10.0'        => true,
      'v2.11.0'        => true,
      'v2.11.1'        => true,
      'v2.11.2'        => true,
      'v2.11.3'        => true,
      'v2.12.0'        => true,
      'v2.12.1'        => true,
      'v2.13.0'        => true,
      'v2.14.0.rc1'    => true,
      'v2.14.0'        => true,
      'v2.14.1'        => true,
      'v2.14.2'        => true,
      'v2.14.3'        => true,
      'v2.14.4'        => true,
      'v2.14.5'        => true,
      'v2.99.0.beta1'  => true,
      'v2.99.0.beta2'  => true,
      'v2.99.0.rc1'    => true,
      'v2.99.0'        => true,
      'v2.99.1'        => true,
      'v2.99.2'        => true,
      'v3.0.0.beta1'   => true,
      'v3.0.0.beta2'   => true,
      'v3.0.0.rc1'     => true,
      'v3.0.0'         => true,
      'v3.0.1'         => true,
      'v3.0.2'         => true,
      'v3.0.3'         => true,
      'v3.0.4'         => true,
      'v3.1.0'         => true,
      'v3.1.1'         => true,
      'v3.1.2'         => true,
      'v3.2.0'         => true,
      'v3.2.1'         => true,
      'v3.3.0'         => true,
      'v3.3.1'         => true,
      'v3.4.0'         => true,
      'v3.5.0.beta1'   => true,
      'v3.5.0.beta2'   => true,
      'v3.5.0.beta3'   => true,
      'v3.5.0.beta4'   => true,
      'v3.5.0'         => true,
      'v3.6.0.beta1'   => true,
      'v3.6.0.beta2'   => true,
      'v3.6.0'         => true,
      'v3.7.0'         => true,
      'v3.8.0'         => true,
      'v3.8.1'         => true,
      'v3.8.2'         => true,
      'v3.8.3'         => true,
      'v3.8.4'         => true,
      'v3.8.5'         => true,
      'v3.8.6'         => true,
      'v3.9.0'         => true,
      'v3.9.1'         => true,
      'v3.9.2'         => true,
      'v3.9.3'         => true,
      'v3.9.4'         => true,
      'v3.10.0'        => true,
      'v3.10.1'        => true
    },
    'rspec-mocks' => {
      'v0.0.0'         => true,
      'v2.0.0.a1'      => true,
      '2.0.0.a2'       => true,
      '2.0.0.a3'       => true,
      'v2.0.0.a4'      => true,
      'v2.0.0.a5'      => true,
      'v2.0.0.a6'      => true,
      'v2.0.0.a7'      => true,
      'v2.0.0.a8'      => true,
      'v2.0.0.a9'      => true,
      'v2.0.0.a10'     => true,
      'v2.0.0.beta.1'  => true,
      'v2.0.0.beta.2'  => true,
      'v2.0.0.beta.3'  => true,
      'v2.0.0.beta.4'  => true,
      'v2.0.0.beta.5'  => true,
      'v2.0.0.beta.6'  => true,
      'v2.0.0.beta.7'  => true,
      'v2.0.0.beta.8'  => true,
      'v2.0.0.beta.9'  => true,
      'v2.0.0.beta.10' => true,
      'v2.0.0.beta.11' => true,
      'v2.0.0.beta.12' => true,
      'v2.0.0.beta.13' => true,
      'v2.0.0.beta.14' => true,
      'v2.0.0.beta.15' => true,
      'v2.0.0.beta.16' => true,
      'v2.0.0.beta.17' => true,
      'v2.0.0.beta.18' => true,
      'v2.0.0.beta.19' => true,
      'v2.0.0.beta.20' => true,
      'v2.0.0.beta.21' => true,
      'v2.0.0.beta.22' => true,
      'v2.0.0.rc'      => true,
      'v2.0.0'         => true,
      'v2.0.1'         => true,
      'v2.1.0'         => true,
      'v2.2.0'         => true,
      'v2.2.1'         => false,
      'v2.3.0'         => true,
      'v2.3.1'         => false,
      'v2.4.0'         => true,
      'v2.5.0'         => true,
      'v2.5.1'         => false,
      'v2.5.2'         => false,
      'v2.6.0.rc1'     => true,
      'v2.6.0.rc2'     => true,
      'v2.6.0.rc3'     => true,
      'v2.6.0.rc4'     => true,
      'v2.6.0.rc5'     => true,
      'v2.6.0.rc6'     => true,
      'v2.6.0'         => true,
      'v2.6.1'         => false,
      'v2.6.2.rc'      => false,
      'v2.6.2'         => false,
      'v2.6.3.beta1'   => false,
      'v2.6.3'         => false,
      'v2.6.4'         => false,
      'v2.7.0.rc1'     => true,
      'v2.7.0'         => true,
      'v2.7.1'         => false,
      'v2.8.0.rc1'     => true,
      'v2.8.0.rc2'     => true,
      'v2.8.0'         => true,
      'v2.9.0.rc1'     => true,
      'v2.9.0.rc2'     => true,
      'v2.9.0'         => true,
      'v2.10.0'        => true,
      'v2.10.1'        => true,
      'v2.11.0'        => true,
      'v2.11.1'        => true,
      'v2.11.2'        => true,
      'v2.11.3'        => true,
      'v2.12.0'        => true,
      'v2.12.1'        => true,
      'v2.12.2'        => true,
      'v2.13.0'        => true,
      'v2.13.1'        => true,
      'v2.14.0.rc1'    => true,
      'v2.14.0'        => true,
      'v2.14.1'        => true,
      'v2.14.2'        => true,
      'v2.14.3'        => true,
      'v2.14.4'        => true,
      'v2.14.5'        => true,
      'v2.14.6'        => true,
      'v2.99.0.beta1'  => true,
      'v2.99.0.beta2'  => true,
      'v2.99.0.rc1'    => true,
      'v2.99.0'        => true,
      'v2.99.1'        => true,
      'v2.99.2'        => true,
      'v2.99.3'        => true,
      'v2.99.4'        => true,
      'v3.0.0.beta1'   => true,
      'v3.0.0.beta2'   => true,
      'v3.0.0.rc1'     => true,
      'v3.0.0'         => true,
      'v3.0.1'         => true,
      'v3.0.2'         => true,
      'v3.0.3'         => true,
      'v3.0.4'         => true,
      'v3.1.0'         => true,
      'v3.1.1'         => true,
      'v3.1.2'         => true,
      'v3.1.3'         => true,
      'v3.2.0'         => true,
      'v3.2.1'         => true,
      'v3.3.0'         => true,
      'v3.3.1'         => true,
      'v3.3.2'         => true,
      'v3.4.0'         => true,
      'v3.4.1'         => true,
      'v3.5.0.beta1'   => true,
      'v3.5.0.beta2'   => true,
      'v3.5.0.beta3'   => true,
      'v3.5.0.beta4'   => true,
      'v3.5.0'         => true,
      'v3.6.0.beta1'   => true,
      'v3.6.0.beta2'   => true,
      'v3.6.0'         => true,
      'v3.7.0'         => true,
      'v3.8.0'         => true,
      'v3.8.1'         => true,
      'v3.8.2'         => true,
      'v3.9.0'         => true,
      'v3.9.1'         => true,
      'v3.10.0'        => true,
      'v3.10.1'        => true,
      'v3.10.2'        => true
    },
    'rspec-support' => {
      'v3.0.0.beta1' => true,
      'v3.0.0.beta2' => true,
      'v3.0.0.rc1'   => true,
      'v3.0.0'       => true,
      'v3.0.1'       => true,
      'v3.0.2'       => true,
      'v3.0.3'       => true,
      'v3.0.4'       => true,
      'v3.1.0'       => true,
      'v3.1.1'       => true,
      'v3.1.2'       => true,
      'v3.2.0'       => true,
      'v3.2.1'       => true,
      'v3.2.2'       => true,
      'v3.3.0'       => true,
      'v3.4.0'       => true,
      'v3.4.1'       => true,
      'v3.5.0.beta1' => true,
      'v3.5.0.beta2' => true,
      'v3.5.0.beta3' => true,
      'v3.5.0.beta4' => true,
      'v3.5.0'       => true,
      'v3.6.0.beta1' => true,
      'v3.6.0.beta2' => true,
      'v3.6.0'       => true,
      'v3.7.0'       => true,
      'v3.7.1'       => true,
      'v3.8.0'       => true,
      'v3.8.2'       => true,
      'v3.8.3'       => true,
      'v3.9.0'       => true,
      'v3.9.1'       => true,
      'v3.9.2'       => true,
      'v3.9.3'       => true,
      'v3.9.4'       => true,
      'v3.10.0'      => true,
      'v3.10.1'      => true,
      'v3.10.2'      => true
    }
  }.each do |repo_name, tags|
    tags.each do |original_tag_name, imported|
      new_tag_name = tag_name_in_monorepo_for(original_tag_name, repo_name)

      describe "#{new_tag_name} tag" do
        around do |example|
          Dir.chdir('monorepo') do
            example.run
          end
        end

        it 'is imported', pending: !imported do
          expect { git(['rev-parse', new_tag_name, '--']) }.not_to raise_error
        end
      end
    end
  end

  describe 'v2.0.0.beta.9-core tag which is not reachable from any target branches' do
    around do |example|
      Dir.chdir('monorepo') do
        example.run
      end
    end

    def tags_reachable_from(reference)
      git(['log', '--format=%D', reference])
        .split("\n")
        .select { |line| line.start_with?('tag: ') }
        .map { |line| line.delete_prefix('tag: ') }
    end

    let(:sibling_tag_names) do
      %w[rspec core expectations mocks].map { |suffix| "v2.0.0.beta.9-#{suffix}" }
    end

    it 'can reach to sibling tags' do
      expect(tags_reachable_from('v2.0.0.beta.9-core')).to include(
        'v2.0.0.beta.9-rspec',
        'v2.0.0.beta.9-expectations',
        'v2.0.0.beta.9-mocks'
      )
    end
  end
end
