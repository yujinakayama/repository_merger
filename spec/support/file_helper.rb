# frozen_string_literal: true

require 'digest'
require 'find'

module FileHelper
  module_function

  def files_in(dir_path, only: nil)
    files = []

    Dir.chdir(dir_path) do
      target_paths = only || ['.']

      Find.find(*target_paths) do |path|
        if File.file?(path) || File.symlink?(path)
          files << path.delete_prefix('./')
        elsif File.basename(path) == '.git'
          Find.prune
        end
      end
    end

    files.sort
  end

  def files_with_digest_in(dir_path, only: nil)
    Dir.chdir(dir_path) do
      files_in('.', only: only).each_with_object({}) do |file_path, hash|
        hash[file_path] = Digest::SHA1.hexdigest(File.read(file_path))
      end
    end
  end

  def list_of_files_with_digest(dir_path, only: nil)
    files_with_digest_in(dir_path, only: only).map do |path, digest|
      "#{digest}  #{path}"
    end.join("\n")
  end
end
