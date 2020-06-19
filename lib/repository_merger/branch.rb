# frozen_string_literal: true

require_relative 'commit'

require 'rugged'
require 'set'

class RepositoryMerger
  Branch = Struct.new(:rugged_branch, :repo) do
    def ==(other)
      repo == other.repo && canonical_name == other.canonical_name
    end

    alias eql? ==

    def hash
      repo.hash ^ name.hash
    end

    def name
      rugged_branch.name
    end

    def canonical_name
      rugged_branch.canonical_name
    end

    def local_name
      if rugged_branch.remote_name
        name.delete_prefix("#{rugged_branch.remote_name}/")
      else
        name
      end
    end

    def target_commit
      @target_commit ||= begin
        rugged_commit = rugged_repo.lookup(rugged_branch.target_id)
        Commit.new(rugged_commit, repo)
      end
    end

    def topologically_ordered_commits_from_root
      @topologically_ordered_commits_from_root ||= begin
        walker = Rugged::Walker.new(rugged_repo)
        walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_REVERSE)
        walker.push(rugged_branch.target_id)
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

    def rugged_repo
      repo.rugged_repo
    end

    def revision_id
      name
    end
  end
end
