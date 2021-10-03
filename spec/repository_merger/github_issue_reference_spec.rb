# frozen_string_literal: true

require 'repository_merger/github_issue_reference'

class RepositoryMerger
  RSpec.describe GitHubIssueReference do
    def a_repo_local_reference(issue_number:)
      an_instance_of(GitHubIssueReference::RepositoryLocalReference)
        .and an_object_having_attributes(issue_number: issue_number)
    end

    def an_absolute_reference(username:, repo_name:, issue_number:)
      an_instance_of(GitHubIssueReference::AbsoluteReference)
        .and an_object_having_attributes(
          username: username,
          repo_name: repo_name,
          issue_number: issue_number
        )
    end

    describe '.convert_repo_local_references_to_absolute_references_in' do
      subject(:converted_message) do
        GitHubIssueReference.convert_repo_local_references_to_absolute_ones_in(
          original_message,
          username: 'rspec',
          repo_name: 'rspec-core'
        )
      end

      let(:original_message) { <<~END }
        Merge pull request #372 from danielgrippi/patch-1

        Fixes rspec/rspec-mocks#123 and #456.
      END

      it 'converts only repo-local references' do
        expect(converted_message).to eq(<<~END)
          Merge pull request rspec/rspec-core#372 from danielgrippi/patch-1

          Fixes rspec/rspec-mocks#123 and rspec/rspec-core#456.
        END
      end
    end

    describe '.extract_references_from' do
      subject(:extracted_references) do
        GitHubIssueReference.extract_references_from(message)
      end

      context 'with a repo-local reference in auto-generated message for merged pull request' do
        let(:message) { <<~END }
          Merge pull request #372 from danielgrippi/patch-1
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 372)
          ])
        end
      end

      context 'with only #123' do
        let(:message) { <<~END }
          #123
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with #123 in the body' do
        let(:message) { <<~END }
          Subject

          #123
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with [#123]' do
        let(:message) { <<~END }
          [#123]
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with (#123)' do
        let(:message) { <<~END }
          [#123]
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with foo-#123' do
        let(:message) { <<~END }
          foo-#123
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with #123-foo' do
        let(:message) { <<~END }
          #123-foo
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with _#123' do
        let(:message) { <<~END }
          _#123
        END

        it 'extracts nothing' do
          expect(extracted_references).to be_empty
        end
      end

      context 'with #123_' do
        let(:message) { <<~END }
          #123_
        END

        it 'extracts nothing' do
          expect(extracted_references).to be_empty
        end
      end

      context 'with foo#123' do
        let(:message) { <<~END }
          foo#123
        END

        it 'extracts nothing' do
          expect(extracted_references).to be_empty
        end
      end

      context 'with rspec/rspec-core#123' do
        let(:message) { <<~END }
          Fix error with using custom matchers inside other custom matcher rspec/rspec-core#592
        END

        it 'extracts the reference' do
          expect(extracted_references).to match([
            an_absolute_reference(username: 'rspec', repo_name: 'rspec-core', issue_number: 592)
          ])
        end
      end

      context 'with multiple references' do
        let(:message) { <<~END }
          #123 rspec/rspec-core#456 #789
        END

        it 'extracts the references' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123),
            an_absolute_reference(username: 'rspec', repo_name: 'rspec-core', issue_number: 456),
            a_repo_local_reference(issue_number: 789)
          ])
        end
      end

      context 'with GH-123' do
        let(:message) { <<~END }
          GH-123
        END

        it 'extracts the references' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with gh-123' do
        let(:message) { <<~END }
          gh-123
        END

        it 'extracts the references' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end

      context 'with gh-123-1' do
        let(:message) { <<~END }
          gh-123-1
        END

        it 'extracts the references' do
          expect(extracted_references).to match([
            a_repo_local_reference(issue_number: 123)
          ])
        end
      end
    end
  end
end
