# frozen_string_literal: true

module RSpec
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

      def merge_commit?
        parents.size > 1
      end

      def parents
        @parents ||= rugged_commit.parents.map do |parent_rugged_commit|
          create_parent(parent_rugged_commit)
        end
      end

      private

      def create_parent(parent_rugged_commit)
        self.class.new(parent_rugged_commit, repo)
      end
    end
  end
end
