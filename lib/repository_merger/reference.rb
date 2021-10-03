# frozen_string_literal: true

require_relative 'commit'

require 'rugged'
require 'set'

class RepositoryMerger
  module Reference
    def target_commit
      raise NotImplementedError
    end

    def topologically_ordered_commits_from_root
      @topologically_ordered_commits_from_root ||= begin
        walker = Rugged::Walker.new(repo.rugged_repo)
        walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_REVERSE)
        walker.push(target_commit.id)
        walker.map { |rugged_commit| Commit.new(rugged_commit, repo) }.freeze
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
  end
end
