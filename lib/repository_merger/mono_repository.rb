# frozen_string_literal: true
require_relative 'repository'
require 'rugged'

class RepositoryMerger
  class MonoRepository < Repository
    def import_commit(original_commit, new_parent_ids:, subdirectory:, message: nil, branch_name: nil)
      stage_contents_of(original_commit, subdirectory: subdirectory)

      create_commit_with_metadata_of(
        original_commit,
        new_parent_ids: new_parent_ids,
        message: message,
        branch_name: branch_name
      )
    end

    def import_tag(original_tag, new_commit_id:, new_tag_name:)
      # This is to suppress warning messages
      # `warning: Using the last argument as keyword parameters is deprecated`
      # from rugged gem until a fixed version is released.
      # https://github.com/libgit2/rugged/pull/840
      if original_tag.annotation
        rugged_repo.tags.create(new_tag_name, new_commit_id, **original_tag.annotation)
      else
        rugged_repo.tags.create(new_tag_name, new_commit_id)
      end

      tag(new_tag_name)
    end

    def create_or_update_branch(branch_name, commit_id:)
      if branch(branch_name)
        # `rugged_repo.branches.create` with master branch fails with error:
        # cannot force update branch 'master' as it is the current HEAD of the repository. (Rugged::ReferenceError)
        rugged_repo.references.update("refs/heads/#{branch_name}", commit_id)
      else
        rugged_repo.branches.create(branch_name, commit_id)
      end
    end

    private

    def stage_contents_of(original_commit, subdirectory:)
      original_commit.checkout_contents_into(File.join(path, subdirectory))
      rugged_repo.index.add_all
    end

    def create_commit_with_metadata_of(original_commit, new_parent_ids:, message:, branch_name:)
      original_rugged_commit = original_commit.rugged_commit

      new_commit_id = Rugged::Commit.create(rugged_repo, {
        message: message || original_rugged_commit.message,
        committer: original_rugged_commit.committer,
        author: original_rugged_commit.author,
        tree: rugged_repo.index.write_tree,
        parents: new_parent_ids,
      })

      if branch_name
        create_or_update_branch(branch_name, commit_id: new_commit_id)
      end

      lookup(new_commit_id)
    end
  end
end
