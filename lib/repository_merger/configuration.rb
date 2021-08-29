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
      @commit_map ||= begin
        commit_map =
          if commit_map_file_path && File.exist?(commit_map_file_path)
            CommitMap.load_from(commit_map_file_path, monorepo: monorepo)
          else
            CommitMap.new(monorepo: monorepo)
          end

        if commit_map_file_path
          at_exit do
            commit_map.save_to(commit_map_file_path)
            puts "Saved commit map to #{commit_map_file_path}."
          end
        end

        commit_map
      end
    end
  end
end
