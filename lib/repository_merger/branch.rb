# frozen_string_literal: true

require_relative 'branch_commit'

require 'rugged'
require 'set'

class RepositoryMerger
  Branch = Struct.new(:rugged_branch, :repo) do
    def name
      rugged_branch.name
    end

    def remote?
      rugged_branch.upstream.nil?
    end

    def target_commit
      @target_commit ||= begin
        rugged_commit = rugged_repo.lookup(rugged_branch.target_id)
        BranchCommit.new(rugged_commit, self)
      end
    end

    def topologically_ordered_commits_from_root
      @topologically_ordered_commits_from_root ||= begin
        walker = Rugged::Walker.new(rugged_repo)
        walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_REVERSE)
        walker.push(rugged_branch.target_id)
        walker.map { |rugged_commit| BranchCommit.new(rugged_commit, self) }.freeze
      end
    end

    def mainline?(commit)
      mainline_commit_ids.include?(commit.id)
    end

    def mainline_commit_ids
      @mainline_commit_ids ||= Set.new.tap do |mainline_commit_ids|
        commit = target_commit

        while commit
          mainline_commit_ids << commit.id
          commit = commit.parents.first
        end
      end.freeze
    end

    def rugged_repo
      repo.rugged_repo
    end
  end
end
