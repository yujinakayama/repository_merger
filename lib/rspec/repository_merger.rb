# frozen_string_literal: true

require_relative 'repository_merger/repository'

module RSpec
  class RepositoryMerger
    attr_reader :repo_paths

    def initialize(repo_paths)
      @repo_paths = repo_paths
    end

    def repos
      @repos ||= repo_paths.map { |path| Repository.new(path) }
    end
  end
end
