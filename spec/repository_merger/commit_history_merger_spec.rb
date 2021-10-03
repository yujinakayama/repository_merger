# frozen_string_literal: true

require 'repository_merger'
require 'stringio'

class RepositoryMerger
  RSpec.describe CommitHistoryMerger do
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

    def create_commit_history_merger
      configuration = create_configuration

      original_branches = configuration.original_repos.map { |repo| repo.branch('main') }.compact

      CommitHistoryMerger.new(
        configuration: configuration,
        references: original_branches,
        commit_message_conversion: commit_message_conversion
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

    let(:commit_message_conversion) do
      proc do |original_commit|
        "[#{original_commit.repo.name}] #{original_commit.message}"
      end
    end

    context 'when resuming previous import' do
      let(:repo_a_path) do
        git_init('repo_a') do
          with_git_time('00:00:00') { git_commit(message: 'main 1') }
          with_git_time('00:01:00') { git_commit(message: 'main 2') }
          with_git_time('00:02:00') { git_commit(message: 'main 3') }
        end
      end

      let(:repo_b_path) do
        git_init('repo_b') do
          with_git_time('00:00:10') { git_commit(message: 'main 1') }
          with_git_time('00:01:10') { git_commit(message: 'main 2') }
        end
      end

      before do
        previous_commit_history_merger = create_commit_history_merger

        imported_commit_count = 0

        allow(previous_commit_history_merger).to receive(:process_commit).and_wrap_original do |original_method, commit|
          original_method.call(commit)
          imported_commit_count += 1
          previous_commit_history_merger.wants_to_abort = true if imported_commit_count == 3
        end

        monorepo_head_commit = previous_commit_history_merger.run

        expect(commit_graph_of(monorepo_head_commit)).to eq(<<~'END')
          * 2020-01-01 00:01:00 +0000 [repo_a] main 2
          * 2020-01-01 00:00:10 +0000 [repo_b] main 1
          * 2020-01-01 00:00:00 +0000 [repo_a] main 1
        END

        previous_commit_history_merger.configuration.repo_commit_map.save
        expect(File.exist?(commit_map_file_path)).to be true
      end

      it 'properly imports only subsequent commits without creating duplicates' do
        commit_history_merger = create_commit_history_merger
        monorepo_head_commit = commit_history_merger.run

        expect(commit_graph_of(monorepo_head_commit)).to eq(<<~'END')
          * 2020-01-01 00:02:00 +0000 [repo_a] main 3
          * 2020-01-01 00:01:10 +0000 [repo_b] main 2
          * 2020-01-01 00:01:00 +0000 [repo_a] main 2
          * 2020-01-01 00:00:10 +0000 [repo_b] main 1
          * 2020-01-01 00:00:00 +0000 [repo_a] main 1
        END

        expect(commit_history_merger.configuration.repo_commit_map.map.values).to all have_attributes(size: 1)
      end
    end
  end
end
