# frozen_string_literal: true

require 'ruby-progressbar'
require_relative 'commit'

class RepositoryMerger
  class BranchMerger
    attr_reader :configuration, :target_branch_name, :all_branch_names, :commit_message_transformer, :progressbar

    def initialize(configuration:, target_branch_name:, all_branch_names:, commit_message_transformer: nil, progressbar_title: nil)
      @configuration = configuration
      @target_branch_name = target_branch_name
      @all_branch_names = all_branch_names
      @commit_message_transformer = commit_message_transformer
      @progressbar = create_progressbar(progressbar_title)
    end

    def run
      progressbar.log "Merging `#{target_branch_name}` branches of #{original_branches.map { |original_branch| original_branch.repo.name }.join(', ')} into `#{branch_name_in_monorepo}` branch of #{monorepo.path}..."

      if original_branches_are_already_imported?
        progressbar.log "  The branches are already imported."
        return
      end

      while (original_commit = unprocessed_original_commit_queue.next)
        process_commit(original_commit)
      end
    end

    def original_branches_are_already_imported?
      return false unless branch_in_monorepo

      possible_branch_head_id_sets = original_branches.map do |original_branch|
        commit_map.monorepo_commit_ids_for(original_branch.target_commit)
      end

      return false if possible_branch_head_id_sets.any?(&:empty?)

      possible_branch_head_id_sets.flatten.include?(branch_in_monorepo.target_commit.id)
    end

    def process_commit(original_commit)
      progressbar.log "  #{original_commit.commit_time} [#{original_commit.repo.name}] #{original_commit.message.each_line.first}"

      if commit_map.monorepo_commit_ids_for(original_commit).first
        progressbar.log "    Already imported."
      else
        import_commit_into_monorepo(original_commit)
      end

      update_branch_in_monorepo_if_needed(original_commit)

      progressbar.increment
    end

    def update_branch_in_monorepo_if_needed(original_commit)
      return unless mainline?(original_commit)

      monorepo_commit_id = commit_map.monorepo_commit_ids_for(original_commit).first
      monorepo.create_or_update_branch(branch_name_in_monorepo, commit_id: monorepo_commit_id)
    end

    def import_commit_into_monorepo(original_commit)
      parent_commits_in_monorepo =
        if original_commit.root?
          [branch_in_monorepo&.target_commit].compact
        else
          original_commit.parents.map do |original_parent_commit|
            if mainline?(original_commit) && mainline?(original_parent_commit)
              branch_in_monorepo.target_commit
            else
              commit_map.monorepo_commits_for(original_parent_commit).first
            end
          end
        end

      new_commit_in_monorepo = monorepo.import_commit(
        original_commit,
        new_parents: parent_commits_in_monorepo,
        subdirectory: original_commit.repo.name,
        message: commit_message_from(original_commit)
      )

      commit_map.register(
        monorepo_commit_id: new_commit_in_monorepo.id,
        original_commit: original_commit
      )
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
        all_branch_names: all_branch_names
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

    def commit_map
      configuration.commit_map
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
      attr_reader :repos, :target_branch_name, :all_branch_names

      def initialize(repos:, target_branch_name:, all_branch_names:)
        @repos = repos
        @target_branch_name = target_branch_name
        @all_branch_names = all_branch_names
      end

      def next
        queue_having_highest_priority_commit = commit_queues.reject(&:empty?).max_by { |queue| queue.first }
        queue_having_highest_priority_commit&.shift&.commit
      end

      def size
        commit_queues.sum(&:size)
      end

      def commit_queues
        @commit_queues ||= target_branches.map do |branch|
          branch.topologically_ordered_commits_from_root.map do |commit|
            CommitPriority.new(commit, commit_to_branches_map)
          end
        end
      end

      def target_branches
        repos.map { |repo| repo.branch(target_branch_name) }.compact
      end

      def commit_to_branches_map
        @commit_to_branches_map ||= repos.each_with_object({}) do |repo, commit_to_branches_map|
          commit_to_branches_map.merge!(commit_to_branches_map_in(repo))
        end.freeze
      end

      def commit_to_branches_map_in(repo)
        all_branches_in_repo = repo.branches.select { |branch| all_branch_names.include?(branch.name) }

        all_branches_in_repo.each_with_object({}) do |branch, commit_to_branches_map|
          branch.topologically_ordered_commits_from_root.each do |commit|
            commit_to_branches_map[commit] ||= Set.new
            commit_to_branches_map[commit] << branch
          end
        end
      end

      CommitPriority = Struct.new(:commit, :commit_to_branches_map) do
        include Comparable

        def <=>(other)
          branch_comparison = compare_branches(other)
          return branch_comparison unless branch_comparison.zero?
          compare_commit_time(other)
        end

        def compare_branches(other)
          valid_branch_names = (branch_names + other.branch_names).select do |branch_name|
            [repo, other.repo].all? { |repo| repo.branch(branch_name) }
          end.to_set

          self_branch_names = branch_names & valid_branch_names
          other_branch_names = other.branch_names & valid_branch_names

          if self_branch_names.proper_superset?(other_branch_names)
            1
          elsif self_branch_names.proper_subset?(other_branch_names)
            -1
          else
            0
          end
        end

        def compare_commit_time(other)
          (commit.commit_time <=> other.commit.commit_time) * -1
        end

        def branch_names
          @branch_names ||= Set.new(branches.map(&:name))
        end

        def branches
          commit_to_branches_map[commit]
        end

        def repo
          commit.repo
        end
      end
    end
  end
end
