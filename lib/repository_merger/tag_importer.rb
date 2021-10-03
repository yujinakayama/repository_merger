# frozen_string_literal: true

class RepositoryMerger
  class TagImporter
    attr_reader :original_tags, :configuration, :tag_name_transformer

    def initialize(tags, configuration:, tag_name_transformer:)
      @original_tags = tags
      @configuration = configuration
      @tag_name_transformer = tag_name_transformer
    end

    def run
      logger.verbose('Importing Tags', title: true)
      logger.start_tracking_progress_for('tags', total: original_tags.size)

      original_tags.each do |original_tag|
        process_tag(original_tag)
      end
    end

    def process_tag(original_tag)
      logger.verbose "  [#{original_tag.repo.name}] #{original_tag.name}"

      new_tag_name = tag_name_transformer.call(original_tag)

      if new_tag_name
        if monorepo.tag(new_tag_name)
          logger.verbose "    Already imported as #{new_tag_name.inspect}. Skipping."
        else
          new_tag = import_tag_into_monorepo(original_tag, new_tag_name: new_tag_name)
          logger.verbose "    Imported as #{new_tag_name.inspect}." if new_tag
        end
      else
        logger.verbose '    Not for import. Skipping.'
      end

      logger.increment_progress
    end

    def import_tag_into_monorepo(original_tag, new_tag_name:)
      target_commit_id_in_monorepo = monorepo_commit_id_for(original_tag)

      unless target_commit_id_in_monorepo
        commit_description = "#{original_tag.target_commit.message.chomp.inspect} (#{original_tag.target_commit.abbreviated_id}) in #{original_tag.repo.name}"
        logger.verbose "    The target commit #{commit_description} is not yet imported. Skipping."
        return nil
      end

      monorepo.import_tag(
        original_tag,
        new_commit_id: target_commit_id_in_monorepo,
        new_tag_name: new_tag_name
      )
    end

    def monorepo_commit_id_for(original_tag)
      # TODO: Choosing the first one might be wrong
      configuration.repo_commit_map.monorepo_commit_ids_for(original_tag.target_commit).first
    end

    def monorepo
      configuration.monorepo
    end

    def logger
      configuration.logger
    end
  end
end
