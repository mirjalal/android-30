FROM amd64/debian

MAINTAINER Mirjalal Talishinski "mirjalal.talishinski@gmail.com"

ENV ROOTPASSWORD android
ENV DOCKER_ANDROID_LANG en_US
ENV DOCKER_ANDROID_DISPLAY_NAME androidci-docker

# Never ask for confirmations
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
  && mkdir -p /usr/share/man/man1 \
  && apt-get install -y \
    git xvfb apt \
    locales sudo openssh-client ca-certificates tar gzip parallel \
    net-tools netcat unzip zip bzip2 gnupg curl wget make \
	ssh openssh-server socat libpulse0 xcb

# Set timezone to UTC by default
# RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8

CMD ["/bin/sh"]

ARG cmdline_tools=https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip
ARG android_home=/opt/android/sdk

RUN sudo apt-get update && \
    sudo apt-get install --yes \
        xvfb lib32z1 lib32stdc++6 build-essential \
        libcurl4-openssl-dev libglu1-mesa libxi-dev libxmu-dev \
        libglu1-mesa-dev openjdk-11-jdk && \
    sudo rm -rf /var/lib/apt/lists/*
	
RUN sudo mkdir -p ${android_home}/cmdline-tools && \
    wget -O /tmp/cmdline-tools.zip -t 5 "${cmdline_tools}" && \
    unzip -q /tmp/cmdline-tools.zip -d ${android_home} && \
    rm /tmp/cmdline-tools.zip

ENV ANDROID_HOME ${android_home}
ENV ANDROID_SDK_ROOT ${android_home}
ENV ADB_INSTALL_TIMEOUT 120

ENV PATH=${ANDROID_SDK_ROOT}/platforms:${ANDROID_SDK_ROOT}/build-tools:${ANDROID_SDK_ROOT}/system-images:${ANDROID_SDK_ROOT}/emulator:${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin:${ANDROID_SDK_ROOT}/tools:${ANDROID_SDK_ROOT}/tools/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}

RUN mkdir ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg
		
RUN yes | ./opt/android/sdk/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" --licenses > /dev/null

RUN echo "platforms" && \
    yes | ./opt/android/sdk/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" \
        "platforms;android-30" > /dev/null

RUN echo "platform tools" && \
    yes | ./opt/android/sdk/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" \
        "platform-tools" > /dev/null

RUN echo "build tools 25-30" && \
    yes | ./opt/android/sdk/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" \
        "build-tools;30.0.3"  > /dev/null

RUN echo "emulator" && \
    yes | ./opt/android/sdk/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" "emulator" > /dev/null

# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/

# RUN .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --update

# Expose ADB, ADB control and VNC ports
EXPOSE 22
EXPOSE 5037
EXPOSE 5554
EXPOSE 5555
EXPOSE 5900

# Run sshd
RUN mkdir /var/run/sshd && \
    echo "root:$ROOTPASSWORD" | chpasswd && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    echo "export VISIBLE=now" >> /etc/profile

ENV NOTVISIBLE "in users profile"

# Run sshd
RUN /usr/sbin/sshd

# Detect ip and forward ADB ports outside to outside interface
RUN ip=$(ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}')
RUN socat tcp-listen:5037,bind=$ip,fork tcp:127.0.0.1:5037 &
RUN socat tcp-listen:5554,bind=$ip,fork tcp:127.0.0.1:5554 &
RUN socat tcp-listen:5555,bind=$ip,fork tcp:127.0.0.1:5555 &

# Create & start emulator
RUN echo n | /opt/android/sdk/cmdline-tools/bin/avdmanager create avd --force --name "Android" --abi arm64-v8a --package "system-images;android-31;google_apis;arm64-v8a"

RUN echo no | ./opt/android/sdk/tools/emulator @Android -no-window -no-boot-anim -gpu off -verbose -qemu -usbdevice tablet -vnc :0 &

# Start AVD
# RUN .${ANDROID_SDK_ROOT}/emulator/emulator @Android &
# RUN .${ANDROID_SDK_ROOT}/../platform-tools/adb wait-for-device
# RUN ./tmp/android-wait-for-emulator
# RUN .${ANDROID_SDK_ROOT}/../platform-tools/adb shell input keyevent 82 &


