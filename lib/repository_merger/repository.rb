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

    def name
      File.basename(path)
    end

    def branches
      branches = rugged_repo.branches.map do |rugged_branch|
        Branch.new(rugged_branch, self)
      end

      branches.map { |branch| [branch.name, branch] }.to_h
    end

    def tags
      tags = rugged_repo.tags.map do |rugged_tag|
        Tag.new(rugged_tag, self)
      end

      tags.map { |tag| [tag.name, tag] }.to_h
    end

    def lookup(commit_id)
      rugged_commit = rugged_repo.lookup(commit_id)
      Commit.new(rugged_commit, self)
    end
  end
end
