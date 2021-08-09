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
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" "tools"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" "emulator"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" "platform-tools"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" "build-tools;30.0.3"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" "platforms;android-30"
RUN yes | .${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="/opt/android/sdk" "system-images;android-31;google_apis;arm64-v8a"

# Manually put licenses to the proper folder
RUN sudo rm -rf "/opt/android/sdk/licenses"
RUN	sudo mkdir "/opt/android/sdk/licenses"
RUN curl -s https://gist.githubusercontent.com/mirjalal/87085ddeecfd2250ba7fd1d7c04cc3ba/raw/b94b86c01eab75ef8147fbe0a433783729ec53af/android-googletv-license > /opt/android/sdk/licenses/android-googletv-license
RUN curl -s https://gist.githubusercontent.com/mirjalal/85554901380bab49ad7be1da1ef14b60/raw/308508a2c823e7896fe0495f5a95ca82e94a31f2/android-sdk-arm-dbt-license > /opt/android/sdk/licenses/android-sdk-arm-dbt-license
RUN curl -s https://gist.githubusercontent.com/mirjalal/2d7ec76c4216fd939678abff6b5e2d6a/raw/13a8b48abed3322126b9da1a3ad4b975d84e1619/android-sdk-license > /opt/android/sdk/licenses/android-sdk-license
RUN sudo curl -s https://gist.githubusercontent.com/mirjalal/bd29e13fb6fbe7b8b1e7abf9a95ca410/raw/3d993aede0516a726225baa174698bfcbee2bc44/android-sdk-preview-license > /opt/android/sdk/licenses/android-sdk-preview-license
RUN curl -s https://gist.githubusercontent.com/mirjalal/dea38ec796779c556d60d48f2e29e5e9/raw/1db3840c1db2ed3948683401159f787ccaed2806/google-gdk-license > /opt/android/sdk/licenses/google-gdk-license
RUN curl -s https://gist.githubusercontent.com/mirjalal/1d8b12819b7b02dc79aca0dafeb0866b/raw/be725e7c1504cd1f98b801d154c018a1804f1574/intel-android-extra-license > /opt/android/sdk/licenses/intel-android-extra-license
RUN curl -s https://gist.githubusercontent.com/mirjalal/0ca7519b518580aee129e3599201d9df/raw/bdd01429ab0bb599376111c2571c804aacb06941/mips-android-sysimage-license > /opt/android/sdk/licenses/mips-android-sysimage-license

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


