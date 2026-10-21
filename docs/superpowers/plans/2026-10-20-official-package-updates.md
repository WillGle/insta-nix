# Official package updates implementation plan

> **For agentic workers:** Use superpowers:executing-plans sequentially.

**Goal:** Apply the six package/patch recommendations approved by the user.
**Architecture:** Keep the existing module and package owners. Prefer supported
official Nixpkgs packages; carry only necessary upstream fixes and session wrappers.
**Tech Stack:** NixOS 26.05, Home Manager release-26.05, existing pinned unstable input.
**Spec:** The six-item audit and the user's instruction to implement all six.

## Constraints and review focus

- Preserve the pre-existing unstable lock entry and all unrelated files.
- Keep both system.stateVersion values and home.stateVersion unchanged.
- No Pi/Harness/ACP changes, new tests, activation, push, or garbage collection.
- Validate both hosts and the complete laptop build, not only evaluation.
- Check Fcitx/Blueman startup ownership, Antigravity watcher guard, and matching
  graphics dependencies after the base upgrade.

## Tasks

- [x] 1. Upgrade stable Nixpkgs and Home Manager to 26.05; resolve required
  compatibility changes without unrelated refactoring.
- [x] 2. Remove Calibre from the installed applications, per the user's later
  instruction. Remove the temporary Calibre-specific backport as well.
- [x] 3. Remove redundant Ryzen SMU header injection; use the pinned upstream package.
- [x] 4. Keep Antigravity IDE 2.5.5 and its watcher protection; verify the package build.
- [x] 5. Keep Blueman/Fcitx session wrappers and update Fcitx to official 5.1.23;
  verify the resulting package contains no competing autostart.
- [x] 6. Update Lightworks from a verified official Linux artifact and retain the
  desktop launcher; build and inspect the output.

## Verification

Run formatting, Statix, Deadnix, git diff --check, flake check --no-build,
both NixOS toplevel builds, and targeted package/output checks. Record failures
and any source/download limits precisely. Use one final read-only reviewer.

## Results

- Started on main at c9d51c5 with only flake.lock dirty. The pre-existing unstable
  node remains byte-for-byte identical; only stable Nixpkgs and Home Manager
  were updated by this task, both to their 26.05 branches (2026-10-19 revisions).
- Evidence: /tmp/nixos-official-updates-20261020/.
- NixOS 26.05 required migration from resolved.extraConfig and legacy resolved
  options to settings.Resolve. DNS policy is preserved. Both system.stateVersion
  values and home.stateVersion remain 25.11.
- Calibre was removed following the user's later instruction. The temporary
  Calibre override was deleted. No user books, settings, or application data
  were changed. No Calibre-specific patch remains in the repository.
- Ryzen SMU uses the original pinned upstream package with its built-in header
  fix, without the redundant local injection.
- Antigravity IDE 2.5.5 builds with the existing watcher 2.5.1 protection retained.
- Fcitx 5.1.23 and addons use the same unchanged unstable package set. Blueman
  remains 2.4.6. Existing Home Manager startup ownership is retained.
- Lightworks uses official stable 2026.1.0 build 58024, verified against vendor
  release metadata and a fixed SHA-256. Its package and launcher build; icon is
  present and the main ELF loader resolves 183 entries without an error.
- Full laptop build passed: h7xjzqpz6jjzi9psa2kl8jr8d9515svi.
- Full Plank build passed: la77r8l0bdq6scnzlj9wyc5664h195fw.
- Flake check for both hosts, formatting, Statix, Deadnix, and diff checks passed.
- One read-only reviewer found no remaining material source issue after the
  filtered upstream backport correction; that override was subsequently removed
  with Calibre. The reviewer did not claim GUI/runtime verification.
- No activation, GUI launch, push, or garbage collection. Lightworks project
  compatibility, codecs, hardware paths, and the new NixOS generation's live
  behavior require activation and runtime verification. Vendor warns that opening
  projects in 2026.1 may affect compatibility with older Lightworks versions.
- Remaining warnings preserve legacy Home Manager defaults (Yazi yy and user-dir
  session variables) and existing Nixpkgs aliases; they are not build failures.

## Follow-up: prefer standard Nixpkgs installations

- Prefer packages from the locked Nixpkgs inputs when they meet the current
  version and integration requirements. Local derivations also install into
  the Nix store; they remain exceptions requiring a concrete reason.
- User decision: keep Lightworks 2026.1.0 until Nixpkgs offers an equivalent
  version. Locked stable has 2025.1 and unstable has 2025.2; do not downgrade.
- Add standard unstable Obsidian 1.14.4 to the personal app list, matching the
  installed Flatpak version. Keep the Flatpak installation and its data until
  activation and native-app validation; no application-state migration here.
- Keep Discord 1.0.162 and Signal 8.31.0 as currently installed externally:
  locked Nixpkgs offers at most 1.0.161 and 8.29.0 respectively.
- Antigravity already uses the standard Nixpkgs payload with the scoped watcher
  fix. Blueman/Fcitx wrappers preserve Home Manager startup ownership; OpenLogi
  already uses Nixpkgs. The llama.cpp Vulkan option and Mesa wrapper preserve
  the existing GPU backend. These are integration requirements, not redundant
  alternative installers.
- Codex/Claude/uv have Nixpkgs packages, but their current user-local installers
  own their executables. Do not add competing PATH owners during this app audit.
- Follow-up verification passed: formatting, Statix, Deadnix, diff checks,
  flake check for both hosts, and full laptop build
  4c6hvjklp2zl1mmkmkbrjd6y6ild3g8y. Obsidian's executable and desktop entry
  are present. Lockfile is unchanged from the start of this follow-up. Evidence:
  /tmp/nixos-package-preference-20261020/. No activation or GUI validation.
