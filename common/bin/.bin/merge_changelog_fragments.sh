#!/usr/bin/env bash
#
# Usage: merge_changelog_fragments.sh [-h|--help]
#        merge_changelog_fragments.sh [-n|--dry-run] [--commit] [<path>]
#
# Folds the CHANGELOG.d/ fragments of a repository into its CHANGELOG.md
# for repositories maintained with changelog fragments.
#
# Why fragments exist: agents that each add an entry at the top of CHANGELOG.md
# collide on every parallel branch, and the conflict never carries information.
# Instead each change adds one file under CHANGELOG.d/, named
# <UTC timestamp>-<ticket>-<slug>.md, so two branches never touch the same file.
# This script is the separate, deliberate step that merges them; it is run on
# demand by whoever maintains the changelog, not by each PR and not by CI.
#
# What it does:
#   - collects CHANGELOG.d/*.md (CHANGELOG.d/README.md is documentation and is
#     never a fragment), sorted oldest first by filename;
#   - inserts them newest first directly above the first `## YYYY-MM-DD ...`
#     entry below the CHANGELOG.md top-level `# ` heading, so the merged file
#     stays reverse-chronological like the entries already in it and matches
#     what the agents would have written by hand. Text between the heading and
#     that entry is an introduction and stays in place under the heading. With
#     no entry yet, the fragments go after all of the file's text
#     before the first release;
#   - copies each fragment through unchanged — it never rewrites a heading, so
#     the entry date is the one the agent wrote, not the filename timestamp;
#   - deletes the merged fragment files.
#
# The result is built in a temporary file next to CHANGELOG.md and put in place
# with a rename, so CHANGELOG.md is at every moment either the old file or the
# complete new one. What an interrupted run leaves behind depends on which side
# of that rename it stopped on:
#   - before the rename — a write error, a failed check, SIGINT or SIGTERM:
#     CHANGELOG.md and every fragment are as they were, the temporary file is
#     removed, and the run can simply be repeated. SIGKILL is the exception: no
#     trap runs, so a .CHANGELOG.md.* file can stay behind; CHANGELOG.md itself
#     is still untouched;
#   - after the rename — for example SIGTERM before the fragments are deleted:
#     the merged entry is in CHANGELOG.md and some fragments still exist.
#     Nothing is lost, but repeating the run is refused by the
#     uncommitted-CHANGELOG.md guard: finish that state by hand — check the
#     entry, delete the fragments now in CHANGELOG.md, commit.
#
# What it does not do: it never commits or pushes on its own. Pass --commit for
# a single commit of the merged CHANGELOG.md and the removed fragments — and
# nothing else: the commit names exactly those paths, so nothing else in the
# index can ride along, whatever is staged while it runs. It also refuses up
# front when anything unrelated is already staged. There is no push option,
# pushing stays a separate decision.
#
# Refuses to run, changing nothing, when: the path is not a Git repository,
# CHANGELOG.md is missing, CHANGELOG.d/ is missing, CHANGELOG.md has staged or
# unstaged changes, a fragment is malformed (bad filename, no
# `## YYYY-MM-DD ...` heading on its first non-blank line, no body under that
# heading, or a top-level `# ` heading that would break CHANGELOG.md), or
# --commit was given while changes other than the fragments being merged are
# staged. No fragments at all is not an error: it says so and exits 0.
#
# Options:
#   -n, --dry-run  Print the resulting CHANGELOG.md head and the files that
#                  would be removed; change nothing on disk.
#       --commit   Commit the merged CHANGELOG.md and the removed fragments.
#   -h, --help     Show this message and exit.
#
# Exit codes: 0 merged, or nothing to merge; 1 error; 2 usage

set -euo pipefail

script_name="$(basename -- "$0")"

readonly exit_error=1
readonly exit_usage=2

# <UTC timestamp>-<ticket>-<slug>.md, e.g. 20260928T185427Z-215-server-records.md
readonly fragment_name_re='^[0-9]{8}T[0-9]{6}Z-[A-Za-z0-9]+-[a-z0-9][a-z0-9-]*\.md$'
readonly entry_heading_re='^## [0-9]{4}-[0-9]{2}-[0-9]{2} '

