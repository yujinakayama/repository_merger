# frozen_string_literal: true

require_relative 'repository_merger/branch_merger'
require_relative 'repository_merger/configuration'
require_relative 'repository_merger/tag_importer'

class RepositoryMerger
  attr_reader :configuration

  def initialize(configuration)
    @configuration = configuration
  end

  def merge_branches(branch_name, commit_message_transformer: nil, progress_title: nil)
    branch_merger = BranchMerger.new(
      configuration: configuration,
      branch_name: branch_name,
      commit_message_transformer: commit_message_transformer,
      progress_title: progress_title
    )

    branch_merger.run
  ensure
    configuration.repo_commit_map.save if configuration.repo_commit_map.path
  end

  def import_tags(tag_name_transformer:)
    tag_importer = TagImporter.new(configuration: configuration, tag_name_transformer: tag_name_transformer)
    tag_importer.run
  end
end
