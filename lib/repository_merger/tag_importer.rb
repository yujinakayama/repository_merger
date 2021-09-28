# frozen_string_literal: true

require 'ruby-progressbar'

class RepositoryMerger
  class TagImporter
    attr_reader :configuration, :tag_name_transformer, :progressbar

    def initialize(configuration:, tag_name_transformer:)
      @configuration = configuration
      @tag_name_transformer = tag_name_transformer
      @progressbar = create_progressbar
    end

    def run
      progressbar.log "Importing tags from #{original_repos.map(&:name).join(', ')} into #{monorepo.path}..."

      original_tags.each do |original_tag|
        process_tag(original_tag)
      end
    end

    def process_tag(original_tag)
      progressbar.log "  [#{original_tag.repo.name}] #{original_tag.name}"

      new_tag_name = tag_name_transformer.call(original_tag)

      if new_tag_name
        if monorepo.tag(new_tag_name)
          progressbar.log "    The new tag #{new_tag_name.inspect} is already imported. Skipping."
        else
          progressbar.log "    Importing as #{new_tag_name.inspect}."
          import_tag_into_monorepo(original_tag, new_tag_name: new_tag_name)
        end
      else
        progressbar.log "    Not for import. Skipping."
      end

      progressbar.increment
    end

    def import_tag_into_monorepo(original_tag, new_tag_name:)
      target_commit_id_in_monorepo = monorepo_commit_id_for(original_tag)

      unless target_commit_id_in_monorepo
        commit_description = "#{original_tag.target_commit.message.chomp.inspect} (#{original_tag.target_commit.id[0, 7]}) in #{original_tag.repo.name}"
        progressbar.log "    The target commit #{commit_description} is not yet imported. Skipping."
        return
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

    def original_tags
      @original_tags ||= original_repos.flat_map(&:tags)
    end

    def original_repos
      configuration.original_repos
    end

    def monorepo
      configuration.monorepo
    end

    def create_progressbar
      # 185/407 tags |====== 45 ======>                    |  ETA: 00:00:04
      # %c / %C      |       %w       >         %i         |       %e
      bar_format = " %c/%C tags |%w>%i| %e "

      ProgressBar.create(
        format: bar_format,
        output: configuration.log_output,
        total: original_tags.size
      )
    end
  end
end
