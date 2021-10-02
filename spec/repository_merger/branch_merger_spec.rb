require 'repository_merger'
require 'stringio'

class RepositoryMerger
  RSpec.describe BranchMerger do
    include GitHelper

    def with_git_time(time, &block)
      with_git_date(fake_date_for(time), &block)
    end

    def fake_date_for(time)
      "2020-01-01 #{time} +0000"
    end

    def commit_graph_of(repo_path)
      git_graph(repo_path, format: '%ci %s%d')
    end

    subject(:branch_merger) do
      create_branch_merger
    end

    def create_branch_merger
      BranchMerger.new(
        configuration: create_configuration,
        target_branch_name: 'master',
        commit_message_transformer: commit_message_transformer
      )
    end

    def create_configuration
      Configuration.new(
        original_repo_paths: [repo_a_path, repo_b_path],
        monorepo_path: monorepo_path,
        commit_map_file_path: commit_map_file_path,
        log_output: log_output
      )
    end

    let(:monorepo_path) do
      git_init('monorepo')
    end

    let(:commit_map_file_path) do
      PathHelper.tmp_path.join('commit_map.json')
    end

    before do
      File.delete(commit_map_file_path) if File.exist?(commit_map_file_path)
    end

    let(:log_output) do
      StringIO.new
    end

    let(:commit_message_transformer) do
      proc do |original_commit|
        "[#{original_commit.repo.name}] #{original_commit.message}"
      end
    end

    context 'when resuming previous import' do
      let(:repo_a_path) do
        git_init('repo_a') do
          with_git_time('00:00:00') { git_commit(message: 'master 1') }
          with_git_time('00:01:00') { git_commit(message: 'master 2') }
          with_git_time('00:02:00') { git_commit(message: 'master 3') }
        end
      end

      let(:repo_b_path) do
        git_init('repo_b') do
          with_git_time('00:00:10') { git_commit(message: 'master 1') }
          with_git_time('00:01:10') { git_commit(message: 'master 2') }
        end
      end

      before do
        previous_branch_merger = create_branch_merger

        imported_commit_count = 0

        allow(previous_branch_merger).to receive(:process_commit).and_wrap_original do |original_method, commit|
          original_method.call(commit)
          imported_commit_count += 1
          previous_branch_merger.wants_to_abort = true if imported_commit_count == 3
        end

        previous_branch_merger.run

        expect(commit_graph_of(monorepo_path)).to eq(<<~'END')
          * 2020-01-01 00:01:00 +0000 [repo_a] master 2 (HEAD -> master)
          * 2020-01-01 00:00:10 +0000 [repo_b] master 1
          * 2020-01-01 00:00:00 +0000 [repo_a] master 1
        END

        previous_branch_merger.configuration.repo_commit_map.save
        expect(File.exist?(commit_map_file_path)).to be true
      end

      it 'properly imports only subsequent commits without creating duplicates' do
        branch_merger.run

        expect(commit_graph_of(monorepo_path)).to eq(<<~'END')
          * 2020-01-01 00:02:00 +0000 [repo_a] master 3 (HEAD -> master)
          * 2020-01-01 00:01:10 +0000 [repo_b] master 2
          * 2020-01-01 00:01:00 +0000 [repo_a] master 2
          * 2020-01-01 00:00:10 +0000 [repo_b] master 1
          * 2020-01-01 00:00:00 +0000 [repo_a] master 1
        END

        expect(branch_merger.configuration.repo_commit_map.map.values).to all have_attributes(size: 1)
      end
    end
  end
end
