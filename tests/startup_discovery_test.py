#!/usr/bin/env python3
"""Check source-local rule selection and base startup in disposable homes."""

import os
from pathlib import Path
import platform
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
        self.env.pop('DOTFILES_DIR', None)
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

    def rule(self, name, env):
        return subprocess.run([ROOT / 'rules' / name], env=env,
                              text=True, capture_output=True)

    def test_version_rules_use_source_pins_before_installing_dotfiles(self):
        empty_home = self.home / 'empty home'
        empty_home.mkdir()
        installs = self.home / 'test installs'
        arch = {'x86_64': 'amd64', 'amd64': 'amd64', 'aarch64': 'arm64',
                'arm64': 'arm64'}.get(platform.machine(), platform.machine())
        lego = installs / f'lego_v4.33.0_{platform.system().lower()}_{arch}' / 'lego'
        env = dict(self.env, HOME=str(empty_home), DOTFILE_DIR=str(self.home / 'ignored'),
                   STOW_INSTALL_ROOT=str(installs), JMETER_INSTALL_ROOT=str(installs),
                   LEGO_INSTALL_ROOT=str(installs))

        for name in ('stow', 'jmeter', 'lego'):
            with self.subTest(rule=name, installed=False):
                result = self.rule(name, env)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stderr, '')

        for path in (installs / 'stow-2.4.1', installs / 'apache-jmeter-5.6.3', lego.parent):
            path.mkdir(parents=True, exist_ok=True)
        lego.write_text('#!/bin/sh\nexit 99\n')
        lego.chmod(0o755)
        for context in (env, dict(env, DOTFILES_DIR=str(ROOT))):
            for name in ('stow', 'jmeter', 'lego'):
                with self.subTest(rule=name, installed=True, wrapper='DOTFILES_DIR' in context):
                    result = self.rule(name, context)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stderr, '')
        self.assertEqual(list(empty_home.iterdir()), [])

    def test_version_rules_do_not_evaluate_pin_files(self):
        source = self.home / 'source checkout'
        pins = source / 'common/zsh/.zshversions'
        pins.parent.mkdir(parents=True)
        install = self.home / 'install'
        (install / 'stow-fixture').mkdir(parents=True)
        marker = self.home / 'pin-file-executed'
        env = dict(self.env, DOTFILES_DIR=str(source), PIN_TRIPWIRE=str(marker),
                   STOW_INSTALL_ROOT=str(install), STOW_VERSION='fixture')
        for contents, status in [
            ('touch "$PIN_TRIPWIRE"\nSTOW_VERSION=fixture\n', 0),
            ('STOW_VERSION=fixture\nSTOW_VERSION=fixture\n', 1),
            ('STOW_VERSION=$(touch "$PIN_TRIPWIRE")\n', 1),
            ('JMETER_VERSION=fixture\n', 1),
        ]:
            with self.subTest(contents=contents):
                pins.write_text(contents)
                result = self.rule('stow', env)
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertFalse(marker.exists())

    def test_zsh_rules_skip_user_startup(self):
        marker = self.home / 'zsh-startup-executed'
        (self.home / '.zshenv').rename(self.home / '.original-zshenv')
        (self.home / '.zshenv').write_text('touch "$STARTUP_TRIPWIRE"\n')
        tools = self.home / 'tools'
        tools.mkdir()
        for name in ('dpkg', 'tmux'):
            tool = tools / name
            tool.write_text('#!/bin/sh\nexit 0\n')
            tool.chmod(0o755)
        env = dict(self.env, PATH=f'{tools}:{self.env["PATH"]}', XDG_SESSION_TYPE='wayland',
                   STARTUP_TRIPWIRE=str(marker))
        subprocess.run(['zsh', '-c', ':'], env=env, check=True)
        self.assertTrue(marker.exists())
        marker.rename(self.home / 'negative-control')
        for name in ('libgtk', 'wayland-tmux'):
            with self.subTest(rule=name):
                result = self.rule(name, env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(marker.exists())

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
