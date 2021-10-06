# frozen_string_literal: true

require_relative 'commit_map'

class RepositoryMerger
  class BranchLocalCommitMap
    include CommitMap

    attr_reader :monorepo

    def initialize(monorepo:)
      @monorepo = monorepo
    end

    def map
      @map ||= {}
    end

    def register(monorepo_commit:, original_commit:)
      key = original_commit_key(original_commit)
      raise if map.key?(key)
      map[key] = monorepo_commit.id
    end

    def monorepo_commit_for(original_commit)
      monorepo_commit_id = monorepo_commit_id_for(original_commit)
      monorepo.commit_for(monorepo_commit_id)
    end

    def monorepo_commit_id_for(original_commit)
      map[original_commit_key(original_commit)]
    end
  end
end
