conandroid
==========

```
$ git clone git@github.com:wwarner/conandroid.git && cd conandroid
$ docker run -d --name conanio-android-sdk conanio-android-sdk:latest
$ docker exec conanio-android-sdk bash -c "adb push /home/conan/ohai/ohai /data/local/tmp && adb shell /data/local/tmp/ohai"
/home/conan/ohai/ohai: 1 file pushed, 0 skipped. 1.8 MB/s (6030896 bytes in 3.124s)
o hai
```
