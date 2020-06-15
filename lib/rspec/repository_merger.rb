# frozen_string_literal: true

require_relative 'repository_merger/branch_merger'
require_relative 'repository_merger/commit_map'
require_relative 'repository_merger/merged_repository'
require_relative 'repository_merger/repository'

module RSpec
  class RepositoryMerger
    COMMIT_MAP_PATH = 'commit_map.json'

    attr_reader :original_repo_paths, :merged_repo_path
    attr_accessor :commit_message_transformer

    def initialize(original_repo_paths, merged_repo_path:)
      @original_repo_paths = original_repo_paths
      @merged_repo_path = merged_repo_path
    end

    def merge_branches(branch_name)
      branch_merger = BranchMerger.new(self, branch_name: branch_name)
      branch_merger.run
    end

    def original_repos
      @original_repos ||= original_repo_paths.map { |path| Repository.new(path) }
    end

    def merged_repo
      @merged_repo ||= MergedRepository.new(merged_repo_path)
    end

    def commit_map
      @commit_map ||= begin
        commit_map =
          if File.exist?(COMMIT_MAP_PATH)
            CommitMap.load_from(COMMIT_MAP_PATH)
          else
            CommitMap.new
          end

        at_exit do
          commit_map.save_to(COMMIT_MAP_PATH)
          puts "Saved commit map to #{COMMIT_MAP_PATH}."
        end

        commit_map
      end
    end
  end
end
