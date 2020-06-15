require 'pathname'

module PathHelper
  module_function

  def project_root_path
    File.expand_path('../..', __dir__)
  end
end
