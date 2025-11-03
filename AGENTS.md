# Agent Guidelines

Welcome to the Figi codebase. Please follow these rules when modifying files in
this repository:

1. **Testing.** Run `bundle exec rspec` after making meaningful Ruby code
   changes. Include the command and its result in your final report.
2. **Style.** Prefer idiomatic Ruby 3 syntax: keyword arguments, endless methods
   where it improves clarity, and `freeze` immutable constants. Avoid wrapping
   `require` statements in `begin`/`rescue` blocks.
3. **Documentation.** When touching documentation under the repository root
   (including `README.md`), keep examples accurate for Ruby 3.1+ and the current
   API. Prefer fenced code blocks with explicit language hints.
4. **Configuration files.** If you update gem dependencies, refresh
   `Gemfile.lock` with `bundle lock` or `bundle install` so the lockfile matches.

These instructions apply to the entire project unless a nested `AGENTS.md`
overrides them.
