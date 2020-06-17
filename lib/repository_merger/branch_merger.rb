# frozen_string_literal: true

require 'ruby-progressbar'

class RepositoryMerger
  class BranchMerger
    attr_reader :repo_merger, :branch_name, :commit_message_transformer, :progressbar

    def initialize(repo_merger, branch_name:, commit_message_transformer: nil)
      @repo_merger = repo_merger
      @branch_name = branch_name
      @commit_message_transformer = commit_message_transformer
      @progressbar = create_progressbar
    end

    def run
      progressbar.log "Merging `#{branch_name}` branches of #{original_repos.map(&:name).join(', ')} into `#{branch_name_in_merged_repo}` branch of #{merged_repo.path}..."

      while (original_commit = next_original_commit_to_process!)
        process_commit(original_commit)
      end
    end

    def next_original_commit_to_process!
      queue_having_oldest_next_commit =
        unprocessed_original_commit_queues.reject(&:empty?).min_by { |queue| queue.first.commit_time }

      queue_having_oldest_next_commit&.shift
    end

    def process_commit(original_commit)
      progressbar.log "  #{original_commit.commit_time} [#{original_commit.repo.name}] #{original_commit.message.each_line.first}"

      if commit_map.commit_id_in_merged_repo_for(original_commit)
        progressbar.log "    Already imported. Skipping."
      else
        import_commit_into_merged_repo(original_commit)
      end

      progressbar.increment
    end

    def import_commit_into_merged_repo(original_commit)
      parent_commit_ids_in_merged_repo =
        if original_commit.root?
          [current_branch_head_id_in_merged_repo].compact
        else
          original_commit.parents.map do |original_parent_commit|
            if original_parent_commit.mainline?
              current_branch_head_id_in_merged_repo
            else
              commit_map.commit_id_in_merged_repo_for(original_parent_commit)
            end
          end
        end

      new_commit_in_merged_repo = merged_repo.import_commit(
        original_commit,
        new_parent_ids: parent_commit_ids_in_merged_repo,
        subdirectory: original_commit.repo.name,
        message: commit_message_from(original_commit),
        branch_name: original_commit.mainline? ? branch_name_in_merged_repo : nil
      )

      commit_map.register(
        commit_id_in_merged_repo: new_commit_in_merged_repo.id,
        original_commit: original_commit
      )
    end

    def current_branch_head_id_in_merged_repo
      branch = merged_repo.branches[branch_name_in_merged_repo]
      return nil unless branch
      branch.target_commit.id
    end

    def commit_message_from(original_commit)
      if commit_message_transformer
        commit_message_transformer.call(original_commit)
      else
        original_commit.message
      end
    end

    def branch_name_in_merged_repo
      @branch_name_in_merged_repo ||= original_branches.first.local_name
    end

    def unprocessed_original_commit_queues
      @unprocessed_original_commit_queues ||= original_branches.map do |branch|
        branch.topologically_ordered_commits_from_root.dup
      end
    end

    def original_branches
      original_repos.map { |repo| repo.branches[branch_name] }.compact
    end

    def original_repos
      repo_merger.original_repos
    end

    def merged_repo
      repo_merger.merged_repo
    end

    def commit_map
      repo_merger.commit_map
    end

    def create_progressbar
      # 185/407 commits |====== 45 ======>                    |  ETA: 00:00:04
      # %c / %C         |       %w       >         %i         |       %e
      bar_format = " %t: %c/%C commits |%w>%i| %e "

      ProgressBar.create(
        format: bar_format,
        output: repo_merger.log_output,
        title: branch_name,
        total: unprocessed_original_commit_queues.sum { |queue| queue.size }
      )
    end
  end
end
