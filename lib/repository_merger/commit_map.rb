# frozen_string_literal: true

class RepositoryMerger
  module CommitMap
    def original_commit_key(commit)
      "#{commit.repo.name}-#{commit.id}"
    end
  end
end