# The header comment from line 3 to the first non-comment line is the usage
# text, so the two cannot drift apart.
usage() {
  awk 'NR >= 3 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
}

err() {
  printf '%s: %s\n' "$script_name" "$1" >&2
}

die() {
  err "$1"
  exit "${2:-$exit_error}"
}

dry_run=false
do_commit=false
target=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -n | --dry-run)
      dry_run=true
      shift
      ;;
    --commit)
      do_commit=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      err "unknown option: $1"
      usage >&2
      exit "$exit_usage"
      ;;
    *)
      [ -z "$target" ] || {
        err "unexpected extra argument: $1"
        usage >&2
        exit "$exit_usage"
      }
      target="$1"
      shift
      ;;
  esac
done

if [ $# -gt 0 ]; then
  [ -z "$target" ] || {
    err "unexpected extra argument: $1"
    exit "$exit_usage"
  }
  target="$1"
  shift
  [ $# -eq 0 ] || {
    err "unexpected extra argument: $1"
    exit "$exit_usage"
  }
fi

if $dry_run && $do_commit; then
  die "--dry-run and --commit are mutually exclusive" "$exit_usage"
fi

target="${target:-.}"
[ -d "$target" ] || die "not a directory: $target"

command -v git >/dev/null 2>&1 || die "git is not on PATH"

repo_root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || die "not inside a Git repository: $target"

changelog="$repo_root/CHANGELOG.md"
fragment_dir="$repo_root/CHANGELOG.d"

[ -f "$changelog" ] || die "no CHANGELOG.md in $repo_root"
[ -d "$fragment_dir" ] || die "no CHANGELOG.d/ in $repo_root"

# Collect fragments oldest first. LC_ALL=C keeps the sort byte-wise, so the
# UTC timestamp prefix orders them chronologically whatever the locale is.
fragments=()
while IFS= read -r path; do
  [ -n "$path" ] || continue
  fragments+=("$path")
done < <(
  find "$fragment_dir" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -print \
    | LC_ALL=C sort
)

if [ "${#fragments[@]}" -eq 0 ]; then
  printf 'No fragments in %s; CHANGELOG.md left unchanged.\n' "$fragment_dir"
  exit 0
fi

# A merge rewrites CHANGELOG.md in place. Refuse when it already carries work
# that is not committed, so a bad merge is always `git checkout` away.
if ! git -C "$repo_root" diff --quiet -- CHANGELOG.md \
  || ! git -C "$repo_root" diff --cached --quiet -- CHANGELOG.md; then
  die "CHANGELOG.md has uncommitted changes in $repo_root; commit or discard them first"
fi

# The commit below names its own paths, so staged work can no longer be
# published by accident. Refuse anyway when the index already holds work that
# is not part of this merge: folding a changelog merge into someone else's
# half-staged change set is nearly always a mistake, and saying so before
# anything is written costs nothing. A staged CHANGELOG.md is already refused
# above.
#
# Paths stay NUL-delimited from `git diff` all the way to the message. Command
# substitution strips every trailing newline, so a file whose name is a single
# newline — Git accepts one — would otherwise collapse into an empty string and
# slip past the check unseen. `%q` keeps such a name visible in the message
# instead of printing a bare newline; an ordinary path prints unchanged.
report_unrelated_staged() {
  local staged path found unrelated=false
  while IFS= read -r -d '' staged; do
    found=false
    for path in "${fragments[@]}"; do
      if [ "$staged" = "${path#"$repo_root"/}" ]; then
        found=true
        break
      fi
    done
    if [ "$found" = true ]; then
      continue
    fi
    if [ "$unrelated" = false ]; then
      unrelated=true
      err "--commit refuses because unrelated changes are staged:"
    fi
    printf '  %q\n' "$staged" >&2
  done < <(git -C "$repo_root" diff --cached --name-only -z)
  [ "$unrelated" = false ]
}

# Check before anything is written, so the refusal leaves the repository, the
# index and the fragments exactly as they were.
if $do_commit && ! report_unrelated_staged; then
  die "unstage them (git restore --staged <path>) and re-run, or run without --commit"
fi

# Validate every fragment before touching anything: a malformed one stops the
# whole run rather than being skipped or merged as-is.
validate_fragment() {
  local path="$1" name body_lines=0 saw_heading=false line
  name="$(basename -- "$path")"

  [[ "$name" =~ $fragment_name_re ]] \
    || die "malformed fragment $path: name must be <UTC timestamp>-<ticket>-<slug>.md, e.g. 20260928T185427Z-215-server-records.md"

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$saw_heading" = false ]; then
      case "$line" in
        '' | [[:space:]]*) continue ;;
      esac
      [[ "$line" =~ $entry_heading_re ]] \
        || die "malformed fragment $path: first non-blank line must be a '## YYYY-MM-DD — <title>' entry heading, got: $line"
      saw_heading=true
      continue
    fi
    case "$line" in
      '#' | '# '*) die "malformed fragment $path: a top-level '# ' heading would break CHANGELOG.md" ;;
      '') continue ;;
    esac
    body_lines=$((body_lines + 1))
  done < "$path"

  [ "$saw_heading" = true ] || die "malformed fragment $path: file is empty"
  [ "$body_lines" -gt 0 ] || die "malformed fragment $path: entry heading has no body"
}

