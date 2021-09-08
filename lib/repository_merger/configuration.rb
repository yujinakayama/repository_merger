# frozen_string_literal: true

require_relative 'commit_map'
require_relative 'mono_repository'
require_relative 'repository'

class RepositoryMerger
  Configuration = Struct.new(:original_repo_paths, :monorepo_path, :commit_map_file_path, :log_output, keyword_init: true) do
    def original_repos
      @original_repos ||= original_repo_paths.map { |path| Repository.new(path) }
    end

    def monorepo
      @monorepo ||= MonoRepository.new(monorepo_path)
    end

    def commit_map
      @commit_map ||= CommitMap.new(path: commit_map_file_path, monorepo: monorepo)
    end
  end
end
