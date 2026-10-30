# Upload this OpenOLA package to GitHub

This guide is for the public repository [francisroan/OpenOLA](https://github.com/francisroan/OpenOLA). The repository is currently public and its page shows the Fork button, so other users can fork it already. GitHub allows forks of public repositories; you do not need a special fork setting for this public repository.

## Push the prepared package with GitHub Desktop

The prepared repository clone is already at `D:\Ola_claude\OpenOLA_public_upload`. It contains the filtered OpenOLA package and local commit `0395229` (`Add OpenOLA GUI and Android source with repair research`). It has not been pushed yet.

1. Install GitHub Desktop from [desktop.github.com](https://desktop.github.com/) and sign in to the GitHub account that owns `francisroan/OpenOLA`.
2. In GitHub Desktop, choose **File → Add Local Repository**.
3. Select `D:\Ola_claude\OpenOLA_public_upload` and click **Add repository**. Do not choose `D:\Ola_claude`; that is the original working folder and contains private/local files.
4. GitHub Desktop should show the `main` branch and the prepared commit. Check that the repository URL/origin is `https://github.com/francisroan/OpenOLA.git`.
5. Click **Push origin** in the top bar. If it instead shows **Publish repository**, stop and check the origin URL; the prepared folder is already linked to the existing public repository.
6. Refresh [github.com/francisroan/OpenOLA](https://github.com/francisroan/OpenOLA). The README should render on the front page; open `source/` and check `windows-desktop/`, `android-kotlin/`, and `flutter-mobile/`.

If GitHub Desktop reports a conflict or asks to overwrite remote changes, stop and ask for help instead of force-pushing. The online repository was a one-file starter when this package was prepared.

## Browser upload option

GitHub's web uploader accepts files and folders, but limits an upload to 100 files at a time and 25 MiB per file. This source package exceeds one batch, so GitHub Desktop is the easier route. If you choose the browser, upload in batches and preserve the directory structure exactly. See [GitHub's file upload instructions](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository).

## Confirm that people can fork

The repository is already public and the page currently displays **Fork**. Public repositories are forkable by default. If that changes or the Fork control disappears, check **Settings → General → Features → Allow forking** (when GitHub shows that option for your account/repository). See [GitHub's fork documentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks).

## Before pressing Push

- Do not copy personal captures, local APK binaries, private signing material, certificates granting live access, device identifiers, passwords, or local configuration.
- Keep the repository focused on OpenOLA GUI/APK and repair research.
- Do not publish raw diagnostics until personal/vehicle identifiers and credentials have been removed.
- Review `SOURCE_BUILD_MANIFEST.md` and `VALIDATION_PLAN.md` so readers know which files build each target and which checks remain open.
- Add a license only after confirming rights for all authored code, extracted data, icons, and third-party components. `LICENSE_STATUS.md` records the current status.
