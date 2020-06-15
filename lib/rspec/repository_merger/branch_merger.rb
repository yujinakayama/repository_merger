# frozen_string_literal: true

module RSpec
  class RepositoryMerger
    class BranchMerger
      attr_reader :repo_merger, :branch_name

      def initialize(repo_merger, branch_name:)
        @repo_merger = repo_merger
        @branch_name = branch_name
      end

      def run
        puts "Merging `#{branch_name}` branches from #{original_repos.map(&:name).join(', ')} into #{merged_repo.path}..."

        while (original_commit = next_original_commit_to_process!)
          puts "  [#{original_commit.repo.name}] #{original_commit.commit_time} #{original_commit.message.inspect}"
          import_commit_into_merged_repo(original_commit)
        end
      end

      def next_original_commit_to_process!
        queue_having_oldest_next_commit =
          unprocessed_original_commit_queues.sort_by { |queue |queue.first.commit_time }.first

        queue_having_oldest_next_commit&.shift
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
          branch_name: original_commit.mainline? ? branch_name : nil
        )

        commit_map.register(
          commit_id_in_merged_repo: new_commit_in_merged_repo.id,
          original_commit: original_commit
        )
      end

      def current_branch_head_id_in_merged_repo
        branch = merged_repo.branches[branch_name]
        return nil unless branch
        branch.target_commit.id
      end

      def unprocessed_original_commit_queues
        @unprocessed_original_commit_queues ||= original_branches.map do |branch|
          branch.topologically_ordered_commits_from_root.dup
        end
      end

      def original_branches
        original_repos.map { |repo| repo.branches[branch_name] }
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
    end
  end
end
