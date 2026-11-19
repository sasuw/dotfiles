# Public agent instructions

This is the public template for `AGENTS.md`. An agent changes
`.public-agent-template.md` and copies it byte-for-byte to `AGENTS.md`.
CI verifies equality. Private instruction deployment is independent.

- An agent keeps shared packages in `common/`, optional packages in `parts/`
  and selection checks in `rules/`. Preserve the existing shell dialect.
- An agent uses envmaker's stack commands from the README (`--source`,
  `plan`, `--dry-run execstow restow`) for previews and link changes.
  Runtime tests use isolated HOME and XDG directories. Never
  restow a developer's real home as a test.
- An agent preserves `DOTFILE_DIR` overrides and the `$HOME/dotfiles` default.
- An agent syntax-checks changed Bash files with `bash -n` and `shellcheck`,
  and zsh files with `zsh -n`. There is no build step.
- An agent runs `bash tests/add_to_path_test.sh` and
  `python3 -I scripts/scan_public.py --root .` before committing, and adds
  focused runtime checks for changed behavior. Scan errors fail the gate.
- An agent documents user-facing changes and keeps credentials, personal
  endpoints and machine-specific identifiers out of files and examples.
  Use documentation domains and address ranges in fixtures.
- An agent reads `docs/public_scan.md` before changing scan exceptions.
  Narrow exceptions require a concrete reason; do not suppress directories.
