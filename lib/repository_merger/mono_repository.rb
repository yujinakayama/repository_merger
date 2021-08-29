# frozen_string_literal: true
require_relative 'repository'
require 'rugged'

class RepositoryMerger
  class MonoRepository < Repository
    def initialize(_path)
      super
      configure
    end

    def import_commit(original_commit, new_parents:, subdirectory:, message: nil)
      checkout_contents_if_needed(new_parents.first) unless new_parents.empty?

      stage_contents_of(original_commit, subdirectory: subdirectory)

      create_commit_with_metadata_of(
        original_commit,
        new_parent_ids: new_parents.map(&:id),
        message: message
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

    def configure
      rugged_repo.config['core.ignorecase'] = false
    end

    attr_accessor :current_checked_out_commit_id

    def checkout_contents_if_needed(commit)
      return if commit.id == current_checked_out_commit_id
      commit.checkout_contents
      @current_checked_out_commit_id = commit.id
    end

    def stage_contents_of(original_commit, subdirectory:)
      original_commit.extract_contents_into(File.join(path, subdirectory))

      # First, track (almost) all files (including removed files) with .gitignore rules
      rugged_repo.index.add_all(subdirectory)

      # Then specify all the file paths explicily to track files
      # that matches .gitignore but is tracked in the original commit.
      # We cannot use Rugged::Index#add_all with :force option
      # since it has a bug where it raises strange error when adding files in a ignored directory.
      # https://github.com/libgit2/libgit2/issues/4377
      original_commit.files.each do |original_file_path|
        monorepo_file_path = File.join(subdirectory, original_file_path)
        rugged_repo.index.add(monorepo_file_path)
      end

      rugged_repo.index.write
    end

    def create_commit_with_metadata_of(original_commit, new_parent_ids:, message:)
      original_rugged_commit = original_commit.rugged_commit

      new_commit_id = Rugged::Commit.create(rugged_repo, {
        message: message || original_rugged_commit.message,
        committer: original_rugged_commit.committer,
        author: original_rugged_commit.author,
        tree: rugged_repo.index.write_tree,
        parents: new_parent_ids,
      })

      @current_checked_out_commit_id = new_commit_id

      lookup(new_commit_id)
    end
  end
end
