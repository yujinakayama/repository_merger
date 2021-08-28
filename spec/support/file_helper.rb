module FileHelper
  module_function

  def files_in(dir_path)
    files = []

    Dir.chdir(dir_path) do
      Find.find('.') do |path|
        if File.file?(path) || File.symlink?(path)
          files << path.delete_prefix('./')
        elsif File.basename(path) == '.git'
          Find.prune
        end
      end
    end

    files.sort
  end

  def files_with_digest_in(dir_path)
    Dir.chdir(dir_path) do
      files_in('.').each_with_object({}) do |file_path, hash|
        hash[file_path] = Digest::SHA1.hexdigest(File.read(file_path))
      end
    end
  end

  def list_of_files_with_digest(dir_path)
    files_with_digest_in(dir_path).map do |path, digest|
      "#{digest}  #{path}"
    end.join("\n")
  end
end