for path in "${fragments[@]}"; do
  validate_fragment "$path"
done

# The insertion point is the first dated entry below the top-level heading,
# which is where an agent editing CHANGELOG.md by hand put a new entry.
# Everything between the heading and that entry is introductory text and stays
# directly under the heading. It is found with the same pattern that validates
# fragments, so a `## ` heading that is not a dated entry counts as intro text.
# Without any dated entry, all of the file is intro text and the entries go at
# its end; a file that is only the heading gets them directly under it.
heading_line="$(grep -n -m 1 '^# ' "$changelog" | cut -d: -f1 || true)"
[ -n "$heading_line" ] \
  || die "no top-level '# ' heading in $changelog; cannot find where entries start"
entry_line="$(
  grep -E -n -- "$entry_heading_re" "$changelog" | cut -d: -f1 \
    | awk -v heading="$heading_line" '$1 > heading { print; exit }' || true
)"

# Strip leading and trailing blank lines so the joined block has exactly one
# blank line between entries, whatever whitespace a fragment ended with.
emit_fragment_body() {
  awk '
    { lines[NR] = $0 }
    END {
      first = 1
      while (first <= NR && lines[first] ~ /^[[:space:]]*$/) first++
      last = NR
      while (last >= first && lines[last] ~ /^[[:space:]]*$/) last--
      for (i = first; i <= last; i++) print lines[i]
    }
  ' "$1"
}

# A dry run only prints, so it builds in TMPDIR and leaves the repository
# untouched. A real run builds next to CHANGELOG.md instead: the replacement
# below is then a rename within one directory, hence one filesystem, and is
# atomic. mktemp creates the file 0600, so `cp -p` first takes CHANGELOG.md's
# permission bits; the content is overwritten immediately after.
if $dry_run; then
  merged="$(mktemp)" || die "cannot create a temporary file"
  trap 'rm -f -- "$merged"' EXIT
else
  merged="$(mktemp "$repo_root/.CHANGELOG.md.XXXXXX")" \
    || die "cannot create a temporary file in $repo_root"
  trap 'rm -f -- "$merged"' EXIT
  cp -p -- "$changelog" "$merged"
fi

# Everything above the insertion point, without its trailing blank lines, so
# exactly one blank line separates it from the first inserted entry. The
# heading itself is never blank, so it always survives.
if [ -n "$entry_line" ]; then
  head -n $((entry_line - 1)) "$changelog"
else
  cat -- "$changelog"
fi | awk '
  { lines[NR] = $0 }
  END {
    last = NR
    while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
    for (i = 1; i <= last; i++) print lines[i]
  }
