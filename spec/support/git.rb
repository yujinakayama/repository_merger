# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    ENV['GIT_AUTHOR_NAME'] = 'Alice'
    ENV['GIT_AUTHOR_EMAIL'] = 'alice@example.com'
    ENV['GIT_COMMITTER_NAME'] = 'Carol'
    ENV['GIT_COMMITTER_EMAIL'] = 'carol@example.com'
  end
end
