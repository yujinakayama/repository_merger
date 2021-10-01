# frozen_string_literal: true

require 'ruby-progressbar'
require_relative 'branch_local_commit_map'
require_relative 'commit'

class RepositoryMerger
  class BranchMerger
    attr_reader :configuration, :target_branch_name, :commit_message_transformer, :progressbar
    attr_accessor :wants_to_abort

    def initialize(configuration:, target_branch_name:, commit_message_transformer: nil, progressbar_title: nil)
      @configuration = configuration
      @target_branch_name = target_branch_name
      @commit_message_transformer = commit_message_transformer
      @progressbar = create_progressbar(progressbar_title)
    end

    def run
      progressbar.log "Merging `#{target_branch_name}` branches of #{original_branches.map { |original_branch| original_branch.repo.name }.join(', ')} into `#{branch_name_in_monorepo}` branch of #{monorepo.path}..."

      while (original_commit = unprocessed_original_commit_queue.next)
        process_commit(original_commit)
        break if wants_to_abort
      end
    ensure
      if monorepo_branch_head_commit
        monorepo.create_or_update_branch(branch_name_in_monorepo, commit_id: monorepo_branch_head_commit.id)
      end

      repo_commit_map.merge!(branch_local_commit_map)
    end

    private

    attr_reader :monorepo_branch_head_commit

    def process_commit(original_commit)
      progressbar.log "  #{original_commit.commit_time} [#{original_commit.repo.name}] #{original_commit.message.each_line.first}"

      if (monorepo_commit = already_imported_monorepo_commit_for(original_commit))
        progressbar.log "    Already imported. #{monorepo_commit.id[0,7]}"
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

      progressbar.increment
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

      progressbar.log("    Created commit #{new_commit_in_monorepo.id[0,7]}, parents: #{parent_commits_in_monorepo.map { |commit| commit.id[0,7] }}, mainline: #{mainline?(original_commit)}")

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

    def branch_in_monorepo
      monorepo.branch(branch_name_in_monorepo)
    end

    def branch_name_in_monorepo
      @branch_name_in_monorepo ||= original_branches.first.local_name
    end

    def unprocessed_original_commit_queue
      @unprocessed_original_commit_queue ||= OriginalCommitQueue.new(
        repos: original_repos,
        target_branch_name: target_branch_name,
      )
    end

    def original_branches_by_repo
      @original_branches_by_repo ||= original_branches.each_with_object({}) do |original_branch, hash|
        hash[original_branch.repo] = original_branch
      end
    end

    def original_branches
      original_repos.map { |repo| repo.branch(target_branch_name) }.compact
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

    def create_progressbar(title)
      # 185/407 commits |====== 45 ======>                    |  ETA: 00:00:04
      # %c / %C         |       %w       >         %i         |       %e
      bar_format = " %t %c/%C commits |%w>%i| %e "

      ProgressBar.create(
        format: bar_format,
        output: configuration.log_output,
        title: title,
        total: unprocessed_original_commit_queue.size
      )
    end

    class OriginalCommitQueue
      attr_reader :repos, :target_branch_name

      def initialize(repos:, target_branch_name:)
        @repos = repos
        @target_branch_name = target_branch_name
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
        repos.map { |repo| repo.branch(target_branch_name) }.compact
      end
    end
  end
end
