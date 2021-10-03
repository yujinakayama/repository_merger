# frozen_string_literal: true

require 'pathname'

module PathHelper
  module_function

  def project_root_path
    Pathname.new(File.expand_path('../..', __dir__))
  end

  def tmp_path
    project_root_path.join('tmp')
  end

  def dest_path
    project_root_path.join('dest')
  end
end
