
# Getting and building OpenOLA

This public repository is open to forks and pull requests. A normal `git clone` downloads the prebuilt Android APK and all source archives, including the Windows GUI source.

## Download with Git

1. Install Git for Windows if it is not already installed.
2. Open PowerShell or Command Prompt and run:

   ```powershell
   git clone https://github.com/francisroan/OpenOLA.git
   ```

3. In the cloned `OpenOLA` folder, the APK is at `source/apk/OpenOLA-0.4.0-preview-arm64-v8a.apk`.
4. The ready-to-launch Windows GUI project is in `source/openola-windows-desktop-source.zip`. Extract it, open `windows-desktop/`, and double-click `SETUP_AND_LAUNCH.cmd` for first-time setup. After setup, use `30_scooter_gui.cmd` to launch it again.
5. See `source/apk/README.md` for APK integrity/install details and `SOURCE_BUILD_MANIFEST.md` for build prerequisites and source contents.

## Download source from GitHub

1. Open the repository Code page.
2. Open the `source/` folder.
3. Select the ZIP archive for the project you want: `openola-windows-desktop-source.zip`, `openola-android-kotlin-source.zip`, `openola-flutter-mobile-source.zip`, or `openola-shared-source.zip`.
4. On the archive page, click **Download** (or use **Code → Download ZIP** to get the entire repository).
5. Extract the archive. Follow [SOURCE_BUILD_MANIFEST.md](SOURCE_BUILD_MANIFEST.md) for prerequisites and build commands.

## Fork and contribute

1. Click **Fork** near the top of the repository page and create your own fork.
2. Make and validate changes in your copy, recording exact model/build details and evidence confidence.
3. Open a pull request from your fork and describe the change, tests, and validation limits.
4. Do not include personal vehicle identifiers, credentials, private signing material, raw owner captures, build caches, or vendor keys.

GitHub browser uploads are intended for files, not folders. To publish source updates, create a ZIP with the original project directory structure and upload that archive under `source/`, then update the manifest and archive link. Confirm the archive contents and remove secrets before committing.

Do not commit personal captures, local build caches, or private signing material. See [LICENSE_STATUS.md](LICENSE_STATUS.md) before reusing or redistributing code.
