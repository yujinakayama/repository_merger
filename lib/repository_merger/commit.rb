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

    def checkout_contents_into(directory_path)
      repo.rugged_repo.checkout_tree(id, strategy: :force, target_directory: directory_path)
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
