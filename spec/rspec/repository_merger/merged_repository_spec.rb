require 'rspec/repository_merger/merged_repository'
require 'fileutils'

class RSpec::RepositoryMerger
  RSpec.describe MergedRepository do
    include GitHelper

    subject(:merged_repo) do
      path = 'tmp/merged_repo'
      git_init(path)
      RSpec::RepositoryMerger::MergedRepository.new(path)
    end

    describe '#import_commit' do
      let(:original_repo) do
        FixtureHelper.rspec_core_repo
      end

      let(:original_commits) do
        original_repo.branches['origin/master'].topologically_ordered_commits_from_root
      end

      it 'creates a new commit with contents of the original commit under the given subdirectory on the branch' do
        new_root_commit = merged_repo.import_commit(
          original_commits[0],
          new_parent_ids: [],
          branch_name: 'some_branch',
          subdirectory: 'rspec-core'
        )

        expect(git_show(new_root_commit).sub(/\Acommit \h+/, ''))
          .to eq(git_show(original_commits[0]).sub(/\Acommit \h+/, '').gsub('PATH:', 'PATH:rspec-core/'))

        expect(git_show(new_root_commit)).to start_with(<<~END)
          commit #{new_root_commit.id}
          Author:     Chad Humphries <chad@spicycode.com>
          AuthorDate: Mon Jun 29 11:46:43 2009 -0400
          Commit:     Chad Humphries <chad@spicycode.com>
          CommitDate: Mon Jun 29 11:46:43 2009 -0400

              Initial commit to rspec-core.

          diff --git PATH:rspec-core/.document PATH:rspec-core/.document
          new file mode 100644
          index 0000000000000000000000000000000000000000..ecf3673194b8b6963488dabc93d5f16fea93c5e9
          --- /dev/null
          +++ PATH:rspec-core/.document
          @@ -0,0 +1,5 @@
          +README.rdoc
          +lib/**/*.rb
          +bin/*
          +features/**/*.feature
          +LICENSE
        END

        expect(git_log(merged_repo, 'some_branch')).to eq(<<~END)
          * Initial commit to rspec-core.
        END
      end

      context 'with a parent id' do
        let!(:new_root_commit) do
          merged_repo.import_commit(
            original_commits[0],
            new_parent_ids: [],
            branch_name: 'some_branch',
            subdirectory: 'rspec-core'
          )
        end

        it 'creates a child commit of the parent' do
          new_second_commit = merged_repo.import_commit(
            original_commits[1],
            new_parent_ids: [new_root_commit.id],
            branch_name: 'some_branch',
            subdirectory: 'rspec-core'
          )

          expect(git_show(new_second_commit).sub(/\Acommit \h+/, ''))
            .to eq(git_show(original_commits[1]).sub(/\Acommit \h+/, '').gsub('PATH:', 'PATH:rspec-core/'))

          expect(git_show(new_second_commit)).to start_with(<<~END)
            commit #{new_second_commit.id}
            Author:     Chad Humphries <chad@spicycode.com>
            AuthorDate: Mon Jun 29 11:57:27 2009 -0400
            Commit:     Chad Humphries <chad@spicycode.com>
            CommitDate: Mon Jun 29 11:57:27 2009 -0400

                Version bump to 0.0.0

            diff --git PATH:rspec-core/License.txt PATH:rspec-core/License.txt
            new file mode 100644
            index 0000000000000000000000000000000000000000..7cbad99a459e6ed06ca28aa511f8d80c093fc317
            --- /dev/null
            +++ PATH:rspec-core/License.txt
            @@ -0,0 +1,22 @@
            +(The MIT License)
          END

          expect(git_log(merged_repo, 'some_branch')).to eq(<<~END)
            * Version bump to 0.0.0
            * Initial commit to rspec-core.
          END
        end
      end

      context 'when the second commit contains removal of a file' do
        let(:original_repo) do
          path = 'tmp/original_repo'

          git_init(path) do
            File.write('some_file.txt', "foo\n")
            `git add .`
            `git commit --message='Initial commit'`

            File.delete('some_file.txt')
            `git add .`
            `git commit --message='Remove some_file.txt'`
          end

          RSpec::RepositoryMerger::Repository.new(path)
        end

        let(:original_commits) do
          original_repo.branches['master'].topologically_ordered_commits_from_root
        end

        let!(:new_root_commit) do
          merged_repo.import_commit(
            original_commits[0],
            new_parent_ids: [],
            branch_name: 'some_branch',
            subdirectory: 'subdirectory'
          )
        end

        it 'creates a commit that properly remove the file' do
          new_second_commit = merged_repo.import_commit(
            original_commits[1],
            new_parent_ids: [new_root_commit.id],
            branch_name: 'some_branch',
            subdirectory: 'subdirectory'
          )

          expect(git_show(new_second_commit).sub(/\Acommit \h+/, ''))
            .to eq(git_show(original_commits[1]).sub(/\Acommit \h+/, '').gsub('PATH:', 'PATH:subdirectory/'))

          expect(git_show(new_second_commit)).to end_with(<<~END)

                Remove some_file.txt

            diff --git PATH:subdirectory/some_file.txt PATH:subdirectory/some_file.txt
            deleted file mode 100644
            index 257cc5642cb1a054f08cc83f2d943e56fd3ebe99..0000000000000000000000000000000000000000
            --- PATH:subdirectory/some_file.txt
            +++ /dev/null
            @@ -1 +0,0 @@
            -foo
          END
        end
      end
    end
  end
end
