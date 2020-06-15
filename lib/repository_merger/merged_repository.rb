# frozen_string_literal: true
require_relative 'repository'
require 'rugged'

class RepositoryMerger
  class MergedRepository < Repository
    def import_commit(original_commit, new_parent_ids:, subdirectory:, message: nil, branch_name: nil)
      stage_contents_of(original_commit, subdirectory: subdirectory)

      create_commit_with_metadata_of(
        original_commit,
        new_parent_ids: new_parent_ids,
        message: message,
        branch_name: branch_name
      )
    end

    private

    def stage_contents_of(original_commit, subdirectory:)
      original_commit.checkout_contents_into(File.join(path, subdirectory))
      rugged_repo.index.add_all
    end

    def create_commit_with_metadata_of(original_commit, new_parent_ids:, message:, branch_name:)
      original_rugged_commit = original_commit.rugged_commit

      branch_exists = branches[branch_name]

      new_commit_id = Rugged::Commit.create(rugged_repo, {
        message: message || original_rugged_commit.message,
        committer: original_rugged_commit.committer,
        author: original_rugged_commit.author,
        tree: rugged_repo.index.write_tree,
        update_ref: branch_exists ? "refs/heads/#{branch_name}" : nil,
        parents: new_parent_ids,
      })

      if branch_name && !branch_exists
        rugged_repo.branches.create(branch_name, new_commit_id)
      end

      lookup(new_commit_id)
    end
  end
end
