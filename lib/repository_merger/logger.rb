# frozen_string_literal: true

require 'ruby-progressbar'

class RepositoryMerger
  class Logger
    attr_reader :output

    def initialize(output, verbose:)
      @output = output
      @verbose = verbose
    end

    def info(message, title: false)
      log(message, title: title)
    end

    def verbose(message, title: false)
      return unless verbose?
      log(message, title: title)
    end

    def verbose?
      @verbose
    end

    def start_tracking_progress_for(plural_noun, total:, title: nil)
      format = " %c/%C #{plural_noun} |%w>%i| %e "
      format = " %t#{format}" if title

      @progressbar = ProgressBar.create(
        format: format,
        output: output,
        title: title,
        total: total
      )
    end

    def increment_progress
      progressbar.increment
    end

    private

    def log(message, title:)
      if title
        message = "#{'=' * 10} #{message} #{'=' * 10}"
      end

      progressbar.log(message)
    end

    def progressbar
      @progressbar ||= ProgressBar.create
    end
  end
end
