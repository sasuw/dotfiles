"""Real CLI tests, private HOME/ZDOTDIR/XDG/Git config, local-only remotes.

Successful fixtures are removed; failed suites copy evidence to a sibling tree.
Unexpected setup/runner exceptions keep the original. No startup files are sourced.
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

from fixture_support import setup_evidence


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "common/bin/.bin/add_to_path.sh"
LIBRARY = REPO / "common/bin/.bin/lib/dotfiles_edit_lib.zsh"
ZSH, GIT = sys.argv[1:3]
del sys.argv[1:3]
SESSION = None


class PathTests(unittest.TestCase):
    def setUp(self):
        self.root = SESSION / self._testMethodName
        self.root.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        self.zdotdir = self.root / "zdotdir"
        self.zdotdir.mkdir()
        tool_bin = self.root / "real_bin"
        tool_bin.mkdir()
        (tool_bin / "zsh").symlink_to(ZSH)
        (tool_bin / "git").symlink_to(GIT)
        self.env = {
            "HOME": str(self.home),
            "ZDOTDIR": str(self.zdotdir),
            # Never the caller's source registry.
            "XDG_CONFIG_HOME": str(self.root / "xdg_config"),
            "PATH": f"{tool_bin}:/usr/bin:/bin",
            "LC_ALL": "C",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_AUTHOR_NAME": "Test",
            "GIT_AUTHOR_EMAIL": "test@example.invalid",
            "GIT_COMMITTER_NAME": "Test",
            "GIT_COMMITTER_EMAIL": "test@example.invalid",
        }
        self.file = self.root / "entries.sh"
        self.file.write_text("# saved paths\n")
        self.driver = self.root / "source_entries.zsh"
        self.driver.write_text(
            'if [[ "$2" == --unset ]]; then unset PATH; else PATH="$2"; fi\n'
            'source "$1"\nsource "$1"\nprint -rn -- "${PATH-}"\n'
        )

    def call(self, command, *, env=None, cwd=None):
        return subprocess.run(
            [str(arg) for arg in command],
            env=self.env if env is None else env,
            cwd=self.root if cwd is None else cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30,
        )

    def tool(self, *args, git=False, script=None, file=None, env=None):
        options = [] if git else ["--no-git"]
        options += ["--file", self.file if file is None else file]
        return self.call(
            [ZSH, "-f", SCRIPT if script is None else script, *options, *args], env=env
        )

    def success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def source(self, initial="/usr/bin:/bin", *, env=None, file=None):
        result = self.call(
            [ZSH, "-f", self.driver, self.file if file is None else file, initial],
            env=env,
        )
        self.success(result)
        return result.stdout

    def directory(self, name="tools/bin", *, home=True):
        target = (self.home if home else self.root) / name
        target.mkdir(parents=True, exist_ok=True)
        return target

    def refused(self, args, text, *, git=False, expected=1):
        before = self.file.read_bytes()
        result = self.tool(*args, git=git)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertIn(text, result.stderr)
        self.assertEqual(self.file.read_bytes(), before)

    def git(self, *args):
        result = self.call([GIT, "-C", self.repo, *args])
        self.success(result)
        return result.stdout.strip()

    def init_git(self):
        self.repo = self.root / "repo"
        script = self.repo / "common/bin/.bin/add_to_path.sh"
        library = script.parent / "lib/dotfiles_edit_lib.zsh"
        library.parent.mkdir(parents=True)
        shutil.copy2(SCRIPT, script)
        shutil.copy2(LIBRARY, library)
        self.file = self.repo / "common/shellutil/.shellinclude/path_additions.sh"
        self.file.parent.mkdir(parents=True)
        self.file.write_text("# saved paths\n")
        self.git("init", "-q")
        self.git("symbolic-ref", "HEAD", "refs/heads/main")
        self.git("config", "core.hooksPath", str(self.repo / ".git/hooks"))
        self.git("add", ".")
        self.git("commit", "-qm", "test: fixture")
        self.remote = self.root / "remote.git"
        self.success(self.call([GIT, "init", "-q", "--bare", self.remote]))
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "-q", "origin", "main")
        return script

    def test_help_and_argument_errors(self):
        self.success(self.tool("--help"))
        for args, text in [
            ([], "expected one DIRECTORY"),
            (["one", "two"], "expected one DIRECTORY"),
            ([""], "DIRECTORY is empty"),
            (["a:b"], "colons or line breaks"),
            (["a\nb"], "colons or line breaks"),
            (["a\rb"], "colons or line breaks"),
            (["--bogus"], "unknown option"),
            (["--file"], "needs a file"),
        ]:
            with self.subTest(args=args):
                self.refused(args, text, expected=2)

    def test_append_prepend_and_repeat_sourcing(self):
        append = self.directory("append")
        prepend = self.directory("prepend")
        self.success(self.tool(append))
        self.success(self.tool("--prepend", prepend))
        self.assertEqual(self.source(), f"{prepend}:/usr/bin:/bin:{append}")
        self.assertEqual(self.source(""), f"{prepend}:{append}")
        self.assertEqual(self.source("--unset"), f"{prepend}:{append}")
        # The membership pattern must match a whole component, not a prefix.
        self.assertEqual(
            self.source(f"{append}-extra:/bin"),
            f"{prepend}:{append}-extra:/bin:{append}",
        )

    def test_inherited_path_is_still_persisted_without_repositioning(self):
        target = self.directory()
        env = dict(self.env, PATH=f"/usr/bin:{target}:/bin")
        self.success(self.tool("--prepend", target, env=env))
        self.assertIn('"$HOME"', self.file.read_text())
        self.assertEqual(self.source(env["PATH"]), env["PATH"])

    def test_saved_duplicate_and_conflicting_order(self):
        target = self.directory()
        self.success(self.tool(target))
        before = self.file.read_bytes()
        result = self.tool(target / ".")
        self.success(result)
        self.assertIn("already saved", result.stdout)
        self.assertEqual(self.file.read_bytes(), before)
        self.refused(["--prepend", target], "already saved with append ordering")

    def test_home_portability_and_relative_input(self):
        target = self.directory()
        relative = os.path.relpath(target, self.root)
        self.success(self.tool(relative))
        self.assertNotIn(str(self.home), self.file.read_text())
        alternate_home = self.root / "alternate_home"
        (alternate_home / "tools/bin").mkdir(parents=True)
        env = dict(self.env, HOME=str(alternate_home))
        self.assertEqual(self.source(env=env), f"/usr/bin:/bin:{alternate_home}/tools/bin")

    def test_home_itself_and_home_prefix_boundary(self):
        self.success(self.tool(self.home))
        sibling = self.root / "home_other/bin"
        sibling.mkdir(parents=True)
        self.success(self.tool(sibling))
        self.assertEqual(self.source(), f"/usr/bin:/bin:{self.home}:{sibling}")
        self.assertIn(str(sibling), self.file.read_text())

    def test_quoting_and_no_expression_execution(self):
        for home in (True, False):
            with self.subTest(home=home):
                # Touch commands would create markers if input were evaluated.
                name = 'space \' " $HOME $(touch PWNED) `touch BACKTICK` [*]? \\ !'
                target = self.directory(name, home=home)
                self.success(self.tool(target))
                self.assertEqual(self.source().split(":").count(str(target)), 1)
                self.assertFalse((self.root / "PWNED").exists())
                self.assertFalse((self.root / "BACKTICK").exists())
                self.assertFalse((self.home / "PWNED").exists())

    def test_literal_dollar_home_and_symlink_spelling(self):
        target = self.directory("$HOME/bin", home=False)
        self.success(self.tool("$HOME/bin"))
        self.assertEqual(self.source(), f"/usr/bin:/bin:{target}")
        link = self.home / "linked"
        link.symlink_to(target, target_is_directory=True)
        self.success(self.tool(link))
        self.assertEqual(self.source(), f"/usr/bin:/bin:{target}:{link}")

    def test_missing_directory_warns_and_activates_when_created(self):
        target = self.home / "not-installed/bin"
        result = self.tool(target)
        self.success(result)
        self.assertIn("warning: directory does not exist", result.stderr)
        self.assertEqual(self.source(), "/usr/bin:/bin")
        target.mkdir(parents=True)
        self.assertEqual(self.source(), f"/usr/bin:/bin:{target}")

    def test_dry_run_and_file_endings(self):
        target = self.directory()
        for contents in ("", "# no newline", "# newline\n"):
            with self.subTest(contents=contents):
                self.file.write_text(contents)
                result = self.tool("--dry-run", target)
                self.success(result)
                self.assertIn("Would append", result.stdout)
                self.assertEqual(self.file.read_text(), contents)
                self.success(self.tool(target))
                self.assertTrue(self.file.read_bytes().endswith(b"\n"))
                self.assertEqual(self.source(), f"/usr/bin:/bin:{target}")

    def test_missing_or_invalid_target_refused(self):
        result = self.tool("/bin", file=self.root / "absent.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("file not found", result.stderr)
        self.file.write_text('echo "unterminated\n')
        self.refused(["/bin"], "would not pass zsh -n")

    def test_file_equals_option_delimiter_and_prepend_duplicate(self):
        target = self.directory("-directory", home=False)
        result = self.call(
            [ZSH, "-f", SCRIPT, "--no-git", f"--file={self.file}",
             "--prepend", "--", "-directory"]
        )
        self.success(result)
        self.assertEqual(self.source(), f"{target}:/usr/bin:/bin")
        before = self.file.read_bytes()
        self.success(self.tool("--prepend", target))
        self.assertEqual(self.file.read_bytes(), before)
        self.refused([target], "already saved with prepend ordering")

    def test_resolved_directory_validation(self):
        for name in ("colon:dir", "newline\ndir"):
            with self.subTest(name=name):
                cwd = self.root / name
                cwd.mkdir()
                result = self.call(
                    [ZSH, "-f", SCRIPT, "--no-git", "-f", self.file, "."], cwd=cwd
                )
                self.assertEqual(result.returncode, 2)
                self.assertIn("resolved DIRECTORY", result.stderr)

    def test_stowed_symlink_uses_explicit_layer(self):
        script = self.init_git()
        stowed = self.home / ".bin/add_to_path.sh"
        stowed.parent.mkdir()
        stowed.symlink_to(script)
        result = self.call([ZSH, "-f", stowed, "--no-git", "--layer-root", self.repo,
                            self.directory()])
        self.success(result)
        self.assertIn("if [ -d", self.file.read_text())
        self.assertEqual(self.source(), f"/usr/bin:/bin:{self.home}/tools/bin")

    def test_missing_and_mismatched_destination_refused_before_git(self):
        script = self.init_git()
        other = self.root / 'other'
        other.mkdir()
        before = self.file.read_bytes()
        head = self.git('rev-parse', 'HEAD')
        for options in ([], ['--layer-root', other, '--file', self.file]):
            result = self.call([ZSH, '-f', script, *options, self.directory()])
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.file.read_bytes(), before)
            self.assertEqual(self.git('rev-parse', 'HEAD'), head)
            self.assertEqual(self.git('status', '--porcelain'), '')

    def test_git_publish_isolated_commit_and_saved_noop(self):
        self.init_git()
        unrelated = self.repo / "unrelated"
        unrelated.write_text("pending\n")
        self.git("add", "unrelated")
        result = self.tool(self.directory(), git=True)
        self.success(result)
        self.assertEqual(
            self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"),
            "common/shellutil/.shellinclude/path_additions.sh",
        )
        self.assertEqual(self.git("diff", "--cached", "--name-only"), "unrelated")
        head = self.git("rev-parse", "HEAD")
        remote = self.call([GIT, "--git-dir", self.remote, "rev-parse", "main"])
        self.success(remote)
        self.assertEqual(remote.stdout.strip(), head)
        self.success(self.tool(self.directory(), git=True))
        self.assertEqual(self.git("rev-parse", "HEAD"), head)

    def test_git_dry_run_and_dirty_target(self):
        self.init_git()
        head = self.git("rev-parse", "HEAD")
        before = self.file.read_bytes()
        result = self.tool("--dry-run", self.directory(), git=True)
        self.success(result)
        self.assertIn("Would stage and commit", result.stdout)
        self.assertEqual(self.file.read_bytes(), before)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.file.write_text("# local edit\n")
        self.refused([self.directory()], "existing changes", git=True)
        self.git("add", ".")
        self.refused([self.directory()], "existing changes", git=True)
        self.success(self.tool(self.directory()))

    def test_git_missing_remote_untracked_and_detached_head(self):
        self.init_git()
        self.git("remote", "remove", "origin")
        self.refused([self.directory()], "no push remote", git=True)
        self.git("remote", "add", "origin", str(self.remote))
        self.git("checkout", "--detach", "-q")
        self.refused([self.directory()], "detached HEAD", git=True)
        self.git("switch", "main")
        self.file = self.repo / "untracked.sh"
        self.file.write_text("# untracked\n")
        self.refused([self.directory()], "must be tracked", git=True)

    def test_git_push_remote_precedence(self):
        self.init_git()
        self.git("remote", "rename", "origin", "publish")
        self.git("remote", "add", "broken", str(self.root / "absent.git"))
        self.git("config", "branch.main.remote", "broken")
        self.git("config", "remote.pushDefault", "broken")
        self.git("config", "branch.main.pushRemote", "publish")
        self.success(self.tool(self.directory("first"), git=True))
        self.git("config", "--unset", "branch.main.pushRemote")
        self.git("config", "remote.pushDefault", "publish")
        self.success(self.tool(self.directory("second"), git=True))
        self.git("config", "--unset", "remote.pushDefault")
        self.git("config", "branch.main.remote", "publish")
        self.success(self.tool(self.directory("third"), git=True))
        self.git("config", "branch.main.pushRemote", ".")
        self.refused([self.directory("fourth")], "push remote is local", git=True)

    def test_git_commit_and_push_failures_keep_entry(self):
        self.init_git()
        self.git("config", "remote.origin.pushurl", str(self.root / "absent.git"))
        head = self.git("rev-parse", "HEAD")
        target = self.directory("push-failure")
        result = self.tool(target, git=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("entry committed, but push failed", result.stderr)
        self.assertNotEqual(self.git("rev-parse", "HEAD"), head)
        self.assertIn(str(target), self.source().split(":"))
        # A real failing hook exercises publication failure without faking Git.
        hook = self.repo / ".git/hooks/pre-commit"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        head = self.git("rev-parse", "HEAD")
        target = self.directory("commit-failure")
        result = self.tool(target, git=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("commit failed; changes were kept", result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertIn(str(target), self.source().split(":"))
        self.assertEqual(
            self.git("diff", "--cached", "--name-only"),
            "common/shellutil/.shellinclude/path_additions.sh",
        )

    def test_git_staging_failure_keeps_entry(self):
        self.init_git()
        (self.repo / ".git/index.lock").touch()
        target = self.directory()
        result = self.tool(target, git=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("entry appended, but staging failed", result.stderr)
        self.assertIn(str(target), self.source().split(":"))


def main():
    global SESSION
    with setup_evidence(prefix="add_to_path_test.") as tmp:
        SESSION = Path(tmp)
        result = unittest.TextTestRunner(verbosity=2).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(PathTests)
        )
        if not result.wasSuccessful():
            evidence = tmp + "-failed"
            shutil.copytree(tmp, evidence, symlinks=True)
            print(f"Failed fixtures preserved at {evidence}", file=sys.stderr)
            return 1
        print(f"{result.testsRun} tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
