FROM ubuntu:18.04

ENV ANDROID_HOME="/opt/android-sdk" \
    ANDROID_NDK="/opt/android-ndk" \
    FLUTTER_HOME="/opt/flutter" \
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64/"

ENV TZ=America/Los_Angeles

# Get the latest version from https://developer.android.com/studio/index.html
ENV ANDROID_SDK_TOOLS_VERSION="7583922"
#ENV ANDROID_SDK_TOOLS_VERSION="4333796"

# Get the latest version from https://developer.android.com/ndk/downloads/index.html
ENV ANDROID_NDK_VERSION="r21d"

# nodejs version
ENV NODE_VERSION="12.x"

# Set locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"

RUN apt-get clean && \
    apt-get update && \
    apt-get install -y apt-utils locales && \
    locale-gen $LANG

ENV DEBIAN_FRONTEND="noninteractive" \
    TERM=dumb \
    DEBIAN_FRONTEND=noninteractive

# Variables must be references after they are created
ENV ANDROID_SDK_HOME="$ANDROID_HOME"
ENV ANDROID_NDK_HOME="$ANDROID_NDK/android-ndk-$ANDROID_NDK_VERSION"

ENV PATH="$JAVA_HOME/bin:$PATH:$ANDROID_SDK_HOME/emulator:$ANDROID_SDK_HOME/tools/bin:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$ANDROID_NDK:$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin"

WORKDIR /tmp

# Installing packages
RUN apt-get update && \
    apt-get install locales && \
    locale-gen "$LANG" && \
    apt-get install -y --no-install-recommends \
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
        lib32ncurses5 \
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
        pkg-config \
        ruby-full \
        software-properties-common \
        tzdata \
        unzip \
        vim-tiny \
        wget \
        zip \
        zlib1g-dev && \
    echo "set timezone" && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    echo "nodejs, npm, cordova, ionic, react-native" && \
    curl -sL -k https://deb.nodesource.com/setup_${NODE_VERSION} \
        | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    curl -sS -k https://dl.yarnpkg.com/debian/pubkey.gpg \
        | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" \
        | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install -y yarn && \
    rm -rf /var/lib/apt/lists/ && \
    npm install -g npm && \
    npm install -g \
        bower \
        cordova \
        eslint \
        gulp \
        ionic \
        jshint \
        karma-cli \
        mocha \
        node-gyp \
        npm-check-updates \
        react-native-cli && \
    npm cache clean --force && \
    rm -rf /tmp/* /var/tmp/*

# Install Android SDK
RUN echo "sdk tools ${ANDROID_SDK_TOOLS_VERSION}" && \
    wget --output-document=sdk-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip" && \
    mkdir --parents "$ANDROID_HOME" && \
    unzip -q sdk-tools.zip -d "$ANDROID_HOME"/cmdline-tools
###########
# IMPORTANT LINE! https://stackoverflow.com/a/65262939/4057688
RUN mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/tools
##########
RUN rm --force sdk-tools.zip

RUN echo "ndk ${ANDROID_NDK_VERSION}" && \
    wget --output-document=android-ndk.zip \
    "http://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip" && \
    mkdir --parents "$ANDROID_NDK_HOME" && \
    unzip -q android-ndk.zip -d "$ANDROID_NDK" && \
    rm --force android-ndk.zip

# Install SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.
RUN mkdir ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg

RUN yes | "$ANDROID_HOME"/cmdline-tools/tools/bin/sdkmanager --licenses

RUN echo "platforms" && \
    yes | "$ANDROID_HOME"/cmdline-tools/tools/bin/sdkmanager \
        "platforms;android-30"

RUN echo "platform tools" && \
    yes | "$ANDROID_HOME"/cmdline-tools/tools/bin/sdkmanager \
        "platform-tools"

RUN echo "build tools 25-30" && \
    yes | "$ANDROID_HOME"/cmdline-tools/tools/bin/sdkmanager \
        "build-tools;30.0.3"

RUN echo "emulator" && \
    yes | "$ANDROID_HOME"/cmdline-tools/tools/bin/sdkmanager "emulator"

RUN echo "kotlin" && \
    wget -O sdk.install.sh "https://get.sdkman.io" && \
    bash -c "bash ./sdk.install.sh && source ~/.sdkman/bin/sdkman-init.sh && sdk install kotlin" && \
    rm -f sdk.install.sh

RUN echo "Flutter sdk" && \
    cd /opt && \
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_2.2.0-stable.tar.xz -O flutter.tar.xz && \
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
    gem install bundler --no-document && \
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
RUN mkdir $ANDROID_HOME/tools/keymaps
RUN touch $ANDROID_HOME/tools/keymaps/en-us

# Run sshd
#RUN mkdir /var/run/sshd
#RUN echo "root:$ROOTPASSWORD" | chpasswd
#RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
#RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
#RUN echo "export VISIBLE=now" >> /etc/profile

#ENV NOTVISIBLE "in users profile"
# Add entrypoint
#ADD entrypoint.sh /entrypoint.sh
#RUN chmod +x /entrypoint.sh
#ENTRYPOINT ["/entrypoint.sh"]

# labels, see http://label-schema.org/
LABEL maintainer="Mirjalal Talishinski"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="mirjalal/android-30"
LABEL org.label-schema.version="${DOCKER_TAG}"
# LABEL org.label-schema.usage="/README.md"
# LABEL org.label-schema.docker.cmd="docker run --rm -v `pwd`:/project mingc/android-build-box bash -c 'cd /project; ./gradlew build'"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.vcs-ref="${SOURCE_COMMIT}@${SOURCE_BRANCH}"
