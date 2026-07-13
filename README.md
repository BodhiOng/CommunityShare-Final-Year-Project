# CommunityShare Final Year Project

CommunityShare is a Flutter application backed by Firebase Authentication, Firestore, Storage, Messaging, and Cloud Functions.

The repository is organized into three main parts:

- `communityshare_app/` - the Flutter client
- `functions/` - Firebase Cloud Functions
- `scripts/` - Firestore seed scripts and helper utilities

## Prerequisites

Install the following before setting up the project:

- Flutter SDK
- Dart SDK, if it is not bundled with your Flutter install
- Node.js 20 or later
- Python 3.10 or later
- Firebase CLI
- A Firebase project with Authentication and Firestore enabled

Optional but recommended:

- `flutterfire_cli` for generating Firebase configuration files
- Android Studio or Visual Studio Code for Flutter development

## Repository Layout

- `communityshare_app/lib/main.dart` initializes Firebase and launches the app.
- `communityshare_app/lib/firebase_options.dart` contains the Firebase config used by non-Android targets.
- `communityshare_app/android/app/google-services.json` is required for Android Firebase builds.
- `functions/index.js` contains Firebase Cloud Functions used by the admin workflow.
- `scripts/seed_firestore.py` seeds Firestore with ERD-aligned sample data.
- `seed_firestore.bat` is a Windows helper that runs the seed script using the expected local file paths.

## Local Setup

### 1. Clone the repository

```powershell
git clone <repo-url>
cd CommunityShare-FYP
```

### 2. Configure Firebase

Create or select a Firebase project, then enable:

- Authentication
- Firestore Database
- Cloud Functions
- Cloud Storage if you use image uploads
- Cloud Messaging if you use push notifications

For Android, download `google-services.json` from the Firebase console and place it at:

```text
communityshare_app/android/app/google-services.json
```

For the Dart side, make sure `communityshare_app/lib/firebase_options.dart` matches your Firebase project. If you are using FlutterFire, regenerate it with:

```powershell
cd communityshare_app
flutterfire configure
```

The Android application id in this repo is:

```text
com.bodhi.communityshare
```

That value must match the Firebase Android app registration.

### 3. Install Flutter dependencies

```powershell
cd communityshare_app
flutter pub get
```

### 4. Install Firebase Functions dependencies

```powershell
cd ..\functions
npm install
```

### 5. Run the app locally

From `communityshare_app/`:

```powershell
flutter run
```

If you are testing a specific platform, use the matching Flutter target, for example:

```powershell
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

## Firestore Seed Data

The repository includes a Firestore seeder at [`scripts/seed_firestore.py`](./scripts/seed_firestore.py).

It seeds the ERD collections used by the app:

- `USER`
- `DONOR`
- `RECIPIENT`
- `COMMUNITY_HUB`
- `ADMIN`
- `ITEM_LISTING`
- `ITEM_REQUEST`
- `HANDOVER`
- `REPORT`
- `DONATION_STATUS_HISTORY`

### Dry run

Use `--dry-run` first to verify the document counts:

```powershell
python scripts/seed_firestore.py --service-account communityshare_app\serviceAccountKey.json --google-services-json communityshare_app\android\app\google-services.json --dry-run
```

### Seed the database

If the paths are correct and you want to write data, run:

```powershell
python scripts/seed_firestore.py --service-account communityshare_app\serviceAccountKey.json --google-services-json communityshare_app\android\app\google-services.json
```

By default the script resets the existing top-level ERD collections before writing the new seed set. If you want to keep existing data, add:

```powershell
--skip-reset
```

On Windows, you can also use the helper batch file:

```powershell
seed_firestore.bat
```

### Service account key

The seed script requires a Firebase Admin service account JSON. Keep it local and out of version control.

The repo expects it at:

```text
communityshare_app/serviceAccountKey.json
```

## Firebase Cloud Functions

The `functions/` folder contains the server-side user management functions used by the admin screens.

### Run locally with emulators

```powershell
cd functions
npm run serve
```

### Deploy functions

```powershell
cd functions
npm run deploy
```

## Firebase Deployment

The repo root contains a minimal Firebase configuration in `firebase.json` and `.firebaserc`.

To deploy the backend pieces associated with this project:

```powershell
cd functions
npm run deploy
```

If you later add Firebase Hosting or additional Firebase services, deploy them from the repo root with the Firebase CLI.

## AWS Setup

This repository is not currently configured with AWS infrastructure as code, AWS SDK usage, Elastic Beanstalk, Amplify, S3, or CloudFront deployment scripts.

In other words:

- there is no checked-in AWS backend
- there is no AWS hosting pipeline in this repo
- the current implementation is Firebase-first

If your assignment or production target requires AWS, you will need to add the AWS stack separately and point the app to those services. At the moment, the repo does not contain an AWS setup to document beyond that.

## Useful Commands

```powershell
cd communityshare_app
flutter analyze
flutter test
```

```powershell
cd functions
npm run lint
```

## Notes

- Do not commit `google-services.json` or `serviceAccountKey.json` unless your repository policy explicitly allows it.
- If Firestore seeding fails with a permissions error, confirm the service account has Firestore access and that the Firestore API is enabled for the project.
- `communityshare_app/lib/main.dart` initializes Firebase differently on Android versus other targets, so keep both `firebase_options.dart` and `google-services.json` in sync with the same Firebase project.