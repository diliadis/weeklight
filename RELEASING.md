# Releasing Weeklight

GitHub Actions builds release archives directly from version tags. The workflow
runs the test suite independently on Apple-silicon and Intel macOS runners,
creates an ad-hoc signed app for each architecture, publishes checksums, and
attests the ZIP archives before creating the GitHub Release.

No Apple Developer account or signing certificate is required. Consequently,
these builds are not notarized and users must explicitly approve the first
launch in macOS.

## Prepare a release

1. Choose a semantic version such as `1.1.0`. Prereleases use a suffix such as
   `1.2.0-beta.1`.
2. Set `CFBundleShortVersionString` in `Support/Info.plist` to the three-number
   version without any prerelease suffix. For example:

   ```bash
   /usr/libexec/PlistBuddy \
     -c "Set :CFBundleShortVersionString 1.1.0" \
     Support/Info.plist
   ```

3. Move completed entries from `Unreleased` into a versioned section in
   `CHANGELOG.md`.
4. Run the complete local checks:

   ```bash
   swift test
   ./Scripts/verify.sh
   ./Scripts/build-app.sh
   ```

5. Commit and push the version and changelog changes, then wait for CI on
   `main` to pass.

## Publish

Create and push an annotated tag from the tested commit:

```bash
git tag -a v1.1.0 -m "Release Weeklight 1.1.0"
git push origin v1.1.0
```

The tag must match `vMAJOR.MINOR.PATCH` or
`vMAJOR.MINOR.PATCH-prerelease`. The numeric portion must match
`CFBundleShortVersionString`, otherwise the release workflow stops before
building.

The workflow creates the GitHub Release only after both architectures pass all
tests, bundle validation, packaging, and attestation. Tags containing a hyphen
are automatically published as prereleases.

Releases are intentionally immutable: correct a failed workflow and rerun it
before a release is published. If a published release is wrong, create a new
patch version instead of replacing its assets.

## Verify the published assets

Download an archive and its adjacent `.sha256` file, then run:

```bash
shasum -a 256 -c Weeklight-v1.1.0-macos-arm64.zip.sha256
gh attestation verify Weeklight-v1.1.0-macos-arm64.zip \
  --repo diliadis/weeklight
```

The checksum detects transfer corruption or modification. The attestation ties
the archive to this repository, workflow, commit, and GitHub-hosted build.

## Future notarized releases

After enrolling in the Apple Developer Program, add the Developer ID
certificate and notarization credentials as GitHub Actions secrets. Replace the
ad-hoc signing step with Developer ID signing, submit each archive to Apple's
notary service, and staple the result before publishing. Do not place
certificate files or credentials in the repository.
