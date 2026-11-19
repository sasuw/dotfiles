#!/usr/bin/env python3
"""Check source-local rule selection and base startup in disposable homes."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent


class StartupDiscoveryTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp(prefix='dotfiles-startup-test-'))
        (self.home / '.bin').mkdir()
        (self.home / '.shellinclude').mkdir()
        for name in ('.zshenv', '.zshrc', '.zshvars', '.zshversions'):
            (self.home / name).symlink_to(ROOT / 'common/zsh' / name)
        (self.home / '.bin/common.sh').symlink_to(ROOT / 'common/bin/.bin/common.sh')
        (self.home / '.bin/lib').symlink_to(ROOT / 'common/bin/.bin/lib')
        self.env = dict(os.environ, HOME=str(self.home), TERM='dumb')
        self.env.pop('DOTFILE_DIR', None)
        self.env.pop('ZDOTDIR', None)

    def shell(self, command, interactive=False):
        args = ['zsh', '-i' if interactive else '-c']
        if interactive:
            args.append('-c')
        result = subprocess.run(args + [command], env=self.env, text=True,
                                capture_output=True, check=True)
        return result.stdout.strip().splitlines()[-1]

    def test_default_hook_and_caller_override(self):
        self.assertEqual(self.shell('print -r -- $DOTFILE_DIR'), str(self.home / 'dotfiles'))
        hook = self.home / '.shellinclude/00-personal-root.sh'
        hook.write_text('DOTFILE_DIR="$HOME/custom root"\n')
        self.assertEqual(self.shell('print -r -- $DOTFILE_DIR'), str(self.home / 'custom root'))
        self.env['DOTFILE_DIR'] = str(self.home / 'caller root')
        self.assertEqual(self.shell('print -r -- $DOTFILE_DIR', interactive=True),
                         self.env['DOTFILE_DIR'])
        self.assertEqual(self.shell('source ~/.zshrc; print -r -- $DOTFILE_DIR', interactive=True),
                         self.env['DOTFILE_DIR'])

    def test_rules_ignore_inherited_other_source(self):
        other = self.home / 'other/common/zsh'
        other.mkdir(parents=True)
        (other / '.zshvars').write_text('STOW_VERSION=missing\nJMETER_VERSION=missing\n')
        self.env['DOTFILE_DIR'] = str(other.parent.parent)
        self.env['DOTFILES_DIR'] = str(ROOT)
        for name, installed in [('stow', Path('/opt/stow-2.4.1')),
                                ('jmeter', Path('/opt/apache-jmeter-5.6.3'))]:
            result = subprocess.run([str(ROOT / 'rules' / name)], env=self.env)
            self.assertEqual(result.returncode, 0 if installed.is_dir() else 1)

    def test_application_creation_requires_explicit_layer_and_rejects_escape(self):
        layer = self.home / 'company'
        (layer / 'parts/application').mkdir(parents=True)
        outside = self.home / 'outside'
        outside.mkdir()
        (layer / 'parts/application/escape').symlink_to(outside)
        self.assertEqual(self.shell('dotfiles_add_application_config app >/dev/null 2>&1; print $?',
                                    interactive=True), '1')
        self.assertEqual(self.shell(f'dotfiles_add_application_config "{layer}" ../outside >/dev/null 2>&1; print $?',
                                    interactive=True), '1')
        self.assertEqual(self.shell(f'dotfiles_add_application_config "{layer}" escape >/dev/null 2>&1; print $?',
                                    interactive=True), '1')
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(self.shell(f'dotfiles_add_application_config "{layer}" example >/dev/null; print $?',
                                    interactive=True), '0')
        self.assertTrue((layer / 'parts/application/example/default/.shellinclude/default_example.sh').is_file())


if __name__ == '__main__':
    unittest.main()
