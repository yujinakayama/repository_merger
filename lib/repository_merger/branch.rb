# frozen_string_literal: true

require_relative 'reference'

require 'rugged'
require 'set'

class RepositoryMerger
  Branch = Struct.new(:rugged_branch, :repo) do
    include Reference

    def ==(other)
      repo == other.repo && canonical_name == other.canonical_name
    end

    alias_method :eql?, :==

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
      repo.commit_for(rugged_branch.target_id)
    end

    def revision_id
      name
    end
  end
end
