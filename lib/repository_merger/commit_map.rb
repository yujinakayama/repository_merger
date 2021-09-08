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
      map[original_commit_key(original_commit)] = monorepo_commit_id
    end

    def monorepo_commit_for(original_commit)
      commit_id = monorepo_commit_id_for(original_commit)
      return nil unless commit_id
      monorepo.lookup(commit_id)
    end

    def monorepo_commit_id_for(original_commit)
      map[original_commit_key(original_commit)]
    end

    def original_commit_key(commit)
      "#{commit.repo.name}-#{commit.id}"
    end
  end
end
