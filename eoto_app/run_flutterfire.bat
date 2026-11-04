@echo off
set PATH=C:\Users\Doctor PC\AppData\Roaming\npm;C:\Program Files\nodejs;%PATH%
"d:\src\flutter\bin\dart.bat" pub global run flutterfire_cli:flutterfire configure --project=eoto-app --platforms="android,ios,web" --android-package-name=com.nchd.eoto --ios-bundle-id=com.nchd.eoto -y
