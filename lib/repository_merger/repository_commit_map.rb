# frozen_string_literal: true

require_relative 'commit_map'
require 'json'

class RepositoryMerger
  class RepositoryCommitMap
    include CommitMap

    CannotSaveWithoutPathError = Class.new(StandardError)

    attr_reader :path, :monorepo

    def initialize(monorepo:, path: nil)
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

    def merge!(branch_local_commit_map)
      branch_local_commit_map.map.each do |original_commit_key, monorepo_commit_id|
        map[original_commit_key] ||= []
        next if map[original_commit_key].include?(monorepo_commit_id)
        map[original_commit_key] << monorepo_commit_id
      end
    end

    def save
      raise CannotSaveWithoutPathError unless path
      json = JSON.pretty_generate(map)
      File.write(path, json)
    end

    def monorepo_commits_for(original_commit)
      commit_ids = monorepo_commit_ids_for(original_commit)
      commit_ids.map { |id| monorepo.commit_for(id) }
    end

    def monorepo_commit_ids_for(original_commit)
      map[original_commit_key(original_commit)] || []
    end
  end
end
