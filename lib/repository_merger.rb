# frozen_string_literal: true

require_relative 'repository_merger/commit_history_merger'
require_relative 'repository_merger/configuration'
require_relative 'repository_merger/tag_importer'

class RepositoryMerger
  attr_reader :configuration

  def initialize(configuration)
    @configuration = configuration
  end

  def merge_commit_history_of_branches_named(original_branch_name, commit_message_transformer: nil, progress_title: nil)
    original_branches = configuration.original_repos.map { |repo| repo.branch(original_branch_name) }.compact

    commit_history_merger = CommitHistoryMerger.new(
      configuration: configuration,
      references: original_branches,
      commit_message_transformer: commit_message_transformer,
      progress_title: progress_title
    )

    monorepo_head_commit = commit_history_merger.run

    if monorepo_head_commit
      monorepo_branch_name = original_branches.first.local_name
      configuration.monorepo.create_or_update_branch(monorepo_branch_name, commit_id: monorepo_head_commit.id)
    end
  end

  def import_tags(tag_name_transformer:)
    tag_importer = TagImporter.new(configuration: configuration, tag_name_transformer: tag_name_transformer)
    tag_importer.run
  end
end
