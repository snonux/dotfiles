# Releasing an app through the snonux F-Droid repo

## 1. Is this app in the F-Droid repo?

The list of apps is `apps.yml` in the GitHub repo snonux/fdroid. Check it like this (fish):

    set repo (gh repo view --json nameWithOwner -q .nameWithOwner)
    gh api repos/snonux/fdroid/contents/apps.yml -H 'Accept: application/vnd.github.raw' | grep -qx "    github: $repo"; and echo "F-Droid app"; or echo "not an F-Droid app"

That list is the source of truth. A quick local hint: `.github/workflows/release.yml` mentions snonux/fdroid, and there is a `fastlane/metadata/android/` directory next to `pubspec.yaml`. Current apps are Quicklog (snonux/quicklog), ComicRedr (snonux/comicredr) and RESTForge (snonux/restforge).

If the app is not listed, skip this reference. Adding a new app is a separate job described in `docs/onboarding-flutter-app.md` in snonux/fdroid.

## 2. How a release works

A release is a pushed `vX.Y.Z` tag, nothing more. The app repo's release workflow then builds and signs the APKs and attaches them to the GitHub release of that tag, creating the release if needed. snonux/fdroid picks up new releases by itself every 6 hours. Never build or upload APKs by hand, and never create the GitHub release without pushing the tag.

## 3. Steps

1. Start from an up-to-date, clean main branch.
2. Bump `version:` in `pubspec.yaml` (for RESTForge it is `flutter/pubspec.yaml`). The part before `+` is the new version and must equal the tag without the leading `v`, or the release build fails on purpose. The build number after `+` must be higher than in the last release. Never lower it, or phones cannot update.
3. Write the "What's new" text: plain text, at most 500 characters, in `<fastlane dir>/metadata/android/en-US/changelogs/`.
   - Quicklog: three files with the same text, named build*10+1, +2 and +3. For example, `+13` needs 131.txt, 132.txt and 133.txt.
   - ComicRedr: one file named after the build number, e.g. `+4` needs 4.txt.
   - RESTForge: overwrite default.txt.
   - Any other app: F-Droid reads `<versionCode>.txt`, falling back to `default.txt`. Check the app's AGENTS.md or README.
4. Update CHANGELOG.md or the README if the repo keeps one, and run the repo's own tests and analyzer.
5. Commit, tag and push (fish):

       git commit -am "release: vX.Y.Z"
       git tag vX.Y.Z; and git push; and git push --tags
       gh run watch

6. Check that `gh release view vX.Y.Z` lists the APKs: `app-<abi>-release.apk` for Quicklog, `<app>-vX.Y.Z-<abi>.apk` for the others. To put it in F-Droid right away instead of waiting up to 6 hours: `gh workflow run publish.yml -R snonux/fdroid`.

## 4. When the release run fails

- "signing secrets are not all set": the repo secrets ANDROID_KEYSTORE, ANDROID_KEY_ALIAS, ANDROID_KEYSTORE_PASSWORD and ANDROID_KEY_PASSWORD are missing. Ask Paul to set them from `android/key.properties`. Never print or commit key material.
- "Tag does not match version": fix `pubspec.yaml`, delete the tag locally and on GitHub, recreate it and push again.
- To rebuild an existing tag after a fix: `gh workflow run release.yml -f tag=vX.Y.Z`.
