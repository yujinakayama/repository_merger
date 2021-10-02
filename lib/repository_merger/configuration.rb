# frozen_string_literal: true

require_relative 'mono_repository'
require_relative 'repository'
require_relative 'repository_commit_map'

class RepositoryMerger
  class Configuration
    attr_reader :original_repo_paths, :monorepo_path, :commit_map_file_path, :log_output

    def initialize(original_repo_paths:, monorepo_path:, commit_map_file_path: 'commit_map.json', log_output: $stdout)
      @original_repo_paths = original_repo_paths
      @monorepo_path = monorepo_path
      @commit_map_file_path = commit_map_file_path
      @log_output = log_output
    end

    def original_repos
      @original_repos ||= original_repo_paths.map { |path| Repository.new(path) }
    end

    def monorepo
      @monorepo ||= MonoRepository.new(monorepo_path)
    end

    def repo_commit_map
      @commit_map ||= RepositoryCommitMap.new(path: commit_map_file_path, monorepo: monorepo)
    end
  end
end
