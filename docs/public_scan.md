# Public scan policy reference

`python3 -I scripts/scan_public.py --root .` runs the public gates locally.
Requires Python 3 and Gitleaks 8.16.0 on PATH. CI installs the exact Go module
version with `go install github.com/zricethezav/gitleaks/v8@v8.16.0` into a
temporary bin directory. Local users can install that version into a private
bin directory and pass its executable with `--gitleaks /absolute/executable`.
No private checkout, account, service or credentials are needed.

The public runner checks the complete tree, including hidden files, docs,
tests and workflows. Only root `.git` metadata is outside the content tree.
Symlinks must resolve inside the tree; their text is checked and their regular
targets are scanned too. Binary, non-UTF-8 and special files fail closed.
The runner checks public instructions against their template.

Before every release or re-export is accepted, a release agent also runs a
separate private privacy gate against the same candidate. That gate checks
case-insensitive literal substrings in file and directory names, contents and
symlink text. Its private term policy and tests are excluded from this tree.
No term exemptions are approved. Public CI runs only the public gates; a
successful export or public scan alone is insufficient release evidence.

Gitleaks uses the explicit checked-in configuration extending its pinned
default rules. The runner rejects alternative ignore files.

The gate rejects paths Gitleaks 8.16.0 would silently omit: any nested `.git`,
names containing `vendor`, `node_modules`, `package-lock.json` or
`gitleaks.toml`, names ending in `go.mod`/`go.sum`, and names ending in
`jpg`, `gif`, `doc`, `docx`, `zip`, `xls`, `pdf`, `bin`, `svg` or `socket`.
The matching is case-insensitive and substring-based, conservatively covering
the scanner's default allowlist. Such paths fail even with neutral content.
The retained extensionless `rules/verapdf` also ends in `pdf`; it receives a
separate Gitleaks `detect --pipe` scan so no filename allowlist applies, and
reported locations map back to that rule. This is a scan route, not a secret
exception. The only fixed-content exception is `policy/gitleaks.toml`, which
must equal the runner's exact reviewed bytes; adding even a comment fails.
All other accepted text files are scanned for secrets through the normal
filesystem scan. Root Git metadata is excluded; Git history is not scanned.

Both filesystem and stdin invocations run with the candidate as their working
directory and `--source .`. Config and report paths remain absolute; HOME and
diagnostics remain in isolated scratch. Gitleaks therefore sees relative file
paths, so a parent directory containing `vendor`, `node_modules`,
`package-lock.json` or `gitleaks.toml` cannot suppress the whole scan. Reported
file locations are relative to the candidate, including the stdin rule mapping.

Diagnostic streams stay private in a temporary directory that is
removed after scanning. Only rule ID, path and line from the JSON secret
report are printed; matched text is never printed. Exit zero means both gates
passed. Missing tools, invalid policy, scan failures and unexplained matches
return nonzero. These gates cannot establish third-party rights or replace an
independent privacy review before release.
