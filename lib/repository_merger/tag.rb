# frozen_string_literal: true

require_relative 'reference'

class RepositoryMerger
  Tag = Struct.new(:rugged_tag, :repo) do
    include Reference

    def name
      rugged_tag.name
    end

    def target_commit
      @target_commit ||= begin
        commit_id =
          if rugged_tag.annotated?
            rugged_tag.annotation.target_id
          else
            rugged_tag.target_id
          end

        repo.lookup(commit_id)
      end
    end

    def annotation
      if rugged_tag.annotated?
        { tagger: rugged_tag.annotation.tagger, message: rugged_tag.annotation.message }
      else
        nil
      end
    end

    def id
      name
    end

    def revision_id
      name
    end
  end
end