' > "$merged"
# Newest first: the fragments are sorted oldest first, so each one is placed
# above the previous, exactly as successive hand-written entries would have
# stacked up above the existing ones.
for ((i = ${#fragments[@]} - 1; i >= 0; i--)); do
  {
    printf '\n'
    emit_fragment_body "${fragments[$i]}"
  } >> "$merged"
done
# The existing entries follow unchanged, from the first one to the end. awk
# only terminates a last line that lacks its newline.
if [ -n "$entry_line" ]; then
  printf '\n' >> "$merged"
  tail -n +"$entry_line" "$changelog" | awk '{ print }' >> "$merged"
fi

if $dry_run; then
  printf 'Would merge %d fragment(s) into %s:\n\n' "${#fragments[@]}" "$changelog"
  for ((i = ${#fragments[@]} - 1; i >= 0; i--)); do
    printf '  %s\n' "${fragments[$i]}"
  done
  printf '\nResulting %s head:\n\n' "CHANGELOG.md"
  sed -n "1,$(($(wc -l < "$merged") < 60 ? $(wc -l < "$merged") : 60))p" "$merged" \
    | sed 's/^/  | /'
  printf '\nWould remove:\n'
  for path in "${fragments[@]}"; do
    printf '  %s\n' "$path"
  done
  printf '\nDry run: nothing changed.\n'
  exit 0
fi

# Confirm the result is complete before it replaces anything. Every step above
# fails the run through `set -e`, but a write that reports success and still
# drops data would take the entries copied from the bottom of CHANGELOG.md with
# it, and those exist nowhere else on disk once the rename has happened. Count
# the entry headings: the result must hold every one that CHANGELOG.md and the
# fragments had between them.
[ -s "$merged" ] || die "the merged result is empty; $changelog is unchanged"

count_entry_headings() {
  grep -c '^## ' "$1" || true
}

expected_headings="$(count_entry_headings "$changelog")"
for path in "${fragments[@]}"; do
  expected_headings=$((expected_headings + $(count_entry_headings "$path")))
done
actual_headings="$(count_entry_headings "$merged")"
[ "$actual_headings" -eq "$expected_headings" ] \
  || die "the merged result holds $actual_headings entry heading(s), expected $expected_headings; $changelog is unchanged"

# The rename is the only step that makes the new file visible, and it either
# happens completely or not at all.
mv -f -- "$merged" "$changelog" \
  || die "cannot replace $changelog; it and the fragments are unchanged"
trap - EXIT

# Only now: until the replacement succeeded, the fragments were the only copy.
rm -f -- "${fragments[@]}"

printf 'Merged %d fragment(s) into %s:\n' "${#fragments[@]}" "$changelog"
for ((i = ${#fragments[@]} - 1; i >= 0; i--)); do
  printf '  %s\n' "$(basename -- "${fragments[$i]}")"
done

if $do_commit; then
  # Constrain the commit itself instead of checking the index and then
  # committing all of it: those two steps cannot be made atomic against another
  # agent working in the same checkout, who may stage something between them or
  # during them, so any number of checks only narrows that window. `--only`
  # builds the commit from the working-tree state of the named paths alone, so
  # nothing else rides along however the index changes meanwhile, and whatever
  # else is staged is left staged and untouched.
  #
  # Exact fragment paths, never the CHANGELOG.d directory: a directory pathspec
  # would sweep in an unrelated edit to CHANGELOG.d/README.md. `--only` rejects
  # a pathspec that matches nothing Git knows, and a fragment that was never
  # committed and never staged left nothing behind when it was removed — so
  # pass only the fragments the index still lists, and stage a CHANGELOG.md
  # that has never been committed first.
  git -C "$repo_root" ls-files --error-unmatch -- "$changelog" >/dev/null 2>&1 \
    || git -C "$repo_root" add -- "$changelog"

  commit_paths=("$changelog")
  while IFS= read -r -d '' path; do
    commit_paths+=("$path")
  done < <(git -C "$repo_root" ls-files -z -- "${fragments[@]}")

  git -C "$repo_root" commit -q --only \
    -m "docs: merge ${#fragments[@]} CHANGELOG.d fragment(s) into CHANGELOG.md" \
    -- "${commit_paths[@]}" \
    || die "the merge is on disk but could not be committed; commit $changelog and the removed fragments yourself"
  printf 'Committed as %s. Not pushed.\n' "$(git -C "$repo_root" rev-parse --short HEAD)"
else
  printf 'Not committed. Review the diff, then commit CHANGELOG.md and the removed fragments.\n'
fi
