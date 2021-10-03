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

    def abbreviated_id
      id[0, 7]
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

    def parents
      @parents ||= rugged_commit.parents.map do |parent_rugged_commit|
        create_parent(parent_rugged_commit)
      end
    end

    def files
      @files ||= begin
        blob_entries = rugged_commit.tree.walk(:postorder).select { |_, entry| entry[:type] == :blob }
        blob_entries.map { |directory, entry| "#{directory}#{entry[:name]}" }
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
        strategy: [:dont_update_index, :force, :remove_ignored, :remove_untracked],
        target_directory: directory_path
      )
    end

    def revision_id
      id
    end

    def inspect
      "#<#{self.class} id=#{abbreviated_id} repo=#{repo.name} message=#{message.each_line.first.chomp.inspect}>"
    end

    def pretty_print(pp)
      pp.text(inspect)
    end

    private

    def create_parent(parent_rugged_commit)
      self.class.new(parent_rugged_commit, repo)
    end
  end
end
