@echo off
set PATH=C:\Users\Doctor PC\AppData\Roaming\npm;C:\Program Files\nodejs;%PATH%
firebase deploy --only firestore,storage --project eoto-app
