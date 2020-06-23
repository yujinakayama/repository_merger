# frozen_string_literal: true

require 'json'

class RepositoryMerger
  class CommitMap
    def self.load_from(path)
      json = File.read(path)
      new(JSON.parse(json))
    end

    def initialize(map = {})
      @map = map
    end

    def save_to(path)
      json = JSON.pretty_generate(@map)
      File.write(path, json)
    end

    def register(monorepo_commit_id:, original_commit:)
      @map[original_commit_key(original_commit)] = monorepo_commit_id
    end

    def monorepo_commit_id_for(original_commit)
      @map[original_commit_key(original_commit)]
    end

    def original_commit_key(commit)
      "#{commit.repo.name}-#{commit.id}"
    end
  end
end
