#!/usr/bin/env python3
"""Exercise editing entry points against separate disposable repositories.

Every run gets a private HOME, ZDOTDIR and XDG directories inside the fixture,
so no caller startup file or source registry is read.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / 'common/bin/.bin'
PATH_REL = 'common/shellutil/.shellinclude/path_additions.sh'
ALIAS_REL = 'common/alias/.shellinclude/aliases.sh'


def zz_relative(script, source):
    if script == 'add_to_path.sh':
        return f'common/shellutil/.shellinclude/zz-{source}-paths.sh'
    return f'common/alias/.shellinclude/zz-{source}-aliases.sh'


def standard_relative(script):
    return PATH_REL if script == 'add_to_path.sh' else ALIAS_REL


class DestinationTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix='dotfiles-writer-test-')).resolve()
        self.addCleanup(shutil.rmtree, self.root)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.xdg_config = self.root / 'xdg-config'
        self.registry = self.xdg_config / 'dotfiletracker/config'
        self.registry.parent.mkdir(parents=True)
        # Only the tool search path is inherited: HOME, startup files, every
        # XDG directory and Git configuration point into the fixture.
        self.env = {
            'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
            'TMPDIR': os.environ.get('TMPDIR', '/tmp'),
            'LC_ALL': 'C',
            'HOME': str(self.home), 'ZDOTDIR': str(self.home),
            'XDG_CONFIG_HOME': str(self.xdg_config),
            'XDG_DATA_HOME': str(self.root / 'xdg-data'),
            'XDG_CACHE_HOME': str(self.root / 'xdg-cache'),
            'XDG_STATE_HOME': str(self.root / 'xdg-state'),
            'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': os.devnull,
            'GIT_AUTHOR_NAME': 'Test', 'GIT_COMMITTER_NAME': 'Test',
            'GIT_AUTHOR_EMAIL': 'test@example.invalid',
            'GIT_COMMITTER_EMAIL': 'test@example.invalid',
        }
        self.layers = {}
        for name in ('base', 'company', 'project'):
            repo = self.root / name
            repo.mkdir()
            for relative in (PATH_REL, ALIAS_REL):
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

    def test_nested_repository_is_a_different_layer(self):
        outer = self.layers['company']
        project = self.layers['project']
        nested = outer / 'nested-project'
        project.rename(nested)
        remote = self.root / 'project-remote.git'
        head = self.git(nested, 'rev-parse', 'HEAD')
        outer_head = self.git(outer, 'rev-parse', 'HEAD')
        outer_status = self.git(outer, 'status', '--porcelain')
        cases = [
            ('add_to_path.sh', PATH_REL, [self.home / 'private-tools']),
            ('add_function_for_cmd.sh', ALIAS_REL, ['fixture_cmd', 'print fixture']),
        ]
        for script, relative, args in cases:
            target = nested / relative
            original = target.read_bytes()
            for flags in ([], ['--dry-run'], ['--no-git']):
                with self.subTest(script=script, flags=flags):
                    result = self.call(script, *flags, '--layer-root', outer,
                                       '--file', target, *args)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('different Git repository', result.stderr)
                    self.assertEqual(target.read_bytes(), original)
                    self.assertEqual(self.git(nested, 'status', '--porcelain'), '')
                    self.assertEqual(self.git(nested, 'rev-parse', 'HEAD'), head)
                    self.assertEqual(self.git(outer, 'status', '--porcelain'), outer_status)
                    self.assertEqual(self.git(outer, 'rev-parse', 'HEAD'), outer_head)
                    self.assertEqual(self.git(remote, 'for-each-ref'), '')
            result = self.call(script, '--dry-run', '--layer-root', nested, *args)
            self.assertEqual(result.returncode, 0, result.stderr)

    def git(self, repo, *args):
        return subprocess.run(['git', '-C', str(repo), *args], env=self.env,
                              text=True, capture_output=True, check=True).stdout.strip()

    def call(self, script, *args, **kwargs):
        return self.run_writer(BIN / script, *args, **kwargs)

    def run_writer(self, path, *args, cwd=None, env=None, startup=False):
        # startup=True drops -f, so zsh reads the fixture ZDOTDIR/.zshenv.
        flags = [] if startup else ['-f']
        return subprocess.run(['zsh', *flags, str(path), *map(str, args)],
                              env=self.env if env is None else env,
                              cwd=self.root if cwd is None else cwd,
                              stdin=subprocess.DEVNULL, text=True,
                              capture_output=True, timeout=60)

    def write_registry(self, *lines, newline=True):
        text = '\n'.join(str(line) for line in lines)
        self.registry.write_text(text + ('\n' if newline and lines else ''))

    def args_for(self, script, label='fixture'):
        if script == 'add_to_path.sh':
            return [self.home / f'{label}-tools']
        return [f'{label}_cmd', f'print {label}']

    def make_source(self, name, files, *, remote=False, writers=False):
        """Create a committed source repository on branch main."""
        repo = self.root / name
        repo.mkdir()
        for relative in files:
            path = repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'# {name} {Path(relative).name}\n')
        if writers:
            library = repo / 'common/bin/.bin/lib'
            library.mkdir(parents=True)
            for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
                shutil.copy2(BIN / script, repo / 'common/bin/.bin' / script)
            shutil.copy2(BIN / 'lib/dotfiles_edit_lib.zsh', library)
        self.git(repo, 'init', '-q')
        self.git(repo, 'symbolic-ref', 'HEAD', 'refs/heads/main')
        self.git(repo, 'add', '.')
        self.git(repo, 'commit', '-qm', 'fixture')
        if remote:
            bare = self.root / f'{name}-remote.git'
            self.git(self.root, 'init', '-q', '--bare', str(bare))
            self.git(repo, 'remote', 'add', 'origin', str(bare))
            self.git(repo, 'push', '-q', 'origin', 'main')
        return repo

    def state(self, *repos, registry=False):
        """Files, HEAD, index state and remote refs of each repository."""
        result = {}
        for repo in repos:
            files = {}
            for directory, subdirs, names in os.walk(repo):
                subdirs[:] = [d for d in subdirs if d != '.git']
                for name in names:
                    path = Path(directory) / name
                    files[str(path.relative_to(repo))] = (
                        os.readlink(path) if path.is_symlink() else path.read_bytes())
            remotes = {}
            for remote in self.git(repo, 'remote').split():
                url = self.git(repo, 'remote', 'get-url', remote)
                remotes[remote] = self.git(url, 'for-each-ref')
            result[str(repo)] = (files, self.git(repo, 'rev-parse', 'HEAD'),
                                 self.git(repo, 'status', '--porcelain'),
                                 self.git(repo, 'diff', '--cached', '--name-only'), remotes)
        if registry:
            result['registry'] = self.registry.read_bytes()
        return result

    def two_sources(self):
        """A generic source holding the writers, and a personal source."""
        generic = self.make_source('generic', [PATH_REL, ALIAS_REL], remote=True, writers=True)
        personal = self.make_source(
            'personal',
            [PATH_REL, ALIAS_REL, zz_relative('add_to_path.sh', 'personal'),
             zz_relative('add_function_for_cmd.sh', 'personal')],
            remote=True)
        self.write_registry(f'source.generic={generic}', f'source.personal={personal}')
        return generic, personal

    def test_explicit_destinations_and_mismatch(self):
        cases = [('add_to_path.sh', PATH_REL, [self.home / 'private-tools']),
                 ('add_function_for_cmd.sh', ALIAS_REL, ['fixture_cmd', 'print fixture'])]
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

    def test_source_usage_errors(self):
        """Repeated, empty, invalid or combined --source is a usage error."""
        generic, personal = self.two_sources()
        before = self.state(generic, personal, registry=True)
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            for options, text in [
                (['--source', 'personal', '--source', 'generic'], 'more than once'),
                (['--source=personal', '--source', 'personal'], 'more than once'),
                (['--source', ''], 'source is empty'),
                (['--source='], 'source is empty'),
                (['--source', 'personal=' + str(personal)], 'invalid source ID'),
                (['--source=a=b'], 'invalid source ID'),
                (['--source', '-personal'], 'invalid source ID'),
                (['--source', 'pers onal'], 'invalid source ID'),
                (['--source', 'personal', '--layer-root', personal], 'cannot be combined'),
                (['--layer-root', personal, '--source', 'personal'], 'cannot be combined'),
                (['--layer-root', personal, '--source=personal'], 'cannot be combined'),
            ]:
                for flags in ([], ['--dry-run'], ['--no-git']):
                    with self.subTest(script=script, options=options, flags=flags):
                        result = self.call(script, *flags, *options, *self.args_for(script))
                        self.assertEqual(result.returncode, 2, result.stderr)
                        self.assertIn(text, result.stderr)
                        self.assertEqual(self.state(generic, personal, registry=True), before)
            with self.subTest(script=script, options='--source without a value'):
                result = self.call(script, '--source')
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn('needs a source ID', result.stderr)

    def test_no_implicit_destination_with_registry(self):
        """I1: a registry never selects a source by itself."""
        generic, personal = self.two_sources()
        before = self.state(generic, personal, registry=True)
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            for flags in ([], ['--dry-run'], ['--no-git'], ['--dry-run', '--no-git']):
                with self.subTest(script=script, flags=flags):
                    result = self.call(script, *flags, *self.args_for(script))
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn('specify --layer-root, --source or --file', result.stderr)
                    self.assertEqual(self.state(generic, personal, registry=True), before)

    def test_source_selects_only_the_registered_root(self):
        """I2: stowed from generic, --source writes, commits and pushes only there."""
        generic, personal = self.two_sources()
        stowed = self.home / '.bin'
        stowed.mkdir()
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            (stowed / script).symlink_to(generic / 'common/bin/.bin' / script)
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            for selected, other, relative in (
                    (personal, generic, zz_relative(script, 'personal')),
                    (generic, personal, standard_relative(script))):
                with self.subTest(script=script, source=selected.name):
                    other_before = self.state(other)
                    head = self.git(selected, 'rev-parse', 'HEAD')
                    original = (selected / relative).read_bytes()
                    result = self.run_writer(stowed / script, '--source', selected.name,
                                             *self.args_for(script, selected.name))
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(f'Appended to {selected / relative}', result.stdout)
                    self.assertNotEqual((selected / relative).read_bytes(), original)
                    self.assertEqual(self.git(selected, 'rev-parse', 'HEAD~1'), head)
                    self.assertEqual(
                        self.git(selected, 'diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD'),
                        relative)
                    self.assertEqual(self.git(selected, 'status', '--porcelain'), '')
                    remote = self.root / f'{selected.name}-remote.git'
                    self.assertEqual(self.git(remote, 'rev-parse', 'main'),
                                     self.git(selected, 'rev-parse', 'HEAD'))
                    self.assertEqual(self.state(other), other_before)

    def test_source_default_includes(self):
        """zz-<ID>-* wins, the standard include is the fallback, else refusal."""
        both = self.make_source('both', [PATH_REL, ALIAS_REL, zz_relative('add_to_path.sh', 'both'),
                                         zz_relative('add_function_for_cmd.sh', 'both')])
        standard = self.make_source('standard', [PATH_REL, ALIAS_REL])
        only_zz = self.make_source('only-zz', [zz_relative('add_to_path.sh', 'only-zz'),
                                               zz_relative('add_function_for_cmd.sh', 'only-zz')])
        # A zz file named after another ID is not this source's include.
        neither = self.make_source('neither', [zz_relative('add_to_path.sh', 'other'),
                                               zz_relative('add_function_for_cmd.sh', 'other')])
        self.write_registry(*(f'source.{repo.name}={repo}'
                              for repo in (both, standard, only_zz, neither)))
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            for repo, relative in ((both, zz_relative(script, 'both')),
                                   (standard, standard_relative(script)),
                                   (only_zz, zz_relative(script, 'only-zz'))):
                with self.subTest(script=script, source=repo.name):
                    result = self.call(script, '--dry-run', '--no-git', '--source', repo.name,
                                       *self.args_for(script))
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(f'Would append to {repo / relative}:', result.stdout)
            with self.subTest(script=script, source='neither'):
                before = self.state(neither)
                result = self.call(script, '--no-git', '--source', 'neither',
                                   *self.args_for(script))
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(str(neither / zz_relative(script, 'neither')), result.stderr)
                self.assertIn(str(neither / standard_relative(script)), result.stderr)
                self.assertIn('--file', result.stderr)
                self.assertEqual(self.state(neither), before)
            with self.subTest(script=script, layer_root='both'):
                result = self.call(script, '--dry-run', '--no-git', '--layer-root', both,
                                   *self.args_for(script))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Would append to {both / standard_relative(script)}:',
                              result.stdout)
            with self.subTest(script=script, explicit_file='neither'):
                target = neither / zz_relative(script, 'other')
                result = self.call(script, '--dry-run', '--no-git', '--source', 'neither',
                                   '--file', target, *self.args_for(script))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Would append to {target}:', result.stdout)

    def test_registry_is_data(self):
        """I3: values are never evaluated, globbed or expanded beyond HOME."""
        decoy = self.root / 'workdir'
        decoy.mkdir()
        # A glob or a ~user / $OTHER expansion would turn these into
        # existing directories; every one must stay literal and missing.
        (decoy / 'only-directory').mkdir()
        other = self.root / 'other-dir'
        (other / 'dir').mkdir(parents=True)
        startup = self.root / 'startup'
        startup.mkdir()
        (startup / '.zshenv').write_text('setopt GLOB_SUBST SH_WORD_SPLIT\n')
        hostile_env = dict(self.env, ZDOTDIR=str(startup), OTHER=str(other))
        # The hostile options must really reach a zsh started without -f.
        probe = subprocess.run(['zsh', '-c', '[[ -o globsubst && -o shwordsplit ]]'],
                               env=hostile_env, cwd=decoy, stdin=subprocess.DEVNULL,
                               capture_output=True, text=True, timeout=30)
        self.assertEqual(probe.returncode, 0, probe.stderr)
        marker = self.root / 'MARKER'
        entries = ['"$(touch MARKER)"', "'$(touch MARKER)'", '$(touch MARKER)',
                   '`touch MARKER`', '$OTHER/dir', '${OTHER}/dir', '~root', '~root/',
                   '*', 'only-*', '$HOME/../other-dir/*', '~"/x"', '$HOMEX', '~x']
        layer = self.layers['company']
        before = self.state(layer)
        for entry in entries:
            self.write_registry(f'source.x={entry}')
            for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
                for startup_files in (False, True):
                    with self.subTest(entry=entry, script=script, startup=startup_files):
                        result = self.call(script, '--no-git', '--source', 'x',
                                           *self.args_for(script), cwd=decoy,
                                           env=hostile_env, startup=startup_files)
                        self.assertEqual(result.returncode, 1, result.stderr)
                        self.assertIn('source directory not found (x)', result.stderr)
                        self.assertFalse(marker.exists())
                        self.assertFalse((decoy / 'MARKER').exists())
                        self.assertFalse((self.home / 'MARKER').exists())
                        self.assertEqual(self.state(layer), before)
        # Positive control: only a leading ~, $HOME or ${HOME} expands.
        selected = self.make_source('home-source', [PATH_REL, ALIAS_REL])
        (self.home / 'linked').symlink_to(selected)
        for entry in ('~/linked', '$HOME/linked', '${HOME}/linked', '"~/linked"',
                      "'$HOME/linked'", f'  {selected}  '):
            self.write_registry(f'  source.home = {entry}', newline=False)
            for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
                for startup_files in (False, True):
                    with self.subTest(entry=entry, script=script, startup=startup_files):
                        result = self.call(script, '--dry-run', '--no-git', '--source', 'home',
                                           *self.args_for(script), cwd=decoy,
                                           env=hostile_env, startup=startup_files)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIn(f'Would append to {selected / standard_relative(script)}:',
                                      result.stdout)

    def test_malformed_registry_fails_closed(self):
        """I4: every malformed registry exits non-zero and changes nothing."""
        first = self.make_source('first', [PATH_REL, ALIAS_REL], remote=True)
        second = self.make_source('second', [PATH_REL, ALIAS_REL], remote=True)
        link = self.root / 'first-link'
        link.symlink_to(first)
        malformed = {
            'mixed legacy and source': ([f'dotfiles_dir={first}', f'source.first={first}'],
                                        'cannot mix'),
            'source before legacy': ([f'source.first={first}', f'{second}'], 'cannot mix'),
            'duplicate ID': ([f'source.first={first}', f'source.first={second}'],
                             'duplicate source ID'),
            'repeated physical root': ([f'source.first={first}', f'source.second={link}'],
                                       'repeated physical source root'),
            'missing directory': ([f'source.first={self.root / "absent"}'],
                                  'source directory not found'),
            'unmatched quote': ([f'source.first="{first}'], 'unmatched source path quote'),
            'mismatched quotes': ([f'source.first="{first}\''], 'unmatched source path quote'),
            'lone quote': (['source.first="'], 'unmatched source path quote'),
            'empty path': (['source.first='], 'empty source path'),
            'empty quoted path': (['source.first=""'], 'empty source path'),
            'invalid ID': ([f'source.bad.id={first}'], 'invalid source ID'),
            'empty ID': ([f'source.={first}'], 'invalid source ID'),
            'ID with a leading dash': ([f'source.-first={first}'], 'invalid source ID'),
            'empty file': ([], 'no source registered'),
            'comment-only file': (['# comment', '   ', '\t# indented'], 'no source registered'),
            'unrelated keys only': (['theme=dark'], 'no source registered'),
        }
        before = self.state(first, second)
        for label, (lines, text) in malformed.items():
            self.write_registry(*lines)
            for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
                for flags in ([], ['--dry-run'], ['--no-git']):
                    with self.subTest(case=label, script=script, flags=flags):
                        result = self.call(script, *flags, '--source', 'first',
                                           *self.args_for(script))
                        self.assertEqual(result.returncode, 1, result.stderr)
                        self.assertIn(text, result.stderr)
                        self.assertEqual(self.state(first, second), before)
        self.registry.unlink()
        self.registry.mkdir()
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            with self.subTest(case='registry is a directory', script=script):
                result = self.call(script, '--no-git', '--source', 'first', *self.args_for(script))
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn('not a readable file', result.stderr)
        self.registry.rmdir()
        refusals = {
            'registry missing': (None, 'requires a source registry'),
            'legacy dotfiles_dir': ([f'dotfiles_dir={first}'], 'requires stack configuration'),
            'legacy dotfile_dir': ([f'dotfile_dir="{first}"'], 'requires stack configuration'),
            'legacy bare path': ([str(first)], 'requires stack configuration'),
            'unknown ID': ([f'source.second={second}'], 'unknown destination source: first'),
        }
        for label, (lines, text) in refusals.items():
            if lines is None:
                self.assertFalse(self.registry.exists())
            else:
                self.write_registry(*lines)
            for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
                for flags in ([], ['--dry-run'], ['--no-git']):
                    with self.subTest(case=label, script=script, flags=flags):
                        result = self.call(script, *flags, '--source', 'first',
                                           *self.args_for(script))
                        self.assertEqual(result.returncode, 1, result.stderr)
                        self.assertIn(text, result.stderr)
                        self.assertEqual(self.state(first, second), before)

    def test_symlink_parent_paths_resolve_like_cd(self):
        """LINK/../NAME resolves like cd -L + pwd -P, never to a missing path."""
        deep = self.root / 'deep'
        (deep / 'x').mkdir(parents=True)
        (self.root / 'linkx').symlink_to(deep / 'x')
        physical = self.make_source('deep/lexsrc', [PATH_REL, ALIAS_REL])
        spelled = f'{self.root}/linkx/../lexsrc'
        # The lexical form is missing; only the physical one exists.
        self.assertFalse((self.root / 'lexsrc').exists())
        self.assertTrue(Path(spelled).is_dir())
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            target = physical / standard_relative(script)
            self.write_registry(f'source.x={spelled}')
            with self.subTest(script=script, case='--source'):
                result = self.call(script, '--dry-run', '--no-git', '--source', 'x',
                                   *self.args_for(script))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Would append to {target}:', result.stdout)
            with self.subTest(script=script, case='repeated physical root'):
                self.write_registry(f'source.plain={physical}', f'source.x={spelled}')
                before = self.state(physical)
                result = self.call(script, '--no-git', '--source', 'x', *self.args_for(script))
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn('repeated physical source root (x)', result.stderr)
                self.assertEqual(self.state(physical), before)
            with self.subTest(script=script, case='--layer-root'):
                self.write_registry(f'source.x={spelled}')
                result = self.call(script, '--dry-run', '--no-git', '--layer-root', spelled,
                                   *self.args_for(script))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Would append to {target}:', result.stdout)
        # --file: the physical target is used; inside a root it must stay there.
        elsewhere = self.root / 'elsewhere'
        (elsewhere / 'sub').mkdir(parents=True)
        outside = elsewhere / 'outside.sh'
        outside.write_text('# outside\n')
        (physical / 'link').symlink_to(elsewhere / 'sub')
        spelled_file = f'{physical}/link/../outside.sh'
        self.assertFalse((physical / 'outside.sh').exists())
        self.write_registry(f'source.x={physical}')
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            for destination in (['--layer-root', physical], ['--source', 'x']):
                with self.subTest(script=script, destination=destination[0]):
                    result = self.call(script, '--no-git', *destination, '--file', spelled_file,
                                       *self.args_for(script))
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn('outside the selected layer root', result.stderr)
                    self.assertEqual(outside.read_text(), '# outside\n')
                    self.assertFalse((physical / 'outside.sh').exists())
            with self.subTest(script=script, destination='--file alone'):
                result = self.call(script, '--dry-run', '--no-git', '--file', spelled_file,
                                   *self.args_for(script))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Would append to {outside}:', result.stdout)

    def test_physically_missing_names_are_refused(self):
        """A name that fails kernel resolution is refused, even if its lexical form exists."""
        source = self.make_source('dsrc', [PATH_REL, ALIAS_REL, 'f.sh'])
        (self.root / 'dangle').symlink_to(self.root / 'nonexistent')
        (source / 'dangle').symlink_to(self.root / 'nonexistent')
        # LINK/../LINK2/DIR: lexically linky/z (exists), physically real/linky/z (missing).
        (self.root / 'real/x').mkdir(parents=True)
        (self.root / 'linkx').symlink_to(self.root / 'real/x')
        (self.root / 'real/y2').mkdir(parents=True)
        (self.root / 'linky').symlink_to(self.root / 'real/y2')
        chained = self.make_source('real/y2/z', [PATH_REL, ALIAS_REL])
        dangling_root = f'{self.root}/dangle/../dsrc'
        chained_root = f'{self.root}/linkx/../linky/z'
        dangling_file = f'{source}/dangle/../f.sh'
        for spelled in (dangling_root, chained_root, dangling_file):
            self.assertFalse(os.path.exists(spelled), spelled)
        self.assertTrue(Path(os.path.normpath(dangling_root)).is_dir())
        self.assertTrue(Path(os.path.normpath(chained_root)).is_dir())
        self.assertTrue(Path(os.path.normpath(dangling_file)).is_file())
        before = self.state(source, chained)
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            for spelled in (dangling_root, chained_root):
                for flags in ([], ['--dry-run'], ['--no-git']):
                    with self.subTest(script=script, source=spelled, flags=flags):
                        self.write_registry(f'source.x={spelled}')
                        result = self.call(script, *flags, '--source', 'x', *self.args_for(script))
                        self.assertEqual(result.returncode, 1, result.stderr)
                        self.assertIn('source directory not found (x)', result.stderr)
                        self.assertEqual(self.state(source, chained), before)
            self.registry.unlink()
            for options, text in (
                    (['--layer-root', dangling_root], 'layer root must be an existing directory'),
                    (['--layer-root', chained_root], 'layer root must be an existing directory'),
                    (['--file', dangling_file], 'file not found'),
                    (['--layer-root', source, '--file', dangling_file], 'file not found')):
                for flags in ([], ['--dry-run'], ['--no-git']):
                    with self.subTest(script=script, options=options, flags=flags):
                        result = self.call(script, *flags, *options, *self.args_for(script))
                        self.assertEqual(result.returncode, 1, result.stderr)
                        self.assertIn(text, result.stderr)
                        self.assertEqual(self.state(source, chained), before)

    def include_tree(self, relative):
        """A directory with both standard includes, outside any repository."""
        tree = self.root / relative
        for include in (PATH_REL, ALIAS_REL):
            path = tree / include
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('# include\n')
        return tree

    def restrict(self, path, mode):
        """Set a mode and restore it before the fixture is removed."""
        self.addCleanup(os.chmod, path, 0o700)
        os.chmod(path, mode)

    def bash_cd(self, name, cwd, env):
        """The root Bash gives for [[ -d NAME ]] && cd -- NAME && pwd -P, or None."""
        result = subprocess.run(
            ['bash', '-c', '[[ -d "$1" ]] && CDPATH= cd -- "$1" && pwd -P && printf x',
             'bash_cd', name],
            env=env, cwd=cwd, stdin=subprocess.DEVNULL, text=True,
            capture_output=True, timeout=30)
        if result.returncode != 0:
            return None
        resolved = result.stdout[:-2]
        # Bash keeps a leading // of NAME in its logical directory. The kernel,
        # and so the writers, name the same directory with one slash.
        if resolved.startswith('//') and not resolved.startswith('///'):
            resolved = resolved[1:]
        return resolved

    def test_directory_names_resolve_like_bash_cd(self):
        """A root is what Bash cd -- NAME && pwd -P gives, or it is refused."""
        tree = self.root / 'tree'
        (tree / 'real/x').mkdir(parents=True)
        (tree / 'linkx').symlink_to(tree / 'real/x')
        # Lexical and physical forms both exist: Bash takes the lexical one.
        self.include_tree('tree/both')
        self.include_tree('tree/real/both')
        # Only the physical form exists.
        self.include_tree('tree/real/only')
        # Lexically tree/mixed/z (through a link), but tree/mixed/qq is
        # missing there, so Bash has no lexical path and goes physically.
        self.include_tree('tree/real/y2/z')
        (tree / 'mixed').symlink_to(tree / 'real/y2')
        (tree / 'linky').symlink_to(tree / 'real/y2')
        (tree / 'real/mixed/qq').mkdir(parents=True)
        self.include_tree('tree/real/mixed/z')
        # The lexical form exists but cannot be entered.
        (tree / 'locked').mkdir()
        self.include_tree('tree/real/locked')
        (tree / 'dangle').symlink_to(tree / 'nonexistent')
        (tree / 'loop').symlink_to('loop')
        (tree / 'afile').write_text('# file\n')
        (tree / 'filelink').symlink_to(tree / 'afile')
        self.include_tree('tree/rel/target')
        (tree / 'rel/rlink').symlink_to('target')
        self.include_tree('tree/two words')
        self.include_tree('tree/tab\tdir')
        # A glob would turn the first name into the second.
        self.include_tree('tree/gl*b[a]?')
        self.include_tree('tree/glxbax')
        self.include_tree('tree/-')
        self.include_tree('tree/+1')
        self.include_tree('tree/-2')
        for name in ('nox', 'none', 'nor', 'enter', 'noxparent/child'):
            self.include_tree(f'tree/perm/{name}')
        self.restrict(tree / 'locked', 0o000)
        self.restrict(tree / 'perm/nox', 0o600)
        self.restrict(tree / 'perm/none', 0o000)
        self.restrict(tree / 'perm/nor', 0o300)
        self.restrict(tree / 'perm/enter', 0o100)
        self.restrict(tree / 'perm/noxparent', 0o600)
        logical = dict(self.env, PWD=str(tree / 'linkx'))
        shapes = [(name, tree, self.env) for name in (
            f'{tree}/both', f'{tree}/both/', f'{tree}/both/.', f'{tree}/both//',
            f'{tree}//real//both', f'{tree}/./both/./.', f'/{tree}/both',
            f'{tree}/linkx', f'{tree}/linkx/', f'{tree}/linkx/..',
            f'{tree}/linkx/../both', f'{tree}/linkx/../only',
            f'{tree}/linkx/../../both', f'{tree}/linkx/..//../tree/both',
            f'{tree}/real/x/..//../both', f'{tree}/real/x/../..//real/../both',
            f'{tree}/linkx/../mixed/qq/../z', f'{tree}/linkx/../mixed/z',
            f'{tree}/linkx/../linky/z', f'{tree}/mixed/z', f'{tree}/mixed/../both',
            f'{tree}/linkx/../locked', f'{tree}/locked', f'{tree}/locked/..',
            f'{tree}/dangle', f'{tree}/dangle/../both', f'{tree}/loop',
            f'{tree}/loop/../both', f'{tree}/afile', f'{tree}/afile/../both',
            f'{tree}/filelink', f'{tree}/missing', f'{tree}/missing/../both',
            f'{tree}/rel/rlink', f'{tree}/rel/rlink/../target', f'{tree}/rel/rlink/..',
            f'{tree}/two words', f'{tree}/tab\tdir', f'{tree}/gl*b[a]?', f'{tree}/gl*',
            f'{tree}/perm/nox', f'{tree}/perm/none', f'{tree}/perm/nor',
            f'{tree}/perm/enter', f'{tree}/perm/noxparent/child',
            f'{tree}/perm/nox/..', f'{tree}/perm/nox/../nor',
            f'{tree}/both' + '/.' * 1900, f'{tree}/both' + '/.' * 2100,
            f'{tree}/' + 'n' * 256,
            'both', './both', 'linkx/../both', 'linkx/../only', 'real/x/../../both',
            '-', './-', '+1', '-2', '.', '..', 'both/..', 'missing')]
        shapes += [(name, tree / 'linkx', logical) for name in (
            '..', '../both', '../only', '../../tree/both', '.', '../x', '../real/both')]
        expected = {}
        for name, cwd, env in shapes:
            expected[(name, str(cwd))] = self.bash_cd(name, cwd, env)

        def root_of(name, cwd=tree):
            return expected[(name, str(cwd))]

        # The fixture is only meaningful if Bash decides these as designed.
        self.assertEqual(root_of(f'{tree}/linkx/../both'), f'{tree}/both')
        self.assertEqual(root_of(f'{tree}/linkx/../only'), f'{tree}/real/only')
        self.assertEqual(root_of(f'{tree}/linkx/../mixed/qq/../z'), f'{tree}/real/mixed/z')
        self.assertEqual(root_of(f'{tree}/real/x/..//../both'), f'{tree}/both')
        self.assertEqual(root_of(f'/{tree}/both'), f'{tree}/both')
        self.assertEqual(root_of('../both', tree / 'linkx'), f'{tree}/both')
        self.assertEqual(root_of('../only', tree / 'linkx'), f'{tree}/real/only')
        self.assertEqual(root_of(f'{tree}/both' + '/.' * 1900), f'{tree}/both')
        for name in (f'{tree}/dangle/../both', f'{tree}/linkx/../linky/z', f'{tree}/loop',
                     f'{tree}/afile', f'{tree}/both' + '/.' * 2100, f'{tree}/gl*', '-'):
            self.assertIsNone(root_of(name), name)
        if os.geteuid() != 0:
            self.assertEqual(root_of(f'{tree}/linkx/../locked'), f'{tree}/real/locked')
            self.assertEqual(root_of(f'{tree}/perm/nor'), f'{tree}/perm/nor')
            self.assertEqual(root_of(f'{tree}/perm/enter'), f'{tree}/perm/enter')
            for name in (f'{tree}/perm/nox', f'{tree}/perm/none', f'{tree}/locked',
                         f'{tree}/perm/noxparent/child'):
                self.assertIsNone(root_of(name), name)
        accepted = sum(root is not None for root in expected.values())
        self.assertGreater(accepted, 30)
        self.assertGreater(len(expected) - accepted, 15)

        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            relative = standard_relative(script)
            scans = script == 'add_function_for_cmd.sh'
            for name, cwd, env in shapes:
                root = expected[(name, str(cwd))]
                include = None if root is None else f'{root}/{relative}'
                short = name if len(name) < 200 else f'{name[:80]}...({len(name)})'
                with self.subTest(script=script, option='--layer-root', name=short, cwd=cwd.name):
                    if self.registry.exists():
                        self.registry.unlink()
                    result = self.call(script, '--dry-run', '--no-git', '--layer-root', name,
                                       *self.args_for(script), cwd=cwd, env=env)
                    if root is None:
                        self.assertEqual(result.returncode, 1, result.stdout)
                        self.assertIn('layer root must be an existing directory', result.stderr)
                    elif os.path.isfile(include):
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIn(f'Would append to {include}:', result.stdout)
                    else:
                        self.assertEqual(result.returncode, 1, result.stdout)
                        self.assertIn(f'file not found: {include}', result.stderr)
                with self.subTest(script=script, option='--source', name=short, cwd=cwd.name):
                    self.write_registry(f'source.x={name}')
                    result = self.call(script, '--dry-run', '--no-git', '--source', 'x',
                                       *self.args_for(script), cwd=cwd, env=env)
                    if root is None:
                        exists = os.path.isdir(os.path.join(cwd, name))
                        text = 'cannot be entered (x)' if exists else 'not found (x)'
                        self.assertEqual(result.returncode, 1, result.stdout)
                        self.assertIn(f'source directory {text}: {name}', result.stderr)
                    elif scans and not os.access(root, os.R_OK):
                        self.assertEqual(result.returncode, 1, result.stdout)
                        self.assertIn(f'source directory is not readable: {root}', result.stderr)
                    elif os.path.isfile(include):
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIn(f'Would append to {include}:', result.stdout)
                    else:
                        self.assertEqual(result.returncode, 1, result.stdout)
                        self.assertIn('has no include', result.stderr)
                        self.assertIn(f'nor {include} exists', result.stderr)

    def test_unsearchable_and_unreadable_paths_fail_closed(self):
        """A root that cannot be entered, or scanned, and an unreadable FILE are refused."""
        if os.geteuid() == 0:
            self.skipTest('permission bits do not restrict the superuser')
        target = self.make_source('target', [PATH_REL, ALIAS_REL, 'sub/f.sh', 'plain.sh'],
                                  remote=True)
        locked = self.make_source('locked', [PATH_REL, ALIAS_REL])
        self.addCleanup(os.chmod, locked, 0o700)
        self.addCleanup(os.chmod, target / 'sub', 0o700)
        self.addCleanup(os.chmod, target / 'plain.sh', 0o600)
        before = self.state(target, locked)
        scripts = ('add_to_path.sh', 'add_function_for_cmd.sh')
        all_flags = ([], ['--dry-run'], ['--no-git'])

        def refused(script, flags, options, text):
            result = self.call(script, *flags, *options, *self.args_for(script))
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn(text, result.stderr)

        def unchanged():
            os.chmod(locked, 0o700)
            os.chmod(target / 'sub', 0o700)
            os.chmod(target / 'plain.sh', 0o600)
            self.assertEqual(self.state(target, locked), before)

        # No search permission: envmaker refuses the registry (its cd fails).
        for mode in (0o600, 0o000, 0o200, 0o400):
            for script in scripts:
                for flags in all_flags:
                    with self.subTest(mode=oct(mode), script=script, flags=flags):
                        os.chmod(locked, mode)
                        self.write_registry(f'source.x={locked}')
                        refused(script, flags, ['--source', 'x'],
                                f'source directory cannot be entered (x): {locked}')
                        # One bad entry invalidates the registry for every source.
                        self.write_registry(f'source.target={target}', f'source.x={locked}')
                        refused(script, flags, ['--source', 'target'],
                                f'source directory cannot be entered (x): {locked}')
                        self.registry.unlink()
                        refused(script, flags, ['--layer-root', locked],
                                'layer root must be an existing directory')
                        refused(script, flags, ['--file', locked / standard_relative(script)],
                                'file not found')
                        unchanged()
            # The scan of add_function_for_cmd.sh needs every registered root.
            for options in (['--layer-root', target],
                            ['--file', target / ALIAS_REL],
                            ['--layer-root', target, '--file', target / ALIAS_REL]):
                for registry in ([f'source.target={target}', f'source.x={locked}'],
                                 [f'dotfiles_dir={locked}']):
                    for flags in all_flags:
                        with self.subTest(mode=oct(mode), options=options[0], flags=flags,
                                          registry=registry[-1].split('=')[0]):
                            os.chmod(locked, mode)
                            self.write_registry(*registry)
                            refused('add_function_for_cmd.sh', flags, options,
                                    'the duplicate check cannot cover all sources')
                            unchanged()
        # Search permission without read permission: envmaker accepts the root,
        # but its shell files cannot be listed, so the scan refuses it.
        for mode in (0o300, 0o100):
            for registry in ([f'source.target={target}', f'source.x={locked}'],
                             [f'dotfiles_dir={locked}']):
                stack = registry[0].startswith('source.')
                destinations = [['--layer-root', target], ['--file', target / ALIAS_REL]]
                if stack:
                    destinations += [['--source', 'target'], ['--source', 'x']]
                for options in destinations:
                    for flags in all_flags:
                        with self.subTest(mode=oct(mode), options=options, flags=flags,
                                          stack=stack):
                            os.chmod(locked, mode)
                            self.write_registry(*registry)
                            refused('add_function_for_cmd.sh', flags, options,
                                    'the duplicate check cannot cover all sources: '
                                    f'source directory is not readable: {locked}')
                            unchanged()
            with self.subTest(mode=oct(mode), script='add_to_path.sh'):
                # No scan there: the root resolves exactly as in envmaker.
                os.chmod(locked, mode)
                self.write_registry(f'source.target={target}', f'source.x={locked}')
                result = self.call('add_to_path.sh', '--dry-run', '--no-git', '--source', 'x',
                                   *self.args_for('add_to_path.sh'))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Would append to {locked / PATH_REL}:', result.stdout)
                unchanged()
        self.registry.unlink()
        # FILE: its directory must be searchable and FILE itself readable.
        for script in scripts:
            for flags in all_flags:
                for destination in ([], ['--layer-root', target]):
                    for mode in (0o600, 0o000):
                        with self.subTest(script=script, flags=flags, directory=oct(mode),
                                          destination=destination[:1]):
                            os.chmod(target / 'sub', mode)
                            refused(script, flags, [*destination, '--file', target / 'sub/f.sh'],
                                    'file not found')
                            unchanged()
                    for mode in (0o000, 0o200):
                        with self.subTest(script=script, flags=flags, file=oct(mode),
                                          destination=destination[:1]):
                            os.chmod(target / 'plain.sh', mode)
                            refused(script, flags, [*destination, '--file', target / 'plain.sh'],
                                    'file is not readable')
                            unchanged()

    def test_source_file_stays_inside_the_selected_root(self):
        """I5: --source with --file narrows the destination, never widens it."""
        first = self.make_source('first', [PATH_REL, ALIAS_REL, 'common/extra/.shellinclude/extra.sh'])
        second = self.make_source('second', [PATH_REL, ALIAS_REL])
        (first / 'escape').symlink_to(second)
        nested = first / 'nested'
        shutil.move(str(self.make_source('nested-source', [PATH_REL, ALIAS_REL])), nested)
        self.write_registry(f'source.first={first}', f'source.second={second}')
        before = self.state(first, second, nested)
        for script in ('add_to_path.sh', 'add_function_for_cmd.sh'):
            relative = standard_relative(script)
            for target, text in ((second / relative, 'outside the selected layer root'),
                                 (first / 'escape' / relative, 'outside the selected layer root'),
                                 (nested / relative, 'different Git repository')):
                for flags in ([], ['--dry-run'], ['--no-git']):
                    with self.subTest(script=script, target=target, flags=flags):
                        result = self.call(script, *flags, '--source', 'first', '--file', target,
                                           *self.args_for(script))
                        self.assertEqual(result.returncode, 1, result.stderr)
                        self.assertIn(text, result.stderr)
                        self.assertEqual(self.state(first, second, nested), before)
            with self.subTest(script=script, target='inside'):
                target = first / 'common/extra/.shellinclude/extra.sh'
                result = self.call(script, '--dry-run', '--no-git', f'--file={target}',
                                   '--source=first', *self.args_for(script))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Would append to {target}:', result.stdout)


if __name__ == '__main__':
    unittest.main()
