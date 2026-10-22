# Location Quest — Flutter Android + FastAPI

## 1. What is this project?

Location Quest is an Android app where users visit locations to complete quests and earn XP points.

**How it works:**

1. The user opens the app and signs in anonymously with Firebase.
2. The app displays quests on Google Maps.
3. The user goes near a quest location.
4. The app gets the user's GPS coordinates.
5. The app sends the coordinates and quest ID to the Python FastAPI backend.
6. FastAPI checks whether the user is close enough to the quest.
7. If the quest is valid, the user earns XP.
8. Firebase saves the XP and completion status.

## 2. Project folder structure

Your project should look like this:

```text
location_quest/
├── android/                # Android app configuration
├── lib/                    # Flutter/Dart source code
│   ├── main.dart
│   ├── models/
│   ├── screens/
│   └── services/
├── backend/                # Python FastAPI backend
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── tests/
│       └── test_distance.py
├── test/                   # Flutter tests
├── pubspec.yaml            # Flutter dependencies
├── firestore.rules         # Firebase database security rules
└── README.md               # Project instructions
```

The `backend` folder must be beside `lib` and `android`, not inside them.

## 3. Required software

Install these tools:

- Flutter SDK
- Android Studio and Android SDK
- Python 3.11 or newer
- Visual Studio Code
- A Firebase account
- A Google Maps API key

Check Flutter and Python in your terminal:

```powershell
flutter --version
flutter doctor
python --version
```

If `python --version` fails, fix the Python installation before continuing.

## 4. Configure Firebase

1. Open https://console.firebase.google.com/
2. Create a Firebase project.
3. Register your Android app using its actual package name.
4. Enable **Authentication → Sign-in method → Anonymous**.
5. Create a Cloud Firestore database.
6. Add at least three documents to the `quests` collection.
7. Publish the security rules from `firestore.rules`.

Example quest document:

```json
{
  "name": "Visit the Park",
  "description": "Reach the checkpoint",
  "latitude": 11.0168,
  "longitude": 76.9558,
  "radiusMeters": 50,
  "xpReward": 100,
  "isActive": true
}
```

Replace the sample coordinates with real, safe locations.

## 5. Configure Flutter

Open the terminal at the project root:

```powershell
cd C:\Users\manoj\location_quest
```

Configure Firebase:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Follow the prompts to select your Firebase project. This generates the Firebase configuration file used by the app.

Then install the Flutter dependencies:

```powershell
flutter pub get
```

Configure a Google Maps API key and the required location permissions in `android/app/src/main/AndroidManifest.xml`. Merge the entries into your existing manifest instead of replacing the entire file.

## 6. Set up Python FastAPI

Open a new terminal:

```powershell
cd C:\Users\manoj\location_quest\backend
```

Create a virtual environment:

```powershell
python -m venv .venv
```

Activate it:

```powershell
.\.venv\Scripts\Activate.ps1
```

Install the backend packages:

```powershell
python -m pip install -r requirements.txt
```

If Python is not recognised, install Python from https://www.python.org/downloads/, enable **Add python.exe to PATH**, and restart your terminal.

## 7. Configure Firebase Admin credentials

FastAPI needs server-side credentials to access Firestore securely.

1. Open Firebase Console → Project settings → Service accounts.
2. Generate a service-account key for local development.
3. Store the JSON key outside your project folder and never upload it to GitHub.
4. Set the environment variable in PowerShell:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\secure\location-quest-service-account.json"
```

Replace the example path with the actual path to your JSON key.

For a deployed backend, prefer an attached service account rather than a downloaded key file.

## 8. Start the FastAPI backend

Keep the terminal inside the `backend` folder with the virtual environment activated:

```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open these addresses in your browser:

- Health check: http://127.0.0.1:8000/health
- API documentation: http://127.0.0.1:8000/docs

Keep this terminal open while testing the app.

## 9. Run the Flutter app

Open a second terminal:

```powershell
cd C:\Users\manoj\location_quest
```

For an Android emulator:

```powershell
flutter run --dart-define=QUEST_API_URL=http://10.0.2.2:8000
```

For a physical Android phone, replace the emulator address with your computer's LAN IP address. Both devices must be connected to the same network, and the firewall must allow the connection.

For deployment, use your HTTPS backend URL instead.

## 10. Test the application

Check these scenarios:

- The app signs in successfully.
- Quests appear on the map.
- Location permission is requested.
- A quest outside the permitted radius is rejected.
- A valid quest awards XP.
- Completing the same quest twice does not award XP twice.
- XP and completed quests remain saved after restarting the app.

Run backend tests:

```powershell
cd C:\Users\manoj\location_quest\backend
pytest -q
```

Run Flutter checks:

```powershell
cd C:\Users\manoj\location_quest
flutter analyze
flutter test
```

## 11. Build the APK

Deploy the backend over HTTPS before creating a release build for distribution.

```powershell
cd C:\Users\manoj\location_quest

flutter build apk --release --dart-define=QUEST_API_URL=https://YOUR-CLOUD-RUN-URL
```

The APK is normally generated at:

`build/app/outputs/flutter-apk/app-release.apk`

Install and test the APK before submitting it.

## 12. Security notes

- Never put Firebase Admin service-account keys inside the Android app.
- Do not commit secret keys to GitHub.
- Do not allow the Flutter app to write XP directly.
- Keep Firestore security rules restrictive.
- Use HTTPS for deployed APIs.
- Phone-reported GPS coordinates can be spoofed, so this prototype does not prove a user is physically present.

## 13. Recommended setup order

1. Install Python and Flutter.
2. Configure Firebase.
3. Configure Google Maps.
4. Set up the FastAPI backend.
5. Start FastAPI.
6. Run the Flutter app.
7. Test quest validation and XP persistence.
8. Build and test the release APK.
