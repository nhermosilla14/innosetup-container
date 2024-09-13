
ARG BASE_IMAGE=bookworm
ARG VERSION=6.3.3
ARG WINEARCH=win32

FROM amake/wine:$BASE_IMAGE AS builder

ARG VERSION
ARG WINEARCH

USER root

RUN apt-get update \
&& apt-get install -y --no-install-recommends procps xvfb \
    && rm -rf /var/lib/apt/lists/*

# get at least error information from wine
ENV WINEDEBUG=-all,err+all

# Run virtual X buffer on this port
ENV DISPLAY=:99

RUN mkdir -p /opt/bin
COPY opt/bin/wine-x11-run opt/bin/waitonprocess /opt/bin/
ENV PATH=$PATH:/opt/bin

USER xclient

# Generate .innosetup-env file
RUN echo "INNO_MAJOR_VERSION=$(echo $VERSION | cut -d . -f 1)" > /home/xclient/.innosetup-env \
    && echo "INNO_MINOR_VERSION=$(echo $VERSION | cut -d . -f 2)" >> /home/xclient/.innosetup-env \
    && echo "INNO_PATCH_VERSION=$(echo $VERSION | cut -d . -f 3)" >> /home/xclient/.innosetup-env \
    && INNO_VERSION_UNDERSCORES=$(echo $VERSION | tr . _) \
    && echo "INNO_VERSION_UNDERSCORES=$INNO_VERSION_UNDERSCORES" >> /home/xclient/.innosetup-env

# InnoSetup ignores dotfiles if they are considered hidden, so set
# ShowDotFiles=Y. But the registry file is written to disk asynchronously, so
# wait for it to be updated before proceeding; see
# https://github.com/amake/innosetup-docker/issues/6
RUN wine reg add 'HKEY_CURRENT_USER\Software\Wine' /v ShowDotFiles /d Y \
    && while [ ! -f /home/xclient/.wine/user.reg ]; do sleep 1; done

# Install Inno Setup binaries
RUN . /home/xclient/.innosetup-env \
    && curl -SL "https://files.jrsoftware.org/is/$INNO_MAJOR_VERSION/innosetup-$VERSION.exe" -o is.exe \
    && wine-x11-run wine is.exe /SP- /VERYSILENT /ALLUSERS /SUPPRESSMSGBOXES /DOWNLOADISCRYPT=1 \
    && rm is.exe

# Install unofficial languages
RUN . /home/xclient/.innosetup-env \
    && [ $WINEARCH = win32 ] \
    && PROGRAM_FILES="/home/xclient/.wine/drive_c/Program Files" || PROGRAM_FILES="/home/xclient/.wine/drive_c/Program Files (x86)" \
    && cd "$PROGRAM_FILES/Inno Setup $INNO_MAJOR_VERSION/Languages" \
    && curl -L "https://api.github.com/repos/jrsoftware/issrc/tarball/is-$INNO_VERSION_UNDERSCORES" \
    | tar xz --strip-components=4 --wildcards "*/Files/Languages/Unofficial/*.isl"

FROM debian:bookworm-slim AS runtime

ARG VERSION
ARG WINEARCH

RUN groupadd -g 999 xclient && useradd -m -g xclient -u 999 -s /bin/bash xclient

# Install some tools required for creating the image
# Install wine and related packages
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    wine \
    $([ $WINEARCH = win32 ] && echo wine32 || echo wine32 wine64) \
    osslsigncode \
    && rm -rf /var/lib/apt/lists/*

COPY opt /opt
ENV PATH=$PATH:/opt/bin

COPY --chown=xclient:xclient --from=builder /home/xclient/.wine /home/xclient/.wine
COPY --chown=xclient: --from=builder /home/xclient/.innosetup-env /home/xclient/.innosetup-env
RUN mkdir /work && chown xclient: -R /work

# Environment preparation for the xclient user
ENV HOME=/home/xclient
ENV WINEPREFIX=/home/xclient/.wine

WORKDIR /app
ENTRYPOINT ["setup_user", "iscc"]
