FROM amake/wine:buster AS inno

ARG VERSION=6.3.3

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends procps xvfb \
    && rm -rf /var/lib/apt/lists/*

# get at least error information from wine
ENV WINEDEBUG=-all,err+all

# Run virtual X buffer on this port
ENV DISPLAY=:99

COPY opt /opt
ENV PATH=$PATH:/opt/bin

USER xclient

# InnoSetup ignores dotfiles if they are considered hidden, so set
# ShowDotFiles=Y. But the registry file is written to disk asynchronously, so
# wait for it to be updated before proceeding; see
# https://github.com/amake/innosetup-docker/issues/6
RUN wine reg add 'HKEY_CURRENT_USER\Software\Wine' /v ShowDotFiles /d Y \
    && while [ ! -f /home/xclient/.wine/user.reg ]; do sleep 1; done

# Install Inno Setup binaries
RUN curl -SL "https://files.jrsoftware.org/is/6/innosetup-$VERSION.exe" -o is.exe \
    && wine-x11-run wine is.exe /SP- /VERYSILENT /ALLUSERS /SUPPRESSMSGBOXES /DOWNLOADISCRYPT=1 \
    && rm is.exe

# Install unofficial languages
RUN cd "/home/xclient/.wine/drive_c/Program Files/Inno Setup $(echo $VERSION | cut -d . -f 1)/Languages" \
    && curl -L "https://api.github.com/repos/jrsoftware/issrc/tarball/is-$(echo $VERSION | sed 's/\./_/g')" \
    | tar xz --strip-components=4 --wildcards "*/Files/Languages/Unofficial/*.isl"

FROM debian:buster-slim

RUN addgroup --system xusers \
    && adduser \
    --home /home/xclient \
    --disabled-password \
    --shell /bin/bash \
    --gecos "user for running an xclient application" \
    --ingroup xusers \
    --quiet \
    xclient

# Install some tools required for creating the image
# Install wine and related packages
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    wine \
    wine32 \
    osslsigncode \
    && rm -rf /var/lib/apt/lists/*

COPY opt /opt
ENV PATH=$PATH:/opt/bin

COPY --chown=xclient:xusers --from=inno /home/xclient/.wine /home/xclient/.wine
RUN mkdir /work && chown xclient:xusers -R /work

# Wine really doesn't like to be run as root, so let's use a non-root user
USER xclient
ENV HOME=/home/xclient
ENV WINEPREFIX=/home/xclient/.wine
ENV WINEARCH=win32

WORKDIR /work
ENTRYPOINT ["iscc"]
