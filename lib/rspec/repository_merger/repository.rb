# frozen_string_literal: true

require_relative 'branch'

require 'rugged'

module RSpec
  class RepositoryMerger
    Repository = Struct.new(:path) do
      def rugged_repo
        @rugged_repo ||= Rugged::Repository.new(path)
      end

      def name
        File.basename(path)
      end

      def branches
        branches = rugged_repo.branches.map do |rugged_branch|
          Branch.new(rugged_branch, self)
        end

        branches.map { |branch| [branch.name, branch] }.to_h
      end
    end
  end
end
