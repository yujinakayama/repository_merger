require 'repository_merger/mono_repository'
require 'fileutils'

class RepositoryMerger
  RSpec.describe MonoRepository do
    include GitHelper

    subject(:monorepo) do
      repo_path = git_init('monorepo')
      MonoRepository.new(repo_path)
    end

    let(:original_repo) do
      FixtureHelper.rspec_core_repo
    end

    describe '#import_commit' do
      let(:original_commits) do
        original_repo.branch('origin/master').topologically_ordered_commits_from_root
      end

      it 'creates a new commit with contents of the original commit under the given subdirectory on the branch' do
        new_root_commit = monorepo.import_commit(
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

        expect(git_graph(monorepo.path, 'some_branch', format: '%s')).to eq(<<~END)
          * Initial commit to rspec-core.
        END
      end

      context 'with a parent id' do
        let!(:new_root_commit) do
          monorepo.import_commit(
            original_commits[0],
            new_parent_ids: [],
            branch_name: 'some_branch',
            subdirectory: 'rspec-core'
          )
        end

        it 'creates a child commit of the parent' do
          new_second_commit = monorepo.import_commit(
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

          expect(git_graph(monorepo.path, 'some_branch', format: '%s')).to eq(<<~END)
            * Version bump to 0.0.0
            * Initial commit to rspec-core.
          END
        end
      end

      context 'when the second commit contains removal of a file' do
        let(:original_repo) do
          repo_path = git_init('original_repo') do
            File.write('some_file.txt', "foo\n")
            `git add .`
            `git commit --message='Initial commit'`

            File.delete('some_file.txt')
            `git add .`
            `git commit --message='Remove some_file.txt'`
          end

          Repository.new(repo_path)
        end

        let(:original_commits) do
          original_repo.branch('master').topologically_ordered_commits_from_root
        end

        let!(:new_root_commit) do
          monorepo.import_commit(
            original_commits[0],
            new_parent_ids: [],
            branch_name: 'some_branch',
            subdirectory: 'subdirectory'
          )
        end

        it 'creates a commit that properly removes the file' do
          new_second_commit = monorepo.import_commit(
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

    describe '#import_tag' do
      context 'with a lightweight annotated tag' do
        let(:original_tag) do
          original_repo.tag('v2.0.0.beta.1')
        end

        let(:original_commit) do
          original_repo.branch('origin/master').topologically_ordered_commits_from_root.find do |commit|
            commit.id == 'dd11a4714dc51d78a8ba5fec42adaffc6c92ea39'
          end
        end

        let(:new_commit_in_monorepo) do
          new_parent_commit = monorepo.import_commit(
            original_commit.parents.first,
            new_parent_ids: [],
            branch_name: 'master',
            subdirectory: 'rspec-core'
          )

          monorepo.import_commit(
            original_commit,
            new_parent_ids: [new_parent_commit.id],
            branch_name: 'master',
            subdirectory: 'rspec-core'
          )
        end

        it 'creates a new tag' do
          new_tag = monorepo.import_tag(
            original_tag,
            new_commit_id: new_commit_in_monorepo.id,
            new_tag_name: 'v2.0.0.beta.1'
          )

          expect(git_show(new_tag).sub(/^commit \h+/, 'commit ?'))
            .to eq(git_show(original_tag).sub(/^commit \h+/, 'commit ?').sub('tag v2.0.0.beta.1', 'tag rspec-core-v2.0.0.beta.1').gsub('PATH:', 'PATH:rspec-core/'))

          expect(git_show(new_tag)).to start_with(<<~END)
            commit 553ffa5b2fdf596956e69871848675a69b6f06d0
            Author:     David Chelimsky <dchelimsky@gmail.com>
            AuthorDate: Mon Mar 1 23:03:27 2010 -0600
            Commit:     David Chelimsky <dchelimsky@gmail.com>
            CommitDate: Mon Mar 1 23:03:27 2010 -0600

                rename method and avoid collision with 'assignments'

          END
        end
      end

      context 'with an annotated tag' do
        let(:original_tag) do
          original_repo.tag('v3.0.0')
        end

        let(:original_commit) do
          original_repo.branch('origin/master').topologically_ordered_commits_from_root.find do |commit|
            commit.id == '91f428f609b37422c08306517e09d2466ab8e516'
          end
        end

        let(:new_commit_in_monorepo) do
          new_parent_commit = monorepo.import_commit(
            original_commit.parents.first,
            new_parent_ids: [],
            branch_name: 'master',
            subdirectory: 'rspec-core'
          )

          monorepo.import_commit(
            original_commit,
            new_parent_ids: [new_parent_commit.id],
            branch_name: 'master',
            subdirectory: 'rspec-core'
          )
        end

        it 'creates a new tag with the annotation' do
          new_tag = monorepo.import_tag(
            original_tag,
            new_commit_id: new_commit_in_monorepo.id,
            new_tag_name: 'rspec-core-v3.0.0'
          )

          expect(git_show(new_tag).sub(/^commit \h+/, 'commit ?'))
            .to eq(git_show(original_tag).sub(/^commit \h+/, 'commit ?').sub('tag v3.0.0', 'tag rspec-core-v3.0.0').gsub('PATH:', 'PATH:rspec-core/'))

          expect(git_show(new_tag)).to eq(<<~END)
            tag rspec-core-v3.0.0
            Tagger:     Myron Marston <myron.marston@gmail.com>
            TaggerDate: Sun Jun 1 20:32:31 2014 -0700

            Version 3.0.0

            commit #{new_tag.target_commit.id}
            Author:     Myron Marston <myron.marston@gmail.com>
            AuthorDate: Sun Jun 1 20:27:10 2014 -0700
            Commit:     Myron Marston <myron.marston@gmail.com>
            CommitDate: Sun Jun 1 20:27:10 2014 -0700

                Release 3.0.0

            diff --git PATH:rspec-core/lib/rspec/core/version.rb PATH:rspec-core/lib/rspec/core/version.rb
            index 1e2105bc3cf83aa00c2d4747e0a6e986797887cb..b565629bca6d7698ae8e6e277cf77eaab6407df2 100644
            --- PATH:rspec-core/lib/rspec/core/version.rb
            +++ PATH:rspec-core/lib/rspec/core/version.rb
            @@ -3,7 +3,7 @@ module RSpec
                 # Version information for RSpec Core.
                 module Version
                   # Current version of RSpec Core, in semantic versioning format.
            -      STRING = '3.0.0.rc1'
            +      STRING = '3.0.0'
                 end
               end
             end
          END
        end
      end
    end
  end
end
