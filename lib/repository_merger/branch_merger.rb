# frozen_string_literal: true

require_relative 'branch_local_commit_map'
require_relative 'commit'

class RepositoryMerger
  class BranchMerger
    attr_reader :configuration, :original_branch_name, :commit_message_transformer, :progress_title
    attr_accessor :wants_to_abort

    def initialize(configuration:, branch_name:, commit_message_transformer: nil, progress_title: nil)
      @configuration = configuration
      @original_branch_name = branch_name
      @commit_message_transformer = commit_message_transformer
      @progress_title = progress_title
    end

    def run
      logger.verbose("Importing Commits for #{monorepo_original_branch_name}", title: true)
      logger.start_tracking_progress_for('commits', total: unprocessed_original_commit_queue.size, title: progress_title)

      while (original_commit = unprocessed_original_commit_queue.next)
        process_commit(original_commit)
        break if wants_to_abort
      end
    ensure
      if monorepo_branch_head_commit
        monorepo.create_or_update_branch(monorepo_original_branch_name, commit_id: monorepo_branch_head_commit.id)
      end

      repo_commit_map.merge!(branch_local_commit_map)
    end

    private

    attr_reader :monorepo_branch_head_commit

    def process_commit(original_commit)
      logger.verbose "  #{original_commit.commit_time} [#{original_commit.repo.name}] #{original_commit.message.each_line.first}"

      if (monorepo_commit = already_imported_monorepo_commit_for(original_commit))
        logger.verbose "    Already imported as #{monorepo_commit.abbreviated_id}. Skipping."
      else
        monorepo_commit = import_commit_into_monorepo(original_commit)
      end

      branch_local_commit_map.register(
        monorepo_commit_id: monorepo_commit.id,
        original_commit: original_commit
      )

      if mainline?(original_commit)
        @monorepo_branch_head_commit = monorepo_commit
      end

      logger.increment_progress
    end

    def already_imported_monorepo_commit_for(original_commit)
      monorepo_commits = repo_commit_map.monorepo_commits_for(original_commit)

      monorepo_commits.find do |monorepo_commit|
        monorepo_commit.parents == parent_commits_in_monorepo_for(original_commit)
      end
    end

    def import_commit_into_monorepo(original_commit)
      parent_commits_in_monorepo = parent_commits_in_monorepo_for(original_commit)

      new_commit_in_monorepo = monorepo.import_commit(
        original_commit,
        new_parents: parent_commits_in_monorepo,
        subdirectory: original_commit.repo.name,
        message: commit_message_from(original_commit)
      )

      logger.verbose "    Created commit #{new_commit_in_monorepo.abbreviated_id}."

      new_commit_in_monorepo
    end

    def parent_commits_in_monorepo_for(original_commit)
      if original_commit.root?
        return [monorepo_branch_head_commit].compact
      end

      original_commit.parents.map do |original_parent_commit|
        if mainline?(original_commit) && mainline?(original_parent_commit)
          monorepo_branch_head_commit
        else
          branch_local_commit_map.monorepo_commit_for(original_parent_commit)
        end
      end
    end

    def mainline?(original_commit)
      original_branch = original_branches_by_repo[original_commit.repo]
      original_branch.mainline?(original_commit)
    end

    def commit_message_from(original_commit)
      if commit_message_transformer
        commit_message_transformer.call(original_commit)
      else
        original_commit.message
      end
    end

    def monorepo_original_branch_name
      @monorepo_original_branch_name ||= original_branches.first.local_name
    end

    def unprocessed_original_commit_queue
      @unprocessed_original_commit_queue ||= OriginalCommitQueue.new(
        repos: original_repos,
        original_branch_name: original_branch_name
      )
    end

    def original_branches_by_repo
      @original_branches_by_repo ||= original_branches.each_with_object({}) do |original_branch, hash|
        hash[original_branch.repo] = original_branch
      end
    end

    def original_branches
      original_repos.map { |repo| repo.branch(original_branch_name) }.compact
    end

    def original_repos
      configuration.original_repos
    end

    def monorepo
      configuration.monorepo
    end

    def repo_commit_map
      configuration.repo_commit_map
    end

    def branch_local_commit_map
      @branch_local_commit_map ||= BranchLocalCommitMap.new(monorepo: monorepo)
    end

    def logger
      configuration.logger
    end

    class OriginalCommitQueue
      attr_reader :repos, :original_branch_name

      def initialize(repos:, original_branch_name:)
        @repos = repos
        @original_branch_name = original_branch_name
      end

      def next
        queue_having_earliest_commit = commit_queues.reject(&:empty?).min_by { |queue| queue.first.commit_time }
        queue_having_earliest_commit&.shift
      end

      def size
        commit_queues.sum(&:size)
      end

      def commit_queues
        @commit_queues ||= target_branches.map(&:topologically_ordered_commits_from_root).map(&:dup)
      end

      def target_branches
        repos.map { |repo| repo.branch(original_branch_name) }.compact
      end
    end
  end
end
