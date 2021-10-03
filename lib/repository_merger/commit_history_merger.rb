# frozen_string_literal: true

require_relative 'branch_local_commit_map'
require_relative 'commit'

class RepositoryMerger
  class CommitHistoryMerger
    attr_reader :configuration, :original_references, :commit_message_conversion, :progress_title
    attr_accessor :wants_to_abort

    def initialize(references, configuration:, commit_message_conversion: nil, progress_title: nil)
      @original_references = references
      @configuration = configuration
      @commit_message_conversion = commit_message_conversion
      @progress_title = progress_title
    end

    def run
      logger.start_tracking_progress_for('commits', total: unprocessed_original_commit_queue.size, title: progress_title)

      while (original_commit = unprocessed_original_commit_queue.next)
        process_commit(original_commit)
        break if wants_to_abort
      end

      monorepo_head_commit
    ensure
      repo_commit_map.merge!(branch_local_commit_map)
      repo_commit_map.save if repo_commit_map.path
    end

    private

    attr_reader :monorepo_head_commit

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
        @monorepo_head_commit = monorepo_commit
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
        return [monorepo_head_commit].compact
      end

      original_commit.parents.map do |original_parent_commit|
        if mainline?(original_commit) && mainline?(original_parent_commit)
          monorepo_head_commit
        else
          branch_local_commit_map.monorepo_commit_for(original_parent_commit)
        end
      end
    end

    def mainline?(original_commit)
      original_reference = original_references_by_repo[original_commit.repo]
      original_reference.mainline?(original_commit)
    end

    def commit_message_from(original_commit)
      if commit_message_conversion
        commit_message_conversion.call(original_commit)
      else
        original_commit.message
      end
    end

    def unprocessed_original_commit_queue
      @unprocessed_original_commit_queue ||= OriginalCommitQueue.new(original_references)
    end

    def original_references_by_repo
      @original_references_by_repo ||= original_references.each_with_object({}) do |original_reference, hash|
        hash[original_reference.repo] = original_reference
      end
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
      attr_reader :references

      def initialize(references)
        @references = references
      end

      def next
        queue_having_earliest_commit = commit_queues.reject(&:empty?).min_by { |queue| queue.first.commit_time }
        queue_having_earliest_commit&.shift
      end

      def size
        commit_queues.sum(&:size)
      end

      def commit_queues
        @commit_queues ||= references.map(&:topologically_ordered_commits_from_root).map(&:dup)
      end
    end
  end
end
