# Releasing an app through the snonux F-Droid repo

The full guide is `docs/releasing-apps.md` in snonux/fdroid (checked out under `~/git/fdroid` on Paul's machines). This reference is the short form for a version bump; where the two differ, that guide wins.

## 1. Is this app in the F-Droid repo?

The list of apps is `apps.yml` in the GitHub repo snonux/fdroid. Check it like this (fish):

    set repo (gh repo view --json nameWithOwner -q .nameWithOwner)
    gh api repos/snonux/fdroid/contents/apps.yml -H 'Accept: application/vnd.github.raw' | grep -qx "    github: $repo"; and echo "F-Droid app"; or echo "not an F-Droid app"

That list is the source of truth. A quick local hint: a workflow under `.github/workflows/` mentions snonux/fdroid, and there is a `fastlane/metadata/android/` directory.

If the app is not listed, skip this reference. Adding a new app is a separate job described in `docs/onboarding-flutter-app.md` in snonux/fdroid.

## 2. How a release works

A release is a `vX.Y.Z` tag on the commit that carries the bumped version. The app repo's Release workflow builds and signs the APKs for that tag and attaches them to its GitHub release, creating the release if needed. snonux/fdroid picks up new releases by itself every 6 hours. Never build or upload APKs by hand, and never create the GitHub release yourself.

**The Release workflow creates the tag.** Do not create or push the tag with git. Start the workflow by hand with the new tag as its `tag` input: when the tag does not exist yet, its first step ("Create the tag if it does not exist yet") reads the version file at the head of the branch the run was started on, stops if it does not match the tag, and otherwise creates a lightweight tag there and builds it. When the tag already exists, the same run rebuilds it and never moves it. This works the same for Paul and for agents; agent sessions in the cloud cannot push tags at all.

A created tag cannot be taken back cleanly once phones have seen the version. Only release when Paul asked for it.

## 3. The apps

| App | Repo | Version file | Tag | Workflow | APK names on the release |
| --- | --- | --- | --- | --- | --- |
| Quicklog | snonux/quicklog | `pubspec.yaml` | `vX.Y.Z` | `release.yml` | `app-<abi>-release.apk` |
| TurboNotes | snonux/turbonotes | `pubspec.yaml` | `vX.Y.Z` | `release.yml` | `app-<abi>-release.apk` |
| TurboLaunch | snonux/turbolaunch | `pubspec.yaml` | `vX.Y.Z` | `release.yml` | `app-<abi>-release.apk` |
| ComicRedr | snonux/comicredr | `pubspec.yaml` | `vX.Y.Z` | `release.yml` | `comicredr-vX.Y.Z-<abi>.apk` |
| RESTForge | snonux/restforge | `flutter/pubspec.yaml` | `vX.Y.Z` | `release.yml` | `restforge-vX.Y.Z-<abi>.apk` |
| Player | snonux/player | `player-android/pubspec.yaml` | `vX.Y.Z` | `release.yml` | `player-vX.Y.Z-<abi>.apk` |
| GunRunners | snonux/gunrunners | `CMakeLists.txt`, `project(Gunrunners VERSION X.Y.Z)` | `vX.Y.Z` | `release.yml` | `gunrunners-vX.Y.Z.apk` (one APK) |
| File Browser | snonux/filebrowser | `filebrowser-android/pubspec.yaml` | `android-vX.Y.Z` | `android-release.yml` | `filebrowser-android-vX.Y.Z-<abi>.apk` |

This table is a copy and may be behind; `apps.yml` and `docs/releasing-apps.md` in snonux/fdroid are current. For File Browser, read `android-vX.Y.Z` and `android-release.yml` wherever the steps below say `vX.Y.Z` and `release.yml` (the plain `vX.Y.Z` tags there belong to the server).

## 4. Steps

1. Start from an up-to-date, clean main branch.
2. Bump the version file. In a pubspec, the part of `version:` before `+` is the new version and must equal the tag without its prefix, or the release run stops on purpose. The build number after `+` must be higher than in the last release. Never lower it, or phones cannot update.
3. Write the "What's new" text: plain text, at most 500 characters, in `<fastlane dir>/metadata/android/en-US/changelogs/`. It must be in the commit that gets tagged.
   - Quicklog: three files with the same text, named build*10+1, +2 and +3. For example, `+13` needs 131.txt, 132.txt and 133.txt.
   - ComicRedr: one file named after the build number, e.g. `+4` needs 4.txt.
   - RESTForge: overwrite default.txt.
   - Any other app: F-Droid reads `<versionCode>.txt`, falling back to `default.txt`. Check the app's AGENTS.md or README.
4. Update CHANGELOG.md or the README if the repo keeps one, and run the repo's own tests and analyzer.
5. Commit and push to `main`, without a tag (fish):

       git commit -am "release: vX.Y.Z"; and git push

6. Check that the workflow has the tag step, then start it on `main` with the new tag. Start it only after the bump commit is on `origin/main`, and with nothing after it that should not ship: the tag goes on the branch head at the moment the run starts.

       set repo (gh repo view --json nameWithOwner -q .nameWithOwner)
       gh api repos/$repo/contents/.github/workflows/release.yml -H 'Accept: application/vnd.github.raw' | grep -c 'Create the tag if it does not exist yet'
       gh workflow run release.yml --ref main -f tag=vX.Y.Z
       gh run watch (gh run list --workflow release.yml --limit 1 --json databaseId --jq '.[0].databaseId')

   Without `gh`, use the GitHub MCP `actions_run_trigger` (method `run_workflow`, workflow `release.yml`, ref `main`, inputs `{"tag": "vX.Y.Z"}`).

   If the grep prints 0, the workflow can only rebuild existing tags (File Browser's `android-release.yml` was still like that on 2026-10-10), and a manual run for a new tag fails at checkout with "couldn't find remote ref" without creating anything. Then the tag is pushed the old way, which only works from Paul's own machine; in a cloud session, ask Paul to run it:

       git tag vX.Y.Z; and git push origin vX.Y.Z

7. Fetch the new tag (`git fetch --tags`) and check that `gh release view vX.Y.Z --json assets --jq '.assets[].name'` lists the APKs named as in the table. To put it in F-Droid right away instead of waiting up to 6 hours: `gh workflow run publish.yml -R snonux/fdroid`.

## 5. When the release run fails

- "Tag vX.Y.Z does not match version ...": on a manual run for a new tag, nothing was created; fix the version file or the tag name, push, and start the run again. For a tag that was pushed by hand, fix the version file, delete the tag locally and on GitHub, and tag again.
- "signing secrets are not all set": the repo secrets ANDROID_KEYSTORE, ANDROID_KEY_ALIAS, ANDROID_KEYSTORE_PASSWORD and ANDROID_KEY_PASSWORD are missing. Ask Paul to set them from `android/key.properties`. Never print or commit key material.
- To rebuild an existing tag after a fix: start the workflow again with the same `tag`; it rebuilds and replaces the APKs.
