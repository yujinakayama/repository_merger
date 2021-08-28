# frozen_string_literal: true

require 'json'

class RepositoryMerger
  class CommitMap
    attr_reader :monorepo

    def self.load_from(path, monorepo:)
      json = File.read(path)
      new(JSON.parse(json), monorepo: monorepo)
    end

    def initialize(map = {}, monorepo:)
      @map = map
      @monorepo = monorepo
    end

    def save_to(path)
      json = JSON.pretty_generate(@map)
      File.write(path, json)
    end

    def register(monorepo_commit_id:, original_commit:)
      @map[original_commit_key(original_commit)] = monorepo_commit_id
    end

    def monorepo_commit_for(original_commit)
      commit_id = monorepo_commit_id_for(original_commit)
      return nil unless commit_id
      monorepo.lookup(commit_id)
    end

    def monorepo_commit_id_for(original_commit)
      @map[original_commit_key(original_commit)]
    end

    def original_commit_key(commit)
      "#{commit.repo.name}-#{commit.id}"
    end
  end
end
