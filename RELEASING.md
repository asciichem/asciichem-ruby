= Releasing AsciiChem

== Versioning

AsciiChem follows https://semver.org/[Semantic Versioning]. While the
public API is still stabilising (0.x), breaking changes bump the minor
version; additive changes and fixes bump the patch.

== Pre-flight

1. Ensure `main` is green on CI.
2. Pull latest `main`.
3. Create a release branch: `git switch -c release/v0.X.Y`.

== Bump version

Edit `lib/asciichem/version.rb`:

[source,ruby]
----
module AsciiChem
  VERSION = "0.X.Y"
end
----

== Update changelog

Add a new section at the top of `CHANGELOG.md`:

[source,markdown]
----
## [0.X.Y] — YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
----

Update the `[Unreleased]` link at the bottom of `CHANGELOG.md` to point
at the new version's comparison on GitHub.

== Verify

[source,sh]
----
bundle exec rspec          # all specs pass
bundle exec rake build     # gem builds cleanly
gem install pkg/asciichem-0.X.Y.gem   # installs locally
asciichem version          # prints 0.X.Y
----

== Commit

[source,sh]
----
git add lib/asciichem/version.rb CHANGELOG.md
git commit -m "Bump version to 0.X.Y"
----

Open a PR for the release branch. **Never commit directly to `main`**
(global rule).

== Tag and push (maintainer only)

After the release PR merges:

[source,sh]
----
git switch main
git pull
git tag v0.X.Y
git push origin v0.X.Y
----

The tag triggers no automation; it exists as a marker. Tags are
permanent and visible — only the maintainer decides when and what to
tag.

== Publish to RubyGems

[source,sh]
----
gem push pkg/asciichem-0.X.Y.gem
----

Verify at https://rubygems.org/gems/asciichem.

== Site deploy

The asciichem.github.io site redeploys automatically on push to `main`.
If a release adds new syntax, update the spec pages on the site repo
in a separate PR.

== Post-release

1. Bump `[Unreleased]` back to the top of `CHANGELOG.md`.
2. Open a PR titled "Post-release housekeeping" with any doc cleanup.
