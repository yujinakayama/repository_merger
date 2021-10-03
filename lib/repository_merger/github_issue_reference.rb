# frozen_string_literal: true

class RepositoryMerger
  module GitHubIssueReference
    RepositoryLocalReference = Struct.new(:issue_number, keyword_init: true)
    AbsoluteReference = Struct.new(:username, :repo_name, :issue_number, keyword_init: true)

    # https://github.com/isiahmeadows/github-limits
    USERNAME_PATTERN = /(?<username>[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38})/i
    REPOSITORY_NAME_PATTERN = /(?<repo_name>[a-z0-9\.\-_]{1,100})/i
    ISSUE_NUMBER_PATTERN = /(?<issue_number>\d{1,5})/ # Technically max is 1073741824 but it won't exist in real life

    # https://docs.github.com/en/github/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls#issues-and-pull-requests
    REPO_LOCAL_REFERENCE_PATTERN = /(?<!\w)(?<repo_local_reference>(?:#|GH-)#{ISSUE_NUMBER_PATTERN})(?!\w)/i
    ABSOLUTE_REFERENCE_PATTERN = /(?<!\w)(?<absolute_reference>#{USERNAME_PATTERN}\/#{REPOSITORY_NAME_PATTERN}##{ISSUE_NUMBER_PATTERN})(?!\w)/
    REFERENCE_PATTERN = /(?:#{REPO_LOCAL_REFERENCE_PATTERN}|#{ABSOLUTE_REFERENCE_PATTERN})/

    def self.extract_references_from(message)
      references = []

      message.scan(REFERENCE_PATTERN) do
        reference = create_referece_from(Regexp.last_match)
        references << reference if reference
      end

      references
    end

    def self.convert_repo_local_references_to_absolute_ones_in(message, username:, repo_name:)
      message.gsub(REPO_LOCAL_REFERENCE_PATTERN) do
        reference = create_referece_from(Regexp.last_match)
        raise unless reference
        "#{username}/#{repo_name}##{reference.issue_number}"
      end
    end

    def self.create_referece_from(match)
      if match[:repo_local_reference]
        RepositoryLocalReference.new(issue_number: Integer(match[:issue_number]))
      elsif match[:absolute_reference]
        AbsoluteReference.new(
          username: match[:username],
          repo_name: match[:repo_name],
          issue_number: Integer(match[:issue_number])
        )
      end
    end
  end
end
