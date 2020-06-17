# frozen_string_literal: true

require_relative 'repository_merger/branch_merger'
require_relative 'repository_merger/commit_map'
require_relative 'repository_merger/merged_repository'
require_relative 'repository_merger/repository'
require_relative 'repository_merger/tag_importer'

class RepositoryMerger
  attr_reader :original_repo_paths, :merged_repo_path, :commit_map_file_path

  def initialize(original_repo_paths, merged_repo_path:, commit_map_file_path: 'commit_map.json')
    @original_repo_paths = original_repo_paths
    @merged_repo_path = merged_repo_path
    @commit_map_file_path = commit_map_file_path
  end

  def merge_branches(branch_name, commit_message_transformer: nil)
    branch_merger = BranchMerger.new(self, branch_name: branch_name, commit_message_transformer: commit_message_transformer)
    branch_merger.run
  end

  def import_tags(tag_name_transformer:)
    tag_importer = TagImporter.new(self, tag_name_transformer)
    tag_importer.run
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
        if commit_map_file_path && File.exist?(commit_map_file_path)
          CommitMap.load_from(commit_map_file_path)
        else
          CommitMap.new
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
