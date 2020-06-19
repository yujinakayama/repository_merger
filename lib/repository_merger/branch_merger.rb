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
      progressbar.log "Merging `#{branch_name}` branches of #{original_branches.map { |original_branch| original_branch.repo.name }.join(', ')} into `#{branch_name_in_merged_repo}` branch of #{merged_repo.path}..."

      if original_branches_are_already_imported?
        progressbar.log "  The branches are already imported."
        return
      end

      while (original_commit = unprocessed_original_commit_queue.next)
        process_commit(original_commit)
      end
    end

    def original_branches_are_already_imported?
      commit_ids_in_merged_repo = original_branches.map do |original_branch|
        commit_map.commit_id_in_merged_repo_for(original_branch.target_commit)
      end

      return false if commit_ids_in_merged_repo.any?(&:nil?)

      commit_ids_in_merged_repo.include?(current_branch_head_id_in_merged_repo)
    end

    def process_commit(original_commit)
      progressbar.log "  #{original_commit.commit_time} [#{original_commit.repo.name}] #{original_commit.message.each_line.first}"

      if commit_map.commit_id_in_merged_repo_for(original_commit)
        progressbar.log "    Already imported."
      else
        import_commit_into_merged_repo(original_commit)
      end

      update_branch_in_merged_repo_if_needed(original_commit)

      progressbar.increment
    end

    def update_branch_in_merged_repo_if_needed(original_commit)
      return unless original_commit.mainline?

      commit_id_in_merged_repo = commit_map.commit_id_in_merged_repo_for(original_commit)
      merged_repo.create_or_update_branch(branch_name_in_merged_repo, commit_id: commit_id_in_merged_repo)
    end

    def import_commit_into_merged_repo(original_commit)
      parent_commit_ids_in_merged_repo =
        if original_commit.root?
          [current_branch_head_id_in_merged_repo].compact
        else
          original_commit.parents.map do |original_parent_commit|
            if original_commit.mainline? && original_parent_commit.mainline?
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
        message: commit_message_from(original_commit)
      )

      commit_map.register(
        commit_id_in_merged_repo: new_commit_in_merged_repo.id,
        original_commit: original_commit
      )
    end

    def current_branch_head_id_in_merged_repo
      branch = merged_repo.branch(branch_name_in_merged_repo)
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

    def unprocessed_original_commit_queue
      @unprocessed_original_commit_queue ||= OriginalCommitQueue.new(original_branches)
    end

    def original_branches
      original_repos.map { |repo| repo.branch(branch_name) }.compact
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
        total: unprocessed_original_commit_queue.size
      )
    end

    class OriginalCommitQueue
      attr_reader :branches, :current_queues, :next_queues

      def initialize(branches)
        @branches = branches
        @current_queues, @next_queues = classify_commits
      end

      def next
        queue_having_oldest_next_commit =
          current_queues.reject(&:empty?).min_by { |queue| queue.first.commit_time }

        if queue_having_oldest_next_commit
          queue_having_oldest_next_commit.shift
        elsif next_queues
          @current_queues = next_queues
          @next_queues = nil
          self.next
        else
          nil
        end
      end

      def size
        [current_queues, next_queues].compact.flatten.sum(&:size)
      end

      private

      def classify_commits
        priority_commit_queues = []
        non_priority_commit_queues = []

        branches.each do |branch|
          priority_commit_queue, non_priority_commit_queue = classify_commits_in(branch)
          priority_commit_queues << priority_commit_queue
          non_priority_commit_queues << non_priority_commit_queue
        end

        [priority_commit_queues, non_priority_commit_queues]
      end

      def classify_commits_in(target_branch)
        other_branches = target_branch.repo.branches - [target_branch]

        commits_contained_in_other_branches = other_branches.each_with_object(Set.new) do |other_branch, commits|
          commits.merge(other_branch.topologically_ordered_commits_from_root)
        end.to_a

        priority_commits = target_branch.topologically_ordered_commits_from_root & commits_contained_in_other_branches.to_a
        non_priority_commits = target_branch.topologically_ordered_commits_from_root - priority_commits

        [priority_commits, non_priority_commits]
      end

      def repos
        @repos ||= branches.map(&:repo)
      end
    end
  end
end
