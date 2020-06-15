# frozen_string_literal: true

module RSpec
  class RepositoryMerger
    class CommitMap
      def register(commit_id_in_merged_repo:, original_commit:)
        map[original_commit_key(original_commit)] = commit_id_in_merged_repo
      end

      def commit_id_in_merged_repo_for(original_commit)
        map[original_commit_key(original_commit)]
      end

      def map
        @map ||= {}
      end

      def original_commit_key(commit)
        "#{commit.repo.name}-#{commit.id}"
      end
    end
  end
end
