require 'repository_merger'
require 'stringio'

RSpec.describe RepositoryMerger do
  include GitHelper

  def git_commit(message:)
    git(['commit', '--allow-empty', "--message=#{message}"])
  end

  def git_merge(branch_name)
    git(['merge', '--no-edit', branch_name])
  end

  def with_git_time(time, &block)
    with_git_date(fake_date_for(time), &block)
  end

  def git_tag(name, message: nil)
    if message
      git(['tag', '--annotate', name, '--message', message])
    else
      git(['tag', name])
    end
  end

  def fake_date_for(time)
    "2020-01-01 #{time} +0000"
  end

  def commit_graph_of(repo_path, branch_names = nil)
    git_graph(repo_path, branch_names, format: '%ci %s%d')
  end

  def commit_fingerprints_in(repo_path, revision_id)
    log = Dir.chdir(repo_path) do
      git(['log', '--format=%ai %ae, %ci %ce', revision_id])
    end

    log.split("\n")
  end

  describe '#merge_branches' do
    let(:repo_merger) do
      RepositoryMerger.new(
        [repo_a_path, repo_b_path],
        monorepo_path: monorepo_path,
        commit_map_file_path: nil,
        log_output: log_output
      )
    end

    let(:monorepo_path) do
      git_init('monorepo')
    end

    let(:log_output) do
      StringIO.new
    end

    let(:commit_message_transformer) do
      proc do |original_commit|
        "[#{original_commit.repo.name}] #{original_commit.message}"
      end
    end

    context 'when importing a single set of branches' do
      # * 2020-01-01 00:07:00 +0000 master 5
      # *   2020-01-01 00:06:00 +0000 Merge branch 'feature-a'
      # |\
      # | * 2020-01-01 00:05:00 +0000 feature-a 2
      # | * 2020-01-01 00:03:00 +0000 feature-a 1
      # * | 2020-01-01 00:04:00 +0000 master 4
      # |/
      # * 2020-01-01 00:02:00 +0000 master 3 / feature-a branching
      # * 2020-01-01 00:01:00 +0000 master 2
      # * 2020-01-01 00:00:00 +0000 master 1
      let(:repo_a_path) do
        git_init('repo_a') do
          with_git_time('00:00:00') { git_commit(message: 'master 1') }
          with_git_time('00:01:00') { git_commit(message: 'master 2') }
          with_git_time('00:02:00') { git_commit(message: 'master 3 / feature-a branching') }

          git('checkout -b feature-a')
          with_git_time('00:03:00') { git_commit(message: 'feature-a 1') }

          git('checkout master')
          with_git_time('00:04:00') { git_commit(message: 'master 4') }

          git('checkout feature-a')
          with_git_time('00:05:00') { git_commit(message: 'feature-a 2') }

          git('checkout master')
          with_git_time('00:06:00') { git_merge('feature-a') }
          with_git_time('00:07:00') { git_commit(message: 'master 5') }
        end
      end

      # * 2020-01-01 00:07:10 +0000 master 4
      # *   2020-01-01 00:04:10 +0000 Merge branch 'feature-b'
      # |\
      # | * 2020-01-01 00:03:10 +0000 feature-b 1
      # * | 2020-01-01 00:01:20 +0000 master 3
      # |/
      # * 2020-01-01 00:01:10 +0000 master 2 / feature-b branching
      # * 2020-01-01 00:00:10 +0000 master 1
      let(:repo_b_path) do
        git_init('repo_b') do
          with_git_time('00:00:10') { git_commit(message: 'master 1') }
          with_git_time('00:01:10') { git_commit(message: 'master 2 / feature-b branching') }

          git('checkout -b feature-b')

          git('checkout master')
          with_git_time('00:01:20') { git_commit(message: 'master 3') }

          git('checkout feature-b')
          with_git_time('00:03:10') { git_commit(message: 'feature-b 1') }

          git('checkout master')
          with_git_time('00:04:10') { git_merge('feature-b') }
          with_git_time('00:07:10') { git_commit(message: 'master 4') }
        end
      end

      it 'imports mainline commits by mixing in date order and non-mainline commits without mixing' do
        repo_merger.merge_branches(['master'], commit_message_transformer: commit_message_transformer)

        expect(commit_graph_of(monorepo_path)).to eq(<<~'END')
          * 2020-01-01 00:07:10 +0000 [repo_b] master 4 (HEAD -> master)
          * 2020-01-01 00:07:00 +0000 [repo_a] master 5
          *   2020-01-01 00:06:00 +0000 [repo_a] Merge branch 'feature-a'
          |\
          | * 2020-01-01 00:05:00 +0000 [repo_a] feature-a 2
          | * 2020-01-01 00:03:00 +0000 [repo_a] feature-a 1
          * |   2020-01-01 00:04:10 +0000 [repo_b] Merge branch 'feature-b'
          |\ \
          | * | 2020-01-01 00:03:10 +0000 [repo_b] feature-b 1
          * | | 2020-01-01 00:04:00 +0000 [repo_a] master 4
          | |/
          |/|
          * | 2020-01-01 00:02:00 +0000 [repo_a] master 3 / feature-a branching
          * | 2020-01-01 00:01:20 +0000 [repo_b] master 3
          |/
          * 2020-01-01 00:01:10 +0000 [repo_b] master 2 / feature-b branching
          * 2020-01-01 00:01:00 +0000 [repo_a] master 2
          * 2020-01-01 00:00:10 +0000 [repo_b] master 1
          * 2020-01-01 00:00:00 +0000 [repo_a] master 1
        END

        expect(commit_fingerprints_in(monorepo_path, 'master')).to contain_exactly(
          *(commit_fingerprints_in(repo_a_path, 'master') + commit_fingerprints_in(repo_b_path, 'master'))
        )
      end
    end

    context "when importing multiple sets of branches sharing some commits, and some non-shared commits have earlier commit time than another repo's branching point commit" do
      # * 2020-01-01 00:05:00 +0000 master 4 (HEAD -> master)
      # | * 2020-01-01 00:04:00 +0000 maintenance 2 (maintenance)
      # | * 2020-01-01 00:03:00 +0000 maintenance 1
      # |/
      # * 2020-01-01 00:02:00 +0000 master 3 / maintenance branching
      # * 2020-01-01 00:01:00 +0000 master 2
      # * 2020-01-01 00:00:00 +0000 master 1
      let(:repo_a_path) do
        git_init('repo_a') do
          with_git_time('00:00:00') { git_commit(message: 'master 1') }
          with_git_time('00:01:00') { git_commit(message: 'master 2') }
          with_git_time('00:02:00') { git_commit(message: 'master 3 / maintenance branching') }

          git('checkout -b maintenance')
          with_git_time('00:03:00') { git_commit(message: 'maintenance 1') }
          with_git_time('00:04:00') { git_commit(message: 'maintenance 2') }

          git('checkout master')
          with_git_time('00:05:00') { git_commit(message: 'master 4') }
        end
      end

      # * 2020-01-01 00:04:10 +0000 master 3 (HEAD -> master)
      # | * 2020-01-01 00:03:10 +0000 maintenance 3 (maintenance)
      # | * 2020-01-01 00:00:40 +0000 maintenance 2 (earlier than repo_a's branching point in date order)
      # | * 2020-01-01 00:00:30 +0000 maintenance 1 (earlier than repo_a's branching point in date order)
      # |/
      # * 2020-01-01 00:00:20 +0000 master 2 / maintenance branching
      # * 2020-01-01 00:00:10 +0000 master 1
      let(:repo_b_path) do
        git_init('repo_b') do
          with_git_time('00:00:10') { git_commit(message: 'master 1') }
          with_git_time('00:00:20') { git_commit(message: 'master 2 / maintenance branching') }

          git('checkout -b maintenance')
          with_git_time('00:00:30') { git_commit(message: "maintenance 1 (earlier than repo_a's branching point in date order)") }
          with_git_time('00:00:40') { git_commit(message: "maintenance 2 (earlier than repo_a's branching point in date order)") }
          with_git_time('00:03:10') { git_commit(message: 'maintenance 3') }

          git('checkout master')
          with_git_time('00:04:10') { git_commit(message: 'master 3') }
        end
      end

      it 'imports commits without creating duplicate commits nor losing commits while keeping date order as much as possible' do
        repo_merger.merge_branches(['master', 'maintenance'], commit_message_transformer: commit_message_transformer)

        expect(commit_graph_of(monorepo_path)).to eq(<<~'END')
          * 2020-01-01 00:05:00 +0000 [repo_a] master 4 (HEAD -> master)
          * 2020-01-01 00:04:10 +0000 [repo_b] master 3
          | * 2020-01-01 00:04:00 +0000 [repo_a] maintenance 2 (maintenance)
          | * 2020-01-01 00:03:10 +0000 [repo_b] maintenance 3
          | * 2020-01-01 00:03:00 +0000 [repo_a] maintenance 1
          | * 2020-01-01 00:00:40 +0000 [repo_b] maintenance 2 (earlier than repo_a's branching point in date order)
          | * 2020-01-01 00:00:30 +0000 [repo_b] maintenance 1 (earlier than repo_a's branching point in date order)
          |/
          * 2020-01-01 00:02:00 +0000 [repo_a] master 3 / maintenance branching
          * 2020-01-01 00:01:00 +0000 [repo_a] master 2
          * 2020-01-01 00:00:20 +0000 [repo_b] master 2 / maintenance branching
          * 2020-01-01 00:00:10 +0000 [repo_b] master 1
          * 2020-01-01 00:00:00 +0000 [repo_a] master 1
        END

        expect(commit_fingerprints_in(monorepo_path, 'master')).to contain_exactly(
          *(commit_fingerprints_in(repo_a_path, 'master') + commit_fingerprints_in(repo_b_path, 'master'))
        )

        expect(commit_fingerprints_in(monorepo_path, 'maintenance')).to contain_exactly(
          *(commit_fingerprints_in(repo_a_path, 'maintenance') + commit_fingerprints_in(repo_b_path, 'maintenance'))
        )
      end
    end

    context "when importing 3 sets of branches sharing some commits, and some commits shared by 2 branches have earlier commit time than another repo's branching point commit shared by 2 branches" do
      # * 2020-01-01 00:03:00 +0000 bugfix 1 (HEAD -> bugfix)
      # * 2020-01-01 00:02:00 +0000 maintenance 1 / bugfix branching (maintenance)
      # * 2020-01-01 00:01:00 +0000 master 2 / maintenance branching (master)
      # * 2020-01-01 00:00:00 +0000 master 1
      let(:repo_a_path) do
        git_init('repo_a') do
          with_git_time('00:00:00') { git_commit(message: 'master 1') }
          with_git_time('00:01:00') { git_commit(message: 'master 2 / maintenance branching') }

          git('checkout -b maintenance')
          with_git_time('00:02:00') { git_commit(message: 'maintenance 1 / bugfix branching') }

          git('checkout -b bugfix')
          with_git_time('00:03:00') { git_commit(message: 'bugfix 1') }
        end
      end

      # * 2020-01-01 00:00:40 +0000 bugfix 1 (HEAD -> bugfix)
      # * 2020-01-01 00:00:30 +0000 maintenance 1 / bugfix branching (maintenance)
      # * 2020-01-01 00:00:20 +0000 master 2 / maintenance branching (master)
      # * 2020-01-01 00:00:10 +0000 master 1
      let(:repo_b_path) do
        git_init('repo_b') do
          with_git_time('00:00:10') { git_commit(message: 'master 1') }
          with_git_time('00:00:20') { git_commit(message: 'master 2 / maintenance branching') }

          git('checkout -b maintenance')
          with_git_time('00:00:30') { git_commit(message: 'maintenance 1 / bugfix branching') }

          git('checkout -b bugfix')
          with_git_time('00:00:40') { git_commit(message: 'bugfix 1') }
        end
      end

      it 'imports commits without creating duplicate commits nor losing commits while keeping date order as much as possible' do
        repo_merger.merge_branches(['master', 'maintenance', 'bugfix'], commit_message_transformer: commit_message_transformer)

        expect(commit_graph_of(monorepo_path)).to eq(<<~'END')
          * 2020-01-01 00:03:00 +0000 [repo_a] bugfix 1 (bugfix)
          * 2020-01-01 00:00:40 +0000 [repo_b] bugfix 1
          * 2020-01-01 00:02:00 +0000 [repo_a] maintenance 1 / bugfix branching (maintenance)
          * 2020-01-01 00:00:30 +0000 [repo_b] maintenance 1 / bugfix branching
          * 2020-01-01 00:01:00 +0000 [repo_a] master 2 / maintenance branching (HEAD -> master)
          * 2020-01-01 00:00:20 +0000 [repo_b] master 2 / maintenance branching
          * 2020-01-01 00:00:10 +0000 [repo_b] master 1
          * 2020-01-01 00:00:00 +0000 [repo_a] master 1
        END
      end
    end

    context 'when importing multiple sets of branches sharing some commits, and one of the repos does not have a specified branch' do
      # * 2020-01-01 00:03:00 +0000 maintenance 1 (HEAD -> maintenance)
      # * 2020-01-01 00:02:00 +0000 master 3 / maintenance branching (master)
      # * 2020-01-01 00:01:00 +0000 master 2
      # * 2020-01-01 00:00:00 +0000 master 1
      let(:repo_a_path) do
        git_init('repo_a') do
          with_git_time('00:00:00') { git_commit(message: 'master 1') }
          with_git_time('00:01:00') { git_commit(message: 'master 2') }
          with_git_time('00:02:00') { git_commit(message: 'master 3 / maintenance branching') }

          git('checkout -b maintenance')
          with_git_time('00:03:00') { git_commit(message: 'maintenance 1') }
        end
      end

      # * 2020-01-01 00:00:30 +0000 master 3 (HEAD -> master)
      # * 2020-01-01 00:00:20 +0000 master 2
      # * 2020-01-01 00:00:10 +0000 master 1
      let(:repo_b_path) do
        git_init('repo_b') do
          with_git_time('00:00:10') { git_commit(message: 'master 1') }
          with_git_time('00:00:20') { git_commit(message: 'master 2') }
          with_git_time('00:00:30') { git_commit(message: 'master 3') }
        end
      end

      it 'imports commits without creating duplicate commits nor losing commits while keeping date order as much as possible' do
        repo_merger.merge_branches(['master', 'maintenance'], commit_message_transformer: commit_message_transformer)

        expect(commit_graph_of(monorepo_path)).to eq(<<~'END')
          * 2020-01-01 00:03:00 +0000 [repo_a] maintenance 1 (maintenance)
          * 2020-01-01 00:02:00 +0000 [repo_a] master 3 / maintenance branching (HEAD -> master)
          * 2020-01-01 00:01:00 +0000 [repo_a] master 2
          * 2020-01-01 00:00:30 +0000 [repo_b] master 3
          * 2020-01-01 00:00:20 +0000 [repo_b] master 2
          * 2020-01-01 00:00:10 +0000 [repo_b] master 1
          * 2020-01-01 00:00:00 +0000 [repo_a] master 1
        END
      end
    end
  end

  describe '#import_tags' do
    let(:repo_merger) do
      RepositoryMerger.new(
        [repo_a_path, repo_b_path],
        monorepo_path: monorepo_path,
        commit_map_file_path: nil,
        log_output: log_output
      )
    end

    let(:log_output) do
      StringIO.new
    end

    let(:commit_message_transformer) do
      proc do |original_commit|
        "[#{original_commit.repo.name}] #{original_commit.message}"
      end
    end

    let(:tag_name_transformer) do
      proc do |original_tag|
        if original_tag.name.include?('alpha')
          nil
        else
          "#{original_tag.repo.name}-#{original_tag.name}"
        end
      end
    end

    # git log --graph --format='%ci %s'
    # * 2020-01-01 00:07:00 +0000 master 5
    # *   2020-01-01 00:06:00 +0000 Merge branch 'feature-a'
    # |\
    # | * 2020-01-01 00:05:00 +0000 feature-a 2
    # | * 2020-01-01 00:03:00 +0000 feature-a 1
    # * | 2020-01-01 00:04:00 +0000 master 4
    # |/
    # * 2020-01-01 00:02:00 +0000 master 3 / feature-a branching
    # * 2020-01-01 00:01:00 +0000 master 2
    # * 2020-01-01 00:00:00 +0000 master 1
    let(:repo_a_path) do
      git_init('repo_a') do
        with_git_time('00:00:00') { git_commit(message: 'master 1') }
        with_git_time('00:01:00') { git_commit(message: 'master 2') }
        git_tag('1.0')
        with_git_time('00:02:00') { git_commit(message: 'master 3 / feature-a branching') }

        git('checkout -b feature-a')
        with_git_time('00:03:00') { git_commit(message: 'feature-a 1') }

        git('checkout master')
        with_git_time('00:04:00') { git_commit(message: 'master 4') }

        git('checkout feature-a')
        with_git_time('00:05:00') { git_commit(message: 'feature-a 2') }
        git_tag('1.1-beta')

        git('checkout master')
        with_git_time('00:06:00') { git_merge('feature-a') }
        with_git_time('00:07:00') { git_commit(message: 'master 5') }
        git_tag('1.1')
      end
    end

    # git log --graph --format='%ci %s'
    # * 2020-01-01 00:07:10 +0000 master 4
    # *   2020-01-01 00:04:10 +0000 Merge branch 'feature-b'
    # |\
    # | * 2020-01-01 00:03:10 +0000 feature-b 1
    # * | 2020-01-01 00:01:20 +0000 master 3
    # |/
    # * 2020-01-01 00:01:10 +0000 master 2 / feature-b branching
    # * 2020-01-01 00:00:10 +0000 master 1
    let(:repo_b_path) do
      git_init('repo_b') do
        with_git_time('00:00:10') { git_commit(message: 'master 1') }
        with_git_time('00:01:10') { git_commit(message: 'master 2 / feature-b branching') }
        git_tag('1.0')

        git('checkout -b feature-b')

        git('checkout master')
        with_git_time('00:01:20') { git_commit(message: 'master 3') }

        git('checkout feature-b')
        with_git_time('00:03:10') { git_commit(message: 'feature-b 1') }
        git_tag('1.1-alpha')

        git('checkout master')
        with_git_time('00:04:10') { git_merge('feature-b') }
        with_git_time('00:07:10') { git_commit(message: 'master 4') }
        git_tag('1.1')
      end
    end

    let(:monorepo_path) do
      git_init('monorepo')
    end

    before do
      repo_merger.merge_branches(['master'], commit_message_transformer: commit_message_transformer)
    end

    it 'imports tags by transforming names or skips importing some tags if it should' do
      repo_merger.import_tags(tag_name_transformer: tag_name_transformer)

      expect(commit_graph_of(monorepo_path, 'master')).to eq(<<~'END')
        * 2020-01-01 00:07:10 +0000 [repo_b] master 4 (HEAD -> master, tag: repo_b-1.1)
        * 2020-01-01 00:07:00 +0000 [repo_a] master 5 (tag: repo_a-1.1)
        *   2020-01-01 00:06:00 +0000 [repo_a] Merge branch 'feature-a'
        |\
        | * 2020-01-01 00:05:00 +0000 [repo_a] feature-a 2 (tag: repo_a-1.1-beta)
        | * 2020-01-01 00:03:00 +0000 [repo_a] feature-a 1
        * |   2020-01-01 00:04:10 +0000 [repo_b] Merge branch 'feature-b'
        |\ \
        | * | 2020-01-01 00:03:10 +0000 [repo_b] feature-b 1
        * | | 2020-01-01 00:04:00 +0000 [repo_a] master 4
        | |/
        |/|
        * | 2020-01-01 00:02:00 +0000 [repo_a] master 3 / feature-a branching
        * | 2020-01-01 00:01:20 +0000 [repo_b] master 3
        |/
        * 2020-01-01 00:01:10 +0000 [repo_b] master 2 / feature-b branching (tag: repo_b-1.0)
        * 2020-01-01 00:01:00 +0000 [repo_a] master 2 (tag: repo_a-1.0)
        * 2020-01-01 00:00:10 +0000 [repo_b] master 1
        * 2020-01-01 00:00:00 +0000 [repo_a] master 1
      END
    end

    context 'with annotated tags' do
      let(:repo_a_path) do
        git_init('repo_a') do
          with_git_time('00:00:00') { git_commit(message: 'master 1') }
          with_git_time('00:01:00') { git_commit(message: 'master 2') }
          with_git_time('00:02:00') { git_tag('1.0', message: 'Initial release') }
        end
      end

      let(:repo_b_path) do
        git_init('repo_b') do
          with_git_time('00:00:10') { git_commit(message: 'master 1') }
        end
      end

      before do
        repo_merger.merge_branches(['master'], commit_message_transformer: commit_message_transformer)
      end

      it 'properly imports them with message and metadata' do
        repo_merger.import_tags(tag_name_transformer: tag_name_transformer)

        expect(commit_graph_of(monorepo_path, 'master')).to eq(<<~'END')
          * 2020-01-01 00:01:00 +0000 [repo_a] master 2 (HEAD -> master, tag: repo_a-1.0)
          * 2020-01-01 00:00:10 +0000 [repo_b] master 1
          * 2020-01-01 00:00:00 +0000 [repo_a] master 1
        END

        expect(git_show(monorepo_path, 'repo_a-1.0')).to eq(<<~'END')
          tag repo_a-1.0
          Tagger:     Carol <carol@example.com>
          TaggerDate: Wed Jan 1 00:02:00 2020 +0000

          Initial release

          commit f26d321247eff1e7369e1abdf9bdfb9648f04209
          Author:     Alice <alice@example.com>
          AuthorDate: Wed Jan 1 00:01:00 2020 +0000
          Commit:     Carol <carol@example.com>
          CommitDate: Wed Jan 1 00:01:00 2020 +0000

              [repo_a] master 2
        END
      end
    end
  end
end
