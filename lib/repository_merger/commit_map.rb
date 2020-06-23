# frozen_string_literal: true

require 'json'

class RepositoryMerger
  class CommitMap
    CannotSaveWithoutPathError = Class.new(StandardError)

    attr_reader :path, :monorepo

    def initialize(path: nil, monorepo:)
      @path = path
      @monorepo = monorepo
    end

    def map
      @map ||=
        if path && File.exist?(path)
          json = File.read(path)
          JSON.parse(json)
        else
          {}
        end
    end

    def save
      raise CannotSaveWithoutPathError unless path
      json = JSON.pretty_generate(map)
      File.write(path, json)
    end

    def register(monorepo_commit_id:, original_commit:)
      key = original_commit_key(original_commit)
      map[key] ||= []
      map[key] << monorepo_commit_id
    end

    def monorepo_commits_for(original_commit)
      commit_ids = monorepo_commit_ids_for(original_commit)
      commit_ids.map { |id| monorepo.lookup(id) }
    end

    def monorepo_commit_ids_for(original_commit)
      map[original_commit_key(original_commit)] || []
    end

    def original_commit_key(commit)
      "#{commit.repo.name}-#{commit.id}"
    end
  end
end
