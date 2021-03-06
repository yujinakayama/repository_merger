require 'repository_merger'
require 'stringio'

RSpec.describe RepositoryMerger do
  include GitHelper

  def git_commit(time:, message:)
    with_git_date(fake_date_for(time)) do
      git(['commit', '--allow-empty', "--message=#{message}"])
    end
  end

  def git_merge(branch_name, time: )
    with_git_date(fake_date_for(time)) do
      git(['merge', '--no-edit', branch_name])
    end
  end

  def fake_date_for(time)
    "2020-01-01 #{time} +0000"
  end

  def commit_graph_of(repo_path, branch_names)
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

    let(:log_output) do
      StringIO.new
    end

    let(:commit_message_transformer) do
      proc do |original_commit|
        "[#{original_commit.repo.name}] #{original_commit.message}"
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
        git_commit(time: '00:00:00', message: 'master 1')
        git_commit(time: '00:01:00', message: 'master 2')
        git_commit(time: '00:02:00', message: 'master 3 / feature-a branching')

        git('checkout -b feature-a')
        git_commit(time: '00:03:00', message: 'feature-a 1')

        git('checkout master')
        git_commit(time: '00:04:00', message: 'master 4')

        git('checkout feature-a')
        git_commit(time: '00:05:00', message: 'feature-a 2')

        git('checkout master')
        git_merge('feature-a', time: '00:06:00')
        git_commit(time: '00:07:00', message: 'master 5')
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
        git_commit(time: '00:00:10', message: 'master 1')
        git_commit(time: '00:01:10', message: 'master 2 / feature-b branching')

        git('checkout -b feature-b')

        git('checkout master')
        git_commit(time: '00:01:20', message: 'master 3')

        git('checkout feature-b')
        git_commit(time: '00:03:10', message: 'feature-b 1')

        git('checkout master')
        git_merge('feature-b', time: '00:04:10')
        git_commit(time: '00:07:10', message: 'master 4')
      end
    end

    subject(:monorepo_path) do
      git_init('monorepo')
    end

    it 'imports mainline commits by mixing in date order and non-mainline commits without mixing' do
      repo_merger.merge_branches(['master'], commit_message_transformer: commit_message_transformer)

      expect(commit_graph_of(monorepo_path, 'master')).to eq(<<~'END')
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

    context "when importing multiple branches that share some commits, and some non-shared commits have earlier commit time than another repo's branching point commit" do
      let(:repo_a_path) do
        git_init('repo_a') do
          git_commit(time: '00:00:00', message: 'master 1')
          git_commit(time: '00:01:00', message: 'master 2')
          git_commit(time: '00:02:00', message: 'master 3 / maintenance branching')

          git('checkout -b maintenance')
          git_commit(time: '00:03:00', message: 'maintenance 1')
          git_commit(time: '00:04:00', message: 'maintenance 2')

          git('checkout master')
          git_commit(time: '00:05:00', message: 'master 4')
        end
      end

      let(:repo_b_path) do
        git_init('repo_b') do
          git_commit(time: '00:00:10', message: 'master 1')
          git_commit(time: '00:00:20', message: 'master 2 / maintenance branching')

          git('checkout -b maintenance')
          git_commit(time: '00:00:30', message: "maintenance 1 (earlier than repo_a's branching point in date order)")
          git_commit(time: '00:00:40', message: "maintenance 2 (earlier than repo_a's branching point in date order)")
          git_commit(time: '00:03:10', message: 'maintenance 3')

          git('checkout master')
          git_commit(time: '00:04:10', message: 'master 3')
        end
      end

      it 'imports commits without creating duplicate commits nor losing commits while keeping date order as much as possible' do
        repo_merger.merge_branches(['master', 'maintenance'], commit_message_transformer: commit_message_transformer)

        expect(commit_graph_of(monorepo_path, ['master', 'maintenance'])).to eq(<<~'END')
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

    context "when importing 3 branches that share some commits, and some commits shared by 2 branches have earlier commit time than another repo's branching point commit shared by 2 branches" do
      let(:repo_a_path) do
        git_init('repo_a') do
          git_commit(time: '00:00:00', message: 'master 1')
          git_commit(time: '00:01:00', message: 'master 2 / maintenance branching')

          git('checkout -b maintenance')
          git_commit(time: '00:02:00', message: 'maintenance 1 / bugfix branching')

          git('checkout -b bugfix')
          git_commit(time: '00:03:00', message: 'bugfix 1')
        end
      end

      let(:repo_b_path) do
        git_init('repo_b') do
          git_commit(time: '00:00:10', message: 'master 1')
          git_commit(time: '00:00:20', message: 'master 2 / maintenance branching')

          git('checkout -b maintenance')
          git_commit(time: '00:00:30', message: 'maintenance 1 / bugfix branching')

          git('checkout -b bugfix')
          git_commit(time: '00:00:40', message: 'bugfix 1')
        end
      end

      it 'imports commits without creating duplicate commits nor losing commits while keeping date order as much as possible' do
        repo_merger.merge_branches(['master', 'maintenance', 'bugfix'], commit_message_transformer: commit_message_transformer)

        expect(commit_graph_of(monorepo_path, ['master', 'maintenance', 'bugfix'])).to eq(<<~'END')
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

    context 'when importing multiple branches that share some commits, and a repo does not have some of the specified branch' do
      let(:repo_a_path) do
        git_init('repo_a') do
          git_commit(time: '00:00:00', message: 'master 1')
          git_commit(time: '00:01:00', message: 'master 2')
          git_commit(time: '00:02:00', message: 'master 3 / maintenance branching')

          git('checkout -b maintenance')
          git_commit(time: '00:03:00', message: 'maintenance 1')
        end
      end

      let(:repo_b_path) do
        git_init('repo_b') do
          git_commit(time: '00:00:10', message: 'master 1')
          git_commit(time: '00:00:20', message: 'master 2')
          git_commit(time: '00:00:30', message: 'master 3')
        end
      end

      it 'imports commits without creating duplicate commits nor losing commits while keeping date order as much as possible' do
        repo_merger.merge_branches(['master', 'maintenance'], commit_message_transformer: commit_message_transformer)

        expect(commit_graph_of(monorepo_path, ['master', 'maintenance'])).to eq(<<~'END')
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
end
