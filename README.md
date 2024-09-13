# About
An easy way to create Inno Setup installer packages for Microsoft Windows directly from your Linux or macOS box.

# Usage
Run in interactive mode with your source root bound to `/app`. Just like with the `amake/innosetup` images, specify your setup script as the command, so you can run:

```bash
docker run --rm -i -v $PWD:/app:Z ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

Unlike with the `amake/innosetup` images, with this image the command above will first guess the correct user ID and group ID of the host user (based on the owner of the /app directory), and then make the IDs of the `xclient` user match those of the host user. This means that the container user will have the same UID and GID as the host user, and the container will be able to read and write files in the working directory without any issues (which can be problematic if running this in a CI/CD pipeline). In this image you can also override this, by setting the `PUID` and `PGID` environment variables to the desired values:

```bash
docker run --rm -i -v $PWD:/app:Z -e PUID=$(id -u) -e PGID=$(id -g) ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

This will make sure the output files are owned by the set user/group id, instead of guessing IDs. 

In Podman you could already do this by using the user namespace mapping feature:

```bash
podman run --rm -i -v $PWD:/app:Z --userns keep-id:uid=999,gid=999 ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

The only issue with this approach is that you must know the UID and GID of the container user, so it's not very convenient, unless you know for sure those two. That why I've chosen to leave them as 999 by default. Now, given this image tries to guess the user ID and group ID of the host user, if you try to run the container with the same command as in the first Docker example, it will do something quite different, but ultimately it will work just fine:

```bash
podman run --rm -i -v $PWD:/app:Z  ghcr.io/nhermosilla14/innosetup-container-x86:latest helloworld.iss
```

This is because, by default, Podman runs as rootless, so it works by mapping the user namespace of the host to the container, particularly mapping the container `root` user to the current host user. In this case, the "guessed" user ID and group ID of the host user will be those of the `root` user, and the container will be able to read and write files in the working directory without any issues. The actual IDs in the "outside" world will be the same as the host user, so your permissions will still be correct.

**Note**: If you try to override the user and group IDs of the container user in rootless mode, you will get an error message. This is because the container will do everything, except changing the working directory permissions, so the internal `xclient` user will not be able to access the files in the working directory (because, even if you set them to the current user's IDs, they will get mapped to other user IDs in the host user namespace).


# Differences from the amake/innosetup images
These images are intended to be used as a near drop-in replacement for the `amake/innosetup` images(https://github.com/amake/innosetup-docker), so they retain the same functionality, but with the following differences:

- **Image tag**: Each image is tagged based on the architecture supported, but also the version of the Inno Setup installer. For example, the `ghcr.io/nhermosilla14/innosetup-container-x86:6.3.3` image contains the Inno Setup 6.3.3 installer for 32-bit Windows. This allows you to be sure that the installer you are using is compatible with the Windows version you are targeting, and also prevents you from keeping an old version of Inno Setup around without ever knowing it (because the amake/innosetup images are always tagged the same, regardless of the version of Inno Setup they contain).

- **PUID and PGID**: Two environment variables are available to control the user ID and group ID of the container user. These are `PUID` and `PGID`, and they are used to set the UID and GID of the `xclient` user, which is used to run the Inno Setup installer. If these variables are not set, the behaviour falls back to one of the following:

    - If the current user is not `root`, then the container will check if the user ID and group ID match the default user ID and group ID of the container. If they do, then the container will run the main script as the `xclient` user as-is.

    - If the current user is not `root` and the user ID and group ID do not match the default user ID and group ID of the container, then the container will display an error message and exit.

    - If the current user is `root`, then the container will check if there are PUID and PGID environment variables set. If they are, then the container will modify the `xclient` user and group to match the values of the environment variables. If they are not, then the container will guess the user ID and group ID of the xclient user from the current directory attributes. In any of those cases, the container will fix the permissions of the `/home/xclient` directory to match the `xclient` user and group, and then run the main script as the `xclient` user.

    - If the current user is `root`, there are no PUID and PGID environment variables set, and the current directory attributes show it belongs to the root user, then the container will run the main script as the `root` user.

This behaviour is different from the `amake/innosetup` images (which always use the same user ID and group ID, although that not explicitly documented or enforced). The behaviour in this image was change to make it easier to use without messing with the permissions of the working directory, and to make it possible to run the container as both rootless and rootful with the same command.

- **Automatic deployment**: The Dockerfile and accompanying scripts are designed to be used with GitHub Actions to automatically build and push new images to the GitHub Container Registry whenever a new version of Inno Setup is released. This is done by periodically checking the Inno Setup website for new versions, and then building and pushing the corresponding image. This check is done ever **Sunday at 16:00 UTC**, and the images are pushed to the `ghcr.io/nhermosilla14` namespace.

- **License**: The original work is licensed under the CC0 license, this is GPLv3 licensed. See the [License](#license) section for more information.

# Available images

| Architecture (winearch) | Base image | First version | Image tag example |
| ----------------------- | ---------- | ------------- | ----------------- |
| wine32 | `amake/wine:bookworm` | `6.2.2` | `ghcr.io/nhermosilla14/innosetup-container-x86:6.2.2` |
| wine64 | `amake/wine:wine64-bookworm` | `6.2.2` | `ghcr.io/nhermosilla14/innosetup-container-x64:6.2.2` |

# Future plans
- Upgrade base images to Debian 12 (Bullseye) and/or Alpine 3.20.
- Add support for other architectures (e.g. arm64).

# Important notes
Be aware that depending on how you mount your code into the container, files referenced by the setup script may or may not be "visible" within the container. You probably want to make sure all referenced files are at or below the directory your script is in. The same applies to the output. The workdir is setup as /app, so it is a good idea to mount the root of your project over there.

# Known issues
## Wine, X11-related warnings and errors
This image pulls some tricks to get wine and Inno Setup installed and working
headlessly. This results in some yucky looking logs, but it seems to work
anyway.


# Licenses
The original work is licensed under the CC0 license, which is pretty much public domain. You can find some more information about this license [here](https://creativecommons.org/publicdomain/zero/1.0/). This image is, by contrast, licensed under the GPLv3 license (which you can find [here](LICENSE)). Among other things, that means you can use it as you see fit, but you must also make your changes available under the same license, so you cannot prevent others from having the same rights to use your code.

Inno Setup is used unmodified as a binary, and it is not covered by the GPLv3 license. It is licensed under the [Inno Setup License](https://github.com/jrsoftware/issrc/blob/main/license.txt).

# See also
- The original amake/innosetup images: [amake/innosetup](https://hub.docker.com/r/amake/innosetup)
- The original repo from amake: [amake/innosetup-docker](https://github.com/amake/innosetup-docker)
- The repo from jrsoftware: [jrsoftware/issrc](https://github.com/jrsoftware/issrc)
- The Inno Setup website: [innosetup.com](https://www.innosetup.com/)
