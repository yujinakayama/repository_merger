# frozen_string_literal: true

require_relative 'commit'

class RepositoryMerger
  class BranchCommit < Commit
    attr_reader :branch

    def initialize(rugged_commit, branch)
      super(rugged_commit, branch.repo)
      @branch = branch
    end

    def mainline?
      branch.mainline?(self)
    end

    private

    def create_parent(rugged_commit)
      self.class.new(rugged_commit, branch)
    end
  end
end
