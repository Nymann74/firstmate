import { spawnSync } from "node:child_process";
import { lstatSync, readFileSync, statSync } from "node:fs";

// Cross-language mirror of the authoritative firstmate root predicate in
// bin/fm-primary-scope-lib.sh (fm_root_is_secondmate_home and
// fm_primary_scope_matches). That shell owner is authoritative for what counts
// as a genuine firstmate-owned primary root; this module exists only because
// the OpenCode plugin cannot source bash, and it must be kept in step with the
// owner rather than inventing a second definition.
//
// A valid secondmate-home marker force-includes that home as a guarded primary
// whether treehouse leased it as a linked worktree (git-dir != git-common-dir)
// or it is a git-cloned plain checkout. Only an unmarked (or invalidly-marked)
// root falls through to the linked-worktree exemption: a plain checkout is
// primary, while a linked git worktree is a crewmate/scout task worktree that
// the plugin must leave alone.

function gitDir(root, flag) {
  const result = spawnSync("git", ["-C", root, "rev-parse", flag], { encoding: "utf8" });
  if (result.status !== 0) return null;
  return result.stdout.trim();
}

// Return true when root carries a genuine secondmate-home marker. Mirrors
// fm_root_is_secondmate_home: a regular file (never a symlink) whose first
// line, with all whitespace removed, is a nonempty [A-Za-z0-9._-] identifier.
export function fmRootIsSecondmateHome(root) {
  if (!root) return false;
  const marker = `${root}/.fm-secondmate-home`;
  let stat;
  try {
    stat = lstatSync(marker);
  } catch {
    return false;
  }
  if (stat.isSymbolicLink() || !stat.isFile()) return false;
  let contents;
  try {
    contents = readFileSync(marker, "utf8");
  } catch {
    return false;
  }
  const firstLine = contents.split("\n", 1)[0] ?? "";
  const id = firstLine.replace(/\s/g, "");
  if (!id) return false;
  return /^[A-Za-z0-9._-]+$/.test(id);
}

function isRegularFile(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

// Return true when root is a genuine firstmate-owned primary root whose
// effective state dir is state. Mirrors fm_primary_scope_matches exactly.
export function fmPrimaryScopeMatches(root, state) {
  if (!root || !state) return false;
  if (!fmRootIsSecondmateHome(root)) {
    const gitDirValue = gitDir(root, "--git-dir");
    const gitCommonDirValue = gitDir(root, "--git-common-dir");
    if (gitDirValue === null || gitCommonDirValue === null) return false;
    if (gitDirValue !== gitCommonDirValue) return false;
  }
  if (!isRegularFile(`${root}/AGENTS.md`)) return false;
  if (!isDirectory(`${root}/bin`)) return false;
  if (!isDirectory(state)) return false;
  return true;
}
