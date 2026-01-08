````md

# client

# Flutter Project Setup Guide

This guide explains how to set up and run this Flutter project locally after cloning it from GitHub.

---

## Prerequisites

Make sure the following are installed on your system:

- Flutter SDK (stable channel)  
  https://docs.flutter.dev/get-started/install
- Dart SDK (comes with Flutter)
- Android Studio or VS Code
- Android Emulator or Physical Device
- Git

Verify Flutter installation:

```bash
flutter doctor
````

Fix any issues reported before proceeding.

---

## Clone the Repository

```bash
git clone https://github.com/BallaRaja/TaskManager-FrontEnd
cd client
```

---

## Install Dependencies

```bash
flutter pub get
```

---

## Run the App

```bash
flutter run
```

To run on a specific device:

```bash
flutter devices
flutter run -d <device_id>
```

---

## Common Commands

```bash
flutter clean
flutter pub get
flutter run
```

---

## Troubleshooting

### Dependency issues

```bash
flutter clean
flutter pub get
```

### Emulator not detected

```bash
flutter devices
```

---

## Notes

* Backend must be running before testing task APIs
* App uses local notifications for reminders
* Time handling is based on device local time (IST by default)

---

## Setup Complete ✅

You are ready to run the project.
