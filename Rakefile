# frozen_string_literal: true

desc 'Remove all generated files including monorepo'
task :clean do
  require 'fileutils'

  Dir.chdir(__dir__) do
    FileUtils.rm_rf(['dest', 'tmp'])
  end
end
