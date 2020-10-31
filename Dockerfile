FROM conanio/gcc8

USER root

ARG ANDROID_NDK=/android-ndk-r21d
ARG STANDALONE_TOOLCHAIN=/android-ndk-r21d/toolchains/llvm/prebuilt/linux-x86_64

ENV ANDROID_NDK=$ANDROID_NDK \
    ANDROID_NDK_HOME=$ANDROID_NDK \
    STANDALONE_TOOLCHAIN=$STANDALONE_TOOLCHAIN \
    ANDROID_STL=c++static \
    ANDROID_ABI=x86_64 \
    ANDROID_PLATFORM=android-24 \
    ANDROID_TOOLCHAIN=clang \
    CC=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android24-clang \
    CXX=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android24-clang++ \
    LD=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-ld \
    AR=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-ar \
    AS=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-as \
    RANLIB=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-ranlib \
    STRIP=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-strip \
    ADDR2LINE=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-addr2line \
    NM=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-nm \
    OBJCOPY=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-objcopy \
    OBJDUMP=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-objdump \
    READELF=$STANDALONE_TOOLCHAIN/bin/x86_64-linux-android-readelf \
    SYSROOT=$STANDALONE_TOOLCHAIN/sysroot \
    CONAN_CMAKE_FIND_ROOT_PATH=$STANDALONE_TOOLCHAIN/sysroot \
    CONAN_CMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
    CONAN_CMAKE_PROGRAM=/cmake-wrapper \
    CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=BOTH \
    CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
    CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
    CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
    PATH=$PATH:$STANDALONE_TOOLCHAIN/bin

COPY cmake-wrapper /cmake-wrapper

RUN sudo apt-get update \
    && sudo apt-get -qq install -y --no-install-recommends unzip openjdk-8-jdk \
    && sudo rm -rf /var/lib/apt/lists/* \
    && sudo curl -s https://dl.google.com/android/repository/android-ndk-r21d-linux-x86_64.zip -O \
    && sudo unzip -qq android-ndk-r21d-linux-x86_64.zip -d / \
    && sudo rm -f android-ndk-r21d-linux-x86_64.zip \
    && sudo chmod +x /cmake-wrapper \
    && conan profile new default --detect \
    && conan profile update settings.os=Android default \
    && conan profile update settings.os.api_level=24 default \
    && conan profile update settings.compiler.libcxx=libc++ default

WORKDIR /home/conan
RUN mkdir -p ohai
COPY ohai.cpp ohai
ENV PATH=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}

# Calling clang++ directly as recommended by SDK -- does conan provide
# a more portable way?
#
# `static` is required as android doesn't ship with libc++_shared
#
# Conform to c++abi to allow compiler versions and flags to evolve
# with less world rebuilding
RUN armv7a-linux-androideabi21-clang++ -static -lc++abi ohai/ohai.cpp -o ohai/ohai

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    ANDROID_SDK_ROOT=/android-sdk

# 11/1/20: latest version 6858069 does not work!
ENV SDK_URL=https://dl.google.com/android/repository/commandlinetools-linux-6609375_latest.zip

RUN mkdir "$ANDROID_SDK_ROOT" \
 && cd "$ANDROID_SDK_ROOT" \
 && mkdir cmdline-tools \
 && cd cmdline-tools \
 && curl -s -o sdk.zip $SDK_URL \
 && unzip -q sdk.zip \
 && rm sdk.zip

ENV PATH=$ANDROID_SDK_ROOT/cmdline-tools/tools/bin:${PATH}
RUN yes | sdkmanager --licenses

# install the system-image, selected from sdkmanager --list
# `ndk-bundle` is not needed, because we installed the one we want
# above; this saves *a lot* of bandwidtch and diskspace
RUN sdkmanager 'system-images;android-24;default;armeabi-v7a'
# `platform` contains adb, required to run the ohai executable in the
# emulater
RUN sdkmanager 'platforms;android-21'
# `build-tools` provides the kernel-ranchu emulator
RUN sdkmanager 'build-tools;30.0.2'

ENV PATH=/android-sdk/platform-tools:/android-sdk/emulator:${PATH}
RUN echo 'no' | avdmanager create avd --name testdevice -k "system-images;android-24;default;armeabi-v7a" 

ENTRYPOINT emulator -sysdir /android-sdk/system-images/android-24/default/armeabi-v7a @testdevice -noaudio -no-accel -no-window -verbose