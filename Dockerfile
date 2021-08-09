FROM amd64/debian

MAINTAINER Mirjalal Talishinski "mirjalal.talishinski@gmail.com"

ENV ROOTPASSWORD android
ENV DOCKER_ANDROID_LANG en_US
ENV DOCKER_ANDROID_DISPLAY_NAME androidci-docker

ADD https://gist.githubusercontent.com/mirjalal/4a9124f1b24ccd06e8338b15e6da0744/raw/8af5601c4fd95808688498e85e53cd84af8457c7/circle-android-copy /bin/circle-android
RUN chmod +rx /bin/circle-android

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

RUN mkdir ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg

# Install new Android Tools and System Image for AVD
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT}/../ "tools"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT}/../ "emulator"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT}/../ "platform-tools"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT}/../ "build-tools;30.0.3"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT}/../ "platforms;android-30"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT}/../ "system-images;android-31;google_apis;arm64-v8a"

# Manually put licenses to the proper folder
RUN rm -rf ${ANDROID_SDK_ROOT}/../licenses && \
	mkdir ${ANDROID_SDK_ROOT}/../licenses && \
	touch android-googletv-license && echo '601085b94cd77f0b54ff86406957099ebe79c4d6' > android-googletv-license && \
	touch android-sdk-arm-dbt-license && echo '859f317696f67ef3d7f30a50a5560e7834b43903' > android-sdk-arm-dbt-license && \
	touch android-sdk-license && echo '24333f8a63b6825ea9c5514f83c2829b004d1fee' > android-sdk-license && \
	touch android-sdk-preview-license && echo '84831b9409646a918e30573bab4c9c91346d8abd' > android-sdk-preview-license && \
	touch google-gdk-license && echo '33b6a2b64607f11b759f320ef9dff4ae5c47d97a' > google-gdk-license && \
	touch intel-android-extra-license && echo 'd975f751698a77b662f1254ddbeed3901e976f5a' > intel-android-extra-license && \
	touch mips-android-sysimage-license && echo 'e9acab5b5fbb560a72cfaecce8946896ff6aab9d' > mips-android-sysimage-license

# RUN .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --update

# Get required emulator waiter
# RUN curl -s https://raw.githubusercontent.com/travis-ci/travis-cookbooks/0f497eb71291b52a703143c5cd63a217c8766dc9/community-cookbooks/android-sdk/files/default/android-wait-for-emulator > /tmp/android-wait-for-emulator
# RUN chmod +x /tmp/android-wait-for-emulator

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
RUN echo n | ${ANDROID_SDK_ROOT}/cmdline-tools/bin/avdmanager create avd --force --name "Android" --abi arm64-v8a --package "system-images;android-31;google_apis;arm64-v8a"

RUN echo no | .${ANDROID_SDK_ROOT}/../tools/emulator @Android -no-window -no-boot-anim -gpu off -verbose -qemu -usbdevice tablet -vnc :0 &

# Start AVD
# RUN .${ANDROID_SDK_ROOT}/emulator/emulator @Android &
# RUN .${ANDROID_SDK_ROOT}/../platform-tools/adb wait-for-device
# RUN ./tmp/android-wait-for-emulator
# RUN .${ANDROID_SDK_ROOT}/../platform-tools/adb shell input keyevent 82 &


