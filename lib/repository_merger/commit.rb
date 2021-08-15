# frozen_string_literal: true

class RepositoryMerger
  Commit = Struct.new(:rugged_commit, :repo) do
    def ==(other)
      id == other.id
    end

    alias eql? ==

    def hash
      id.hash
    end

    def id
      rugged_commit.oid
    end

    def message
      rugged_commit.message
    end

    def commit_time
      rugged_commit.committer[:time]
    end

    def root?
      parents.empty?
    end

    def merge_commit?
      parents.size > 1
    end

    def parents
      @parents ||= rugged_commit.parents.map do |parent_rugged_commit|
        create_parent(parent_rugged_commit)
      end
    end

    def checkout_contents
      repo.rugged_repo.checkout_tree(id, strategy: :force)
    end

    def extract_contents_into(directory_path)
      # We need to specify an empty tree as a baseline tree
      # to prevent libgit2 from skipping checkout of some contents
      # by comparing the commit tree with the HEAD tree.
      empty_tree = Rugged::Tree.empty(repo.rugged_repo)

      repo.rugged_repo.checkout_tree(
        id,
        baseline: empty_tree,
        strategy: [:dont_update_index, :force, :remove_untracked],
        target_directory: directory_path
      )
    end

    def revision_id
      id
    end

    private

    def create_parent(parent_rugged_commit)
      self.class.new(parent_rugged_commit, repo)
    end
  end
end
