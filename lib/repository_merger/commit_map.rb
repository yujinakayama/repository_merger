# frozen_string_literal: true

class RepositoryMerger
  module CommitMap
    def original_commit_key(commit)
      "#{commit.id}@#{commit.repo.name}"
    end
  end
end
