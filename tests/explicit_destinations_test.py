#!/usr/bin/env python3
"""Exercise editing entry points against separate disposable repositories."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / 'common/bin/.bin'


class DestinationTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix='dotfiles-writer-test-'))
        self.home = self.root / 'home'
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_AUTHOR_NAME='Test', GIT_COMMITTER_NAME='Test',
                        GIT_AUTHOR_EMAIL='test@example.invalid',
                        GIT_COMMITTER_EMAIL='test@example.invalid')
        self.layers = {}
        for name in ('base', 'company', 'project'):
            repo = self.root / name
            repo.mkdir()
            for relative in ('common/shellutil/.shellinclude/path_additions.sh',
                             'common/alias/.shellinclude/aliases.sh'):
                path = repo / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('# fixture\n')
            self.git(repo, 'init', '-q')
            self.git(repo, 'add', '.')
            self.git(repo, 'commit', '-qm', 'fixture')
            self.layers[name] = repo
        remote = self.root / 'project-remote.git'
        subprocess.run(['git', 'init', '-q', '--bare', str(remote)], env=self.env, check=True)
        self.git(self.layers['project'], 'remote', 'add', 'origin', str(remote))
        (self.layers['company'] / 'escape').symlink_to(self.layers['base'])

    def git(self, repo, *args):
        return subprocess.run(['git', '-C', str(repo), *args], env=self.env,
                              text=True, capture_output=True, check=True).stdout.strip()

    def call(self, script, *args):
        return subprocess.run(['zsh', '-f', str(BIN / script), *map(str, args)],
                              env=self.env, text=True, capture_output=True)

    def test_explicit_destinations_and_mismatch(self):
        path_rel = 'common/shellutil/.shellinclude/path_additions.sh'
        alias_rel = 'common/alias/.shellinclude/aliases.sh'
        cases = [('add_to_path.sh', path_rel, [self.home / 'private-tools']),
                 ('add_function_for_cmd.sh', alias_rel, ['fixture_cmd', 'print fixture'])]
        for script, relative, args in cases:
            with self.subTest(script=script):
                snapshots = {name: (repo / relative).read_bytes()
                             for name, repo in self.layers.items()}
                heads = {name: self.git(repo, 'rev-parse', 'HEAD')
                         for name, repo in self.layers.items()}
                states = {name: self.git(repo, 'status', '--porcelain')
                          for name, repo in self.layers.items()}
                mismatch = self.call(script, '--layer-root', self.layers['company'],
                                     '--file', self.layers['base'] / relative, *args)
                self.assertNotEqual(mismatch.returncode, 0)
                escaped = self.call(script, '--no-git', '--layer-root', self.layers['company'],
                                    '--file', self.layers['company'] / 'escape' / relative, *args)
                self.assertNotEqual(escaped.returncode, 0)
                ambiguous = self.call(script, *args)
                self.assertNotEqual(ambiguous.returncode, 0)
                preview = self.call(script, '--no-git', '--dry-run', '--layer-root',
                                    self.layers['project'], *args)
                self.assertEqual(preview.returncode, 0, preview.stderr)
                git_preview = self.call(script, '--dry-run', '--layer-root',
                                        self.layers['project'], *args)
                self.assertEqual(git_preview.returncode, 0, git_preview.stderr)
                self.assertIn('Would stage and commit', git_preview.stdout)
                refs = subprocess.run(['git', '--git-dir', str(self.root / 'project-remote.git'),
                                       'for-each-ref'], env=self.env, text=True,
                                      capture_output=True, check=True)
                self.assertEqual(refs.stdout, '')
                for name, repo in self.layers.items():
                    self.assertEqual((repo / relative).read_bytes(), snapshots[name])
                    self.assertEqual(self.git(repo, 'rev-parse', 'HEAD'), heads[name])
                    self.assertEqual(self.git(repo, 'status', '--porcelain'), states[name])
                saved = self.call(script, '--no-git', '--layer-root', self.layers['company'], *args)
                self.assertEqual(saved.returncode, 0, saved.stderr)
                self.assertNotEqual((self.layers['company'] / relative).read_bytes(),
                                    snapshots['company'])
                self.assertEqual((self.layers['base'] / relative).read_bytes(), snapshots['base'])
                self.assertEqual((self.layers['project'] / relative).read_bytes(), snapshots['project'])
                saved_project = self.call(script, '--no-git', '--layer-root',
                                          self.layers['project'], *args)
                self.assertEqual(saved_project.returncode, 0, saved_project.stderr)
                self.assertNotEqual((self.layers['project'] / relative).read_bytes(),
                                    snapshots['project'])
                for name, repo in self.layers.items():
                    self.assertEqual(self.git(repo, 'rev-parse', 'HEAD'), heads[name])
                    self.assertEqual(self.git(repo, 'diff', '--cached', '--name-only'), '')


if __name__ == '__main__':
    unittest.main()
