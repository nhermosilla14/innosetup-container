# About
An easy way to create Inno Setup installer packages for Microsoft Windows directly from your Linux or macOS box.

# Usage
Run in interactive mode with your source root bound to `/app`. As with the `amake/innosetup` images, specify your setup script as the command:

```bash
docker run --rm -i -v $PWD:/app:Z ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

Unlike the `amake/innosetup` images, this image first guesses the host user's UID and GID from the owner of the `/app` directory, then makes the `xclient` user's IDs match them. This allows the container to read and write files in the working directory without permission issues, which can be especially useful in CI/CD pipelines. You can override this behavior by setting the `PUID` and `PGID` environment variables:

```bash
docker run --rm -i -v $PWD:/app:Z -e PUID=$(id -u) -e PGID=$(id -g) ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

This ensures that the output files are owned by the specified user and group instead of guessed IDs.

In Podman you could already do this by using the user namespace mapping feature:

```bash
podman run --rm -i -v $PWD:/app:Z --userns keep-id:uid=999,gid=999 ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

The only issue with this approach is that you must know the container user's UID and GID, so it is not very convenient unless you know both values. That is why the default values are 999. Because this image tries to guess the host user's UID and GID, running the container with the same command as in the first Docker example behaves differently, but still works:

```bash
podman run --rm -i -v $PWD:/app:Z ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

By default, Podman runs rootless and maps the host user namespace to the container, including mapping the container's `root` user to the current host user. In this case, the "guessed" UID and GID are those of `root`, so the container can read and write files in the working directory without permission issues. The IDs outside the container remain those of the host user, so permissions stay correct.

**Note**: If you override the container user's UID and GID in rootless mode, you will get an error. The container can do everything except change the working directory permissions, so the internal `xclient` user cannot access the working directory. Even if you set the IDs to those of the current user, they are mapped to different IDs in the host user namespace.


# Differences from the amake/innosetup images
These images are intended to be used as a near drop-in replacement for the [`amake/innosetup` images](https://github.com/amake/innosetup-docker). They retain the same functionality, with the following differences:

- **Image tag**: Each image is tagged with both its supported architecture and the Inno Setup version. For example, the `ghcr.io/nhermosilla14/innosetup-container-x86:7.0.2` image contains Inno Setup 7.0.2 for 32-bit Windows. This makes the packaged version explicit and avoids unknowingly keeping an old Inno Setup version, as happens with the unversioned `amake/innosetup` tags. For Inno Setup 7 and later, the build uses the architecture-specific installer assets published by the upstream project.

- **PUID and PGID**: Two environment variables control the container user's UID and GID. These are `PUID` and `PGID`, and they set the IDs of the `xclient` user that runs Inno Setup. If these variables are not set, the behavior falls back to one of the following:

    - If the current user is not `root`, then the container will check if the user ID and group ID match the default user ID and group ID of the container. If they do, then the container will run the main script as the `xclient` user as-is.

    - If the current user is not `root` and the user ID and group ID do not match the default user ID and group ID of the container, then the container will display an error message and exit.

    - If the current user is `root`, then the container will check if there are PUID and PGID environment variables set. If they are, then the container will modify the `xclient` user and group to match the values of the environment variables. If they are not, then the container will guess the user ID and group ID of the xclient user from the current directory attributes. In any of those cases, the container will fix the permissions of the `/home/xclient` directory to match the `xclient` user and group, and then run the main script as the `xclient` user.

    - If the current user is `root`, there are no PUID and PGID environment variables set, and the current directory attributes show it belongs to the root user, then the container will run the main script as the `root` user.

This behavior differs from the `amake/innosetup` images, which always use the same UID and GID, although that is not explicitly documented or enforced. This image was changed to make it easier to use without altering the working directory's permissions and to support both rootless and rootful execution with the same command.

- **Automatic deployment**: GitHub Actions checks the [Inno Setup releases](https://github.com/jrsoftware/issrc/releases) every day at **04:00 UTC**, which is midnight at the fixed GMT-4 offset. It examines the three most recent releases, ignores drafts, prereleases, and releases identified as alpha, beta, preview, or release candidates, and checks that the corresponding images are not already present in GHCR. Missing versions are tagged and dispatched directly to the image build workflow. Images are pushed to the `ghcr.io/nhermosilla14` namespace.

- **License**: The original work is licensed under CC0; this project is licensed under GPLv3. See the [Licenses](#licenses) section for more information.

# Available images

| Architecture (winearch) | Base image | First version | Image tag example |
| ----------------------- | ---------- | ------------- | ----------------- |
| wine32 | `amake/wine:bookworm` | `6.2.2` | `ghcr.io/nhermosilla14/innosetup-container-x86:6.2.2` |
| wine64 | `amake/wine:wine64-bookworm` | `6.2.2` | `ghcr.io/nhermosilla14/innosetup-container-x64:6.2.2` |

# Future plans
- Upgrade base images to a newer Debian release and/or Alpine Linux.
- Add support for other architectures (e.g. arm64).

# Important notes
Be aware that, depending on how you mount your code into the container, files referenced by the setup script may or may not be visible within the container. Make sure all referenced files are at or below the directory containing your script. The same applies to the output. The working directory is set to `/app`, so it is a good idea to mount your project root there.

# Known issues
## Wine, X11-related warnings and errors
This image uses several workarounds to install and run Wine and Inno Setup
headlessly. This results in some noisy logs, but the image works as expected.


# Licenses
The original work is licensed under the CC0 license, which is pretty much public domain. You can find some more information about this license [here](https://creativecommons.org/publicdomain/zero/1.0/). This image is, by contrast, licensed under the GPLv3 license (which you can find [here](LICENSE)). Among other things, that means you can use it as you see fit, but you must also make your changes available under the same license, so you cannot prevent others from having the same rights to use your code.

Inno Setup is used unmodified as a binary, and it is not covered by the GPLv3 license. It is licensed under the [Inno Setup License](https://github.com/jrsoftware/issrc/blob/main/license.txt).

# See also
- The original amake/innosetup images: [amake/innosetup](https://hub.docker.com/r/amake/innosetup)
- The original repo from amake: [amake/innosetup-docker](https://github.com/amake/innosetup-docker)
- The repo from jrsoftware: [jrsoftware/issrc](https://github.com/jrsoftware/issrc)
- The Inno Setup website: [innosetup.com](https://www.innosetup.com/)
