# frozen_string_literal: true

require_relative 'repository_merger/commit_history_merger'
require_relative 'repository_merger/configuration'
require_relative 'repository_merger/tag_importer'

class RepositoryMerger
  attr_reader :configuration

  def initialize(configuration)
    @configuration = configuration
  end

  def merge_commit_history_of_branches_named(original_branch_name, commit_message_conversion: nil, progress_title: nil)
    original_branches = configuration.original_repos.map { |repo| repo.branch(original_branch_name) }.compact

    monorepo_head_commit = merge_commit_history_of(
      original_branches,
      commit_message_conversion: commit_message_conversion,
      progress_title: progress_title
    )

    monorepo_branch_name = original_branches.first.local_name
    configuration.monorepo.create_or_update_branch(monorepo_branch_name, commit_id: monorepo_head_commit.id)
  end

  def merge_commit_history_of(references, commit_message_conversion: nil, progress_title: nil)
    commit_history_merger = CommitHistoryMerger.new(
      configuration: configuration,
      references: references,
      commit_message_conversion: commit_message_conversion,
      progress_title: progress_title
    )

    commit_history_merger.run
  end

  def import_all_tags(tag_name_conversion:)
    all_tags = configuration.original_repos.flat_map(&:tags)
    import_tags(all_tags, tag_name_conversion: tag_name_conversion)
  end

  def import_tags(tags, tag_name_conversion:)
    tag_importer = TagImporter.new(tags, configuration: configuration, tag_name_conversion: tag_name_conversion)
    tag_importer.run
  end
end
