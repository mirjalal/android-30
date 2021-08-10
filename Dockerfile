FROM amd64/debian

MAINTAINER Mirjalal Talishinski "mirjalal.talishinski@gmail.com"

ENV ANDROID_HOME="/opt/android-sdk"
ENV ANDROID_NDK="/opt/android-ndk"
ENV FLUTTER_HOME="/opt/flutter"
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64/"

# Specially for SSH access and port redirection
ENV ROOTPASSWORD android

# Expose ADB, ADB control and VNC ports
EXPOSE 22
EXPOSE 5037
EXPOSE 5554
EXPOSE 5555
EXPOSE 5900

# Get the latest version from https://developer.android.com/studio/index.html
ENV ANDROID_SDK_TOOLS_VERSION="7583922"

# Get the latest version from https://developer.android.com/ndk/downloads/index.html
ENV ANDROID_NDK_VERSION="r21e"

# nodejs version
ENV NODE_VERSION="16.x"

RUN apt-get clean && \
    apt-get update -qq && \
    apt-get install -qq -y apt-utils locales

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
ENV LC_ALL=C.UTF-8

ENV DEBIAN_FRONTEND="noninteractive"
ENV TERM=dumb
ENV DEBIAN_FRONTEND=noninteractive

RUN echo "debconf shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections && \
RUN echo "debconf shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections

# Variables must be references after they are created
ENV ANDROID_SDK_HOME="$ANDROID_HOME"
ENV ANDROID_NDK_HOME="$ANDROID_NDK/android-ndk-$ANDROID_NDK_VERSION"

ENV PATH="$JAVA_HOME/bin:$PATH:$ANDROID_SDK_HOME/emulator:$ANDROID_SDK_HOME/tools/bin:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$ANDROID_NDK:$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin"

WORKDIR /tmp

# Installing packages
RUN apt-get update -qq > /dev/null && \
    apt-get install -qq locales > /dev/null && \
    apt-get install -qq --no-install-recommends \
        autoconf \
        build-essential \
        curl \
        file \
        git \
        gpg-agent \
        less \
        lib32stdc++6 \
        lib32z1 \
        lib32z1-dev \
        lib32ncurses-dev \
        libc6-dev \
        libgmp-dev \
        libmpc-dev \
        libmpfr-dev \
        libxslt-dev \
        libxml2-dev \
        m4 \
        ncurses-dev \
        ocaml \
        openjdk-11-jdk \
        openssh-client \
        openssh-server \
        pkg-config \
		ssh \
        ruby-full \
        software-properties-common \
        tzdata \
        unzip \
        vim-tiny \
        wget \
        zip \
        zlib1g-dev > /dev/null

#RUN echo "set timezone" && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#RUN echo "nodejs, npm, cordova, ionic, react-native" && \
#    curl -sL -k https://deb.nodesource.com/setup_${NODE_VERSION} | bash - > /dev/null && \
#    apt-get install -qq nodejs > /dev/null && \
#    apt-get clean > /dev/null && \
#    curl -sS -k https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - > /dev/null && \
#    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list > /dev/null && \
#    apt-get update -qq > /dev/null && \
#    apt-get install -qq yarn > /dev/null && \
#    rm -rf /var/lib/apt/lists/ && \
#    npm install --quiet -g npm > /dev/null && \
#    npm install --quiet -g \
#        bower \
#        cordova \
#        eslint \
#        gulp \
#        ionic \
#        jshint \
#        karma-cli \
#        mocha \
#        node-gyp \
#        npm-check-updates \
#        react-native-cli > /dev/null && \
#    npm cache clean --force > /dev/null && \
#    rm -rf /tmp/* /var/tmp/*

# Install Android SDK
RUN echo "sdk tools ${ANDROID_SDK_TOOLS_VERSION}"
RUN wget --quiet --output-document=sdk-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip"
RUN mkdir --parents "$ANDROID_HOME"
RUN unzip -q sdk-tools.zip -d "$ANDROID_HOME"
RUN rm --force sdk-tools.zip

RUN echo "ndk ${ANDROID_NDK_VERSION}"
RUN wget --quiet --output-document=android-ndk.zip "http://dl.google.com/android/repository/android-ndk-r21e-linux-x86_64.zip"
RUN mkdir --parents "$ANDROID_NDK_HOME"
RUN unzip -q android-ndk.zip -d "$ANDROID_NDK"
RUN rm --force android-ndk.zip

# Install SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.
RUN mkdir --parents "$HOME/.android/"
RUN echo '### User Sources for Android SDK Manager' > "$HOME/.android/repositories.cfg"
RUN yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager --licenses > /dev/null

RUN echo "platforms"
RUN yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager "platforms;android-30" > /dev/null

RUN echo "platform tools"
RUN yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager "platform-tools" > /dev/null

RUN echo "build tools 30.0.3"
RUN yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager "build-tools;30.0.3" > /dev/null

RUN echo "emulator"
RUN yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager "emulator" > /dev/null

RUN echo "kotlin"
RUN wget --quiet -O sdk.install.sh "https://get.sdkman.io"
RUN bash -c "bash ./sdk.install.sh > /dev/null && source ~/.sdkman/bin/sdkman-init.sh && sdk install kotlin"
RUN rm -f sdk.install.sh

RUN echo "Flutter sdk" && \
    cd /opt && \
    wget --quiet https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_2.2.3-stable.tar.xz -O flutter.tar.xz && \
    tar xf flutter.tar.xz && \
    flutter config --no-analytics && \
    rm -f flutter.tar.xz

# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/

# Create some jenkins required directory to allow this image run with Jenkins
RUN mkdir -p /var/lib/jenkins/workspace && \
    mkdir -p /home/jenkins && \
    chmod 777 /home/jenkins && \
    chmod 777 /var/lib/jenkins/workspace && \
    chmod -R 775 $ANDROID_HOME

COPY Gemfile /Gemfile

RUN echo "fastlane" && \
    cd / && \
    gem install bundler --quiet --no-document > /dev/null && \
    mkdir -p /.fastlane && \
    chmod 777 /.fastlane && \
    bundle install --quiet

# COPY README.md /README.md

ARG BUILD_DATE=""
ARG SOURCE_BRANCH=""
ARG SOURCE_COMMIT=""
ARG DOCKER_TAG=""

ENV BUILD_DATE=${BUILD_DATE}
ENV SOURCE_BRANCH=${SOURCE_BRANCH}
ENV SOURCE_COMMIT=${SOURCE_COMMIT}
ENV DOCKER_TAG=${DOCKER_TAG}

# Create fake keymap file
RUN mkdir /usr/local/android-sdk/tools/keymaps
RUN touch /usr/local/android-sdk/tools/keymaps/en-us

# Run sshd
RUN mkdir /var/run/sshd && \
RUN echo "root:$ROOTPASSWORD" | chpasswd && \
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
RUN echo "export VISIBLE=now" >> /etc/profile

ENV NOTVISIBLE "in users profile"
# Add entrypoint
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# labels, see http://label-schema.org/
LABEL maintainer="Mirjalal Talishinski"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="mirjalal/android-30"
LABEL org.label-schema.version="${DOCKER_TAG}"
# LABEL org.label-schema.usage="/README.md"
# LABEL org.label-schema.docker.cmd="docker run --rm -v `pwd`:/project mingc/android-build-box bash -c 'cd /project; ./gradlew build'"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.vcs-ref="${SOURCE_COMMIT}@${SOURCE_BRANCH}"
