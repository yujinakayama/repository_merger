# frozen_string_literal: true

require_relative 'repository_merger/branch_merger'
require_relative 'repository_merger/commit_map'
require_relative 'repository_merger/mono_repository'
require_relative 'repository_merger/repository'
require_relative 'repository_merger/tag_importer'

class RepositoryMerger
  attr_reader :original_repo_paths, :monorepo_path, :commit_map_file_path, :log_output

  def initialize(original_repo_paths, monorepo_path:, commit_map_file_path: 'commit_map.json', log_output: $stdout)
    @original_repo_paths = original_repo_paths
    @monorepo_path = monorepo_path
    @commit_map_file_path = commit_map_file_path
    @log_output = log_output
  end

  def merge_branches(branch_names, commit_message_transformer: nil)
    branch_names.each_with_index do |target_branch_name, index|
      branch_merger = BranchMerger.new(
        self,
        target_branch_name: target_branch_name,
        all_branch_names: branch_names,
        commit_message_transformer: commit_message_transformer,
        progressbar_title: "#{index + 1}/#{branch_names.size} branches: #{target_branch_name}"
      )

      branch_merger.run
    end
  end

  def import_tags(tag_name_transformer:)
    tag_importer = TagImporter.new(self, tag_name_transformer)
    tag_importer.run
  end

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
