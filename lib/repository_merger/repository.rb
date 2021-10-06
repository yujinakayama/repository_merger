# frozen_string_literal: true

require_relative 'branch'
require_relative 'commit'
require_relative 'tag'

require 'rugged'

class RepositoryMerger
  class Repository
    attr_reader :path

    def initialize(path)
      @path = File.expand_path(path)
    end

    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(path)
    end

    def ==(other)
      path == other.path
    end

    alias eql? ==

    def hash
      path.hash
    end

    def name
      File.basename(path)
    end

    def branch_for(name)
      rugged_branch = rugged_repo.branches[name]
      return nil unless rugged_branch
      Branch.new(rugged_branch, self)
    end

    def branches
      rugged_repo.branches.map do |rugged_branch|
        Branch.new(rugged_branch, self)
      end
    end

    def tag_for(name)
      rugged_tag = rugged_repo.tags[name]
      return nil unless rugged_tag
      Tag.new(rugged_tag, self)
    end

    def tags
      rugged_repo.tags.map do |rugged_tag|
        Tag.new(rugged_tag, self)
      end
    end

    def commit_for(commit_id)
      object = rugged_repo.lookup(commit_id)
      return nil unless object.is_a?(Rugged::Commit)
      Commit.new(object, self)
    end
  end
end
