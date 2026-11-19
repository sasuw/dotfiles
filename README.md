# Dotfiles

A shell-first GNU Stow tree for Bash and zsh, with optional application and
OS packages. Env maker selects packages and manages home links in an ordered
`generic < personal` stack. `DOTFILE_DIR` names the generic shell checkout,
not the ordered registry; its default is `$HOME/dotfiles`.

## How to install

Requires Git, Bash, zsh, GNU Stow 2.4.1, Python 3, Perl 5.16+ for stack mode,
and standard Unix tools (including `find`, `readlink`, `realpath`, `sort` and
`xargs`). Env maker requires Stow specifically at
`/opt/stow-2.4.1/bin/stow`; a `stow` found only on PATH is insufficient.
The executable and its matching Perl modules must be installed together.
Linux is the initial validation platform. Native macOS and FreeBSD validation
remains pending; compatible GNU tools may be needed.

The overlay is implemented. Public
[envmaker](https://github.com/sasuw/envmaker) is available; the reviewed version
is `28b291e80ce14ae121b1ba6c9962d61052c802c4`. The dotfiles URL below is the
intended public destination; dotfiles publication and a literal fresh-install
check remain release prerequisites. See envmaker's
[Stow prerequisite guide](https://github.com/sasuw/envmaker/blob/28b291e80ce14ae121b1ba6c9962d61052c802c4/docs/prerequisites.md),
[source registry reference](https://github.com/sasuw/envmaker/blob/28b291e80ce14ae121b1ba6c9962d61052c802c4/docs/source_registry.md),
[migration guide](https://github.com/sasuw/envmaker/blob/28b291e80ce14ae121b1ba6c9962d61052c802c4/docs/migrate_overlay.md)
and [state and recovery reference](https://github.com/sasuw/envmaker/blob/28b291e80ce14ae121b1ba6c9962d61052c802c4/docs/overlay_state.md).

Use a disposable account for the first install. Review `common/`, `parts/`
and `rules/` first: installed applications may select configuration
automatically. Rules and discovery fallbacks execute even during inspection
and preview; sources must be trusted. No package manager or secret store is
required by the dotfiles tree itself. Optional packages need their applications.

1. Clone the generic tree and envmaker:

   ```bash
   git clone https://github.com/sasuw/dotfiles "$HOME/dotfiles"
   git clone https://github.com/sasuw/envmaker "$HOME/envmaker"
   export DOTFILE_DIR="$HOME/dotfiles"
   ```

   Follow the Stow prerequisite guide above: obtain the
   `stow-2.4.1.tar.gz` release and its signature from GNU Stow downloads,
   verify provenance using GNU's release instructions, and extract into a
   new disposable build directory. Ensure Perl, `make`, a compiler and the
   upstream build prerequisites are available. On a shared machine, an
   operator approves any package installation first. No pinned Perl build
   is required.

   From the extracted, provenance-verified `stow-2.4.1` source, run:

   ```bash
   ./configure --prefix=/opt/stow-2.4.1
   make
   sudo make install
   ```

   Configure and build are unprivileged. Review upstream install behavior
   before granting installation privileges. Env maker requires no manpage
   links or system package metadata changes.

   From the envmaker checkout, check the executable and matching modules:

   ```bash
   cd "$HOME/envmaker"
   /opt/stow-2.4.1/bin/stow --version
   perl bin/stow_probe.pl /opt/stow-2.4.1/bin/stow 2.4.1
   ```

   The JSON probe must report version `2.4.1` and an existing `Stow.pm`.
   Copying only the executable or using unrelated module versions is
   insufficient.

2. Use a one-source stack for a fresh home, so personal can be added later
   without a legacy-link migration:

   ```bash
   bash "$HOME/envmaker/envmaker.sh" --source generic="$DOTFILE_DIR" listdirs
   bash "$HOME/envmaker/envmaker.sh" --source generic="$DOTFILE_DIR" plan
   bash "$HOME/envmaker/envmaker.sh" --source generic="$DOTFILE_DIR" --dry-run execstow restow
   bash "$HOME/envmaker/envmaker.sh" --source generic="$DOTFILE_DIR" execstow restow
   bash "$HOME/envmaker/envmaker.sh" ls
   ```

   `listdirs` is source-qualified; `plan` reports selection. `ls` reports
   recorded ownership after apply. Preview checks selection and ownership,
   creates no persistent generation and runs no hooks. It reports
   `stow_simulation: false`: a successful preview is not a completed Stow
   simulation, and source edits between preview and apply remain live.

   Existing files and unrelated links cause refusal. Inspect and preserve
   each conflicting entry before explicitly relocating it. Equal contents
   do not prove ownership. Use the migration procedure below for old direct
   or folded Stow links. Do not use raw Stow to bypass stack ownership.

3. Keep the common startup dependencies together: `.zshenv`, `.zshvars`, `.zshversions`,
   `.zshrc`, `.bashrc`, `.bin/common.sh`, `.bin/lib/dotfiles_root.sh` and
   `.shellinclude/`. Then start the desired shell:

   ```bash
   exec zsh
   ```

   Bash users run `exec bash` instead. Interactive zsh adds `~/.bin` to PATH.
   In another shell mode, use `"$HOME/.bin/command"` or configure PATH in
   that shell's owning layer. Plain `bash -c` inherits its parent's PATH.
   After adding files, preview and restow
   before reloading. For edits to already linked files, a new shell suffices.
   Set `DOTFILE_DIR` in the parent environment or in the optional
   `~/.shellinclude/00-personal-root.sh` when the generic checkout differs
   from the default, including paths with spaces. A nonempty parent value
   takes precedence. Discovery reads literal version pins from the registered
   source before any dotfiles are installed. Stow and JMeter use
   `common/zsh/.zshversions`, and LEGO uses `common/zsh/.zshvars`.
   Each tool defaults to an install under `/opt`. Set `STOW_INSTALL_ROOT`,
   `JMETER_INSTALL_ROOT`, or `LEGO_INSTALL_ROOT` for a different install root.
   The prompt uses plain spacing when the character set is not UTF-8.

## How to add personal configuration

Choose the destination when using configuration writers. For example:

```sh
add_to_path.sh --layer-root "$HOME/dotfiles" --no-git "$HOME/tools/bin"
add_function_for_cmd.sh --layer-root "$HOME/dotfiles" --no-git show_root 'git rev-parse --show-toplevel'
```

Each writer also accepts `--file` for an explicit existing include. When both
`--layer-root` and `--file` are supplied, the resolved file must be inside the
selected root. A file in a Git checkout must belong to the selected layer's
repository. `--dry-run` previews the change. Without `--no-git`, the writer
stages, commits and pushes the selected file after Git checks pass.

For a new application include, use
`dotfiles_add_application_config <layer-root> <application-name> [config-name]`
in an interactive shell. The layer's `parts/application` directory must exist.

Create an empty private source before registering it, then add trusted
personal packages under the same `common/`, `parts/` and `rules/` structure:

```bash
bash "$HOME/envmaker/envmaker.sh" init "$HOME/dotfiles-personal"
```

This initializes local Git; it creates no remote and publishes nothing.
Keep credentials outside Git. Every registered root must exist.

Preserve existing configuration, then edit
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiletracker/config` to contain these
ordered entries (create the parent directory if absent):

```text
source.generic="$HOME/dotfiles"
source.personal="$HOME/dotfiles-personal"
```

Replace the legacy `dotfiles_dir` entry rather than keeping it alongside
sources. Configuration is data, not shell code: only a leading `~`, `$HOME`
or `${HOME}` expands; other variables and command substitutions stay literal.
For a generic-only persistent registry, keep just the first source line.

Inspect and reconcile the configured stack:

```bash
bash "$HOME/envmaker/envmaker.sh" listdirs
bash "$HOME/envmaker/envmaker.sh" plan
bash "$HOME/envmaker/envmaker.sh" explain .zshrc
bash "$HOME/envmaker/envmaker.sh" --dry-run execstow restow
bash "$HOME/envmaker/envmaker.sh" execstow restow
bash "$HOME/envmaker/envmaker.sh" ls
exec zsh
```

For one invocation, repeated `--source ID=PATH` replaces the **entire**
configured list in order; it never appends implicitly:

```bash
bash "$HOME/envmaker/envmaker.sh" \
  --source generic="$DOTFILE_DIR" \
  --source personal="$HOME/dotfiles-personal" explain .zshrc
```

`--source` cannot be combined with `--dotfiles-dir`, which selects legacy
single-root mode. `explain` describes selected and shadowed owners;
`ls` describes recorded ownership, without rediscovery.

### Whole-file precedence

The later source wins the whole home target, even when its bytes are equal.
An unchanged full personal fork shadows later generic edits. There is no
content merge or copy-on-write: edits through home links reach the winning
source. An editor that replaces a link can break ownership and cause refusal.
Removing, ignoring or deactivating a personal entry restores a selected generic
entry on reconciliation; absence is inheritance, not a suppression marker.
An empty optional personal source also inherits. Explicitly reducing the stack
can remove obsolete recorded owned links; this is not general home cleanup.

Same-source duplicates and file/directory conflicts fail. Package names do
not set priority. Rules and hooks stay source-local. Hooks run in source
order; identical hook names run in both sources. Rules in one source never
disable another source's entries. An optional
`common/personal/.shellinclude/zz-personal-settings.sh` can hold zsh settings
loaded after generic snippets. Bash needs Bash-compatible startup includes.

## How to migrate existing direct or folded links

Register the old owning root first, using the ordered configuration above.
Ordinary stack apply refuses to adopt old direct/folded links or unrelated
links. `generic` below is correct only if that registered source owns the
old links; otherwise use its actual source ID:

```bash
bash "$HOME/envmaker/envmaker.sh" --yes --dry-run migrate --from generic
bash "$HOME/envmaker/envmaker.sh" --yes migrate --from generic
bash "$HOME/envmaker/envmaker.sh" ls
```

Migration checks exact relative Stow link text into selected packages of
that source. Equal contents or an absolute link do not qualify. There is a
non-atomic unlink/relink interval; failure after unlink requires recovery.
After success, use ordinary stack preview and `execstow restow` for updates.

## How to recover an interrupted operation

Keep HOME and XDG_STATE_HOME consistent with the original operation. Inspect
before choosing a recovery action:

```bash
bash "$HOME/envmaker/envmaker.sh" recover inspect
```

After inspecting the report, a human chooses **one** action:

- Finish the recorded new generation (requires its recorded source inputs):

  ```bash
  bash "$HOME/envmaker/envmaker.sh" recover resume
  ```

- Or restore the old generation or original migration links:

  ```bash
  bash "$HOME/envmaker/envmaker.sh" recover restore
  ```

Restore can reinstate recorded links with unavailable sources; those links
may dangle until the sources return. Preserve journals, generations, lock
metadata and unrelated human replacements. Recovery refuses unrelated
replacements and live recorded processes. Do not automatically rerun a
failed operation, force adoption, edit state or delete locks to bypass it.

## Checks and license

Run `bash tests/add_to_path_test.sh` for the retained PATH helper suite.
Run `python3 -I scripts/scan_public.py --root .` with Gitleaks 8.16.0 for the
same content gates as CI. See [scan policy](docs/public_scan.md) for coverage,
exceptions and tool setup. Check changed shell files with `bash -n`,
`shellcheck` or `zsh -n` as appropriate. There is no compilation step.

Before accepting a release or re-export, a release agent must also run the
separate private privacy gate on that same candidate. Its term policy stays
private; public CI checks the public structural and secret gates only.

Original retained content is MIT licensed; see [LICENSE](LICENSE).
The owner has confirmed redistribution rights for the retained content.
External programs and plugins retain their own licenses; that confirmation
does not extend to separately installed dependencies.
