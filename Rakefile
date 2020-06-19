# frozen_string_literal: true

desc 'Remove all generated files including merged repo'
task :clean do
  require 'fileutils'

  Dir.chdir(__dir__) do
    FileUtils.rm_rf(['commit_map.json', 'merged_repo', 'original_repos', 'tmp'])
  end
end
