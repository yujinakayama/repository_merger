# frozen_string_literal: true

require_relative 'lib/repository_merger/version'

Gem::Specification.new do |spec|
  spec.name          = 'repository_merger'
  spec.version       = RepositoryMerger::Version.to_s
  spec.authors       = ['Yuji Nakayama']
  spec.email         = ['nkymyj@gmail.com']

  spec.summary       = 'A tool for merging existing Git repositories into a monorepo with the original commit history'
  spec.homepage      = 'https://github.com/yujinakayama/repository_merger'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'ruby-progressbar', '~> 1.11'
  spec.add_runtime_dependency 'rugged', '~> 1.2'

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
