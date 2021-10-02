# frozen_string_literal: true

require_relative 'repository_merger/branch_merger'
require_relative 'repository_merger/configuration'
require_relative 'repository_merger/tag_importer'

class RepositoryMerger
  attr_reader :configuration

  def initialize(configuration)
    @configuration = configuration
  end

  def merge_branches(branch_names, commit_message_transformer: nil)
    branch_names.each_with_index do |target_branch_name, index|
      branch_merger = BranchMerger.new(
        configuration: configuration,
        target_branch_name: target_branch_name,
        commit_message_transformer: commit_message_transformer,
        progressbar_title: "#{index + 1}/#{branch_names.size} branches: #{target_branch_name}"
      )

      branch_merger.run
    end
  ensure
    configuration.repo_commit_map.save if configuration.repo_commit_map.path
  end

  def import_tags(tag_name_transformer:)
    tag_importer = TagImporter.new(configuration: configuration, tag_name_transformer: tag_name_transformer)
    tag_importer.run
  end
end
