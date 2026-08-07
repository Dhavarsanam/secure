# SecureRide — Firebase Backend Setup (Balance Steps)

## Code side la enna already fix pannaachu (naan pannitten)

1. `lib/main.dart` — Firebase.initializeApp() uncomment pannirukku, error handle panra try/catch kooda irukku.
2. `lib/firebase_options.dart` — corrupted file ah (adhula weather_screen code irundhichu, wrong paste) replace pannitten proper placeholder template vachu. Idhula ellame `TODO-REPLACE-...` values irukku — real keys venum.
3. `lib/providers/auth_provider.dart` — pure SharedPreferences mock ah irundhadhu, ippo real Firebase Auth (`AuthService`) use pannudhu. Method names ellam same (`login`, `signUp`, `logout`, etc.) so screens onnume maatha thevai illa.
4. `lib/providers/trip_provider.dart` — dummy trip list ah irundhadhu, ippo real Firestore (`FirestoreService`) use pannudhu — trip create, join by code, complete, cancel ellame real DB operations. `loadDummyTrips(uid)` method name same ah vachurukken (screens la call panra place maatha thevai illa) but ippo adhu live Firestore stream.
5. `firestore.rules` (project root la pudhusa) — basic security rules, users own profile mattum edit pannalam, trips members mattum update pannalam.

## Neenga pannanum (Firebase console access venum, so naan panna mudiyadhu)

### Step 1 — Firebase project create pannunga
1. https://console.firebase.google.com open pannunga → "Add project"
2. Project name kudunga (e.g. `secure-ride`) → Continue → Google Analytics venumna on pannunga (optional) → Create project

### Step 2 — Android app register pannunga
1. Project overview la Android icon click pannunga
2. **Android package name** = `com.example.secure_ride` (idhu unga `android/app/build.gradle.kts` la irukku — same ah type pannunga, illana app crash aagum)
3. App nickname optional, SHA-1 ippo skip pannalam (phone auth venumna mattum thevai)
4. "Register app" → **`google-services.json` download pannunga**
5. Andha file ah `android/app/` folder la podunga (exact path: `android/app/google-services.json`)

### Step 3 — flutterfire CLI install pannunga (mudinjaa idhu best option)
Terminal la (project root la):
```
dart pub global activate flutterfire_cli
flutterfire configure
```
- Idhu unga Firebase account login kேlum (browser open aagum)
- Project select pannunga (Step 1 la create pannadhu)
- Platforms select pannunga (Android mattum podhum, ipo)
- Run aana automatic ah `lib/firebase_options.dart` correct values vachu overwrite pannidum, `android/app/build.gradle.kts` la google-services plugin add pannidum

**flutterfire CLI install panna mudiyalana:** `lib/firebase_options.dart` la iruka TODO values ah, Firebase Console → Project Settings → General → "Your apps" → Android app → config values kandu manual ah replace pannunga (apiKey, appId, messagingSenderId, projectId, storageBucket).

### Step 4 — Authentication enable pannunga
1. Console la Build → Authentication → Get started
2. Sign-in method tab → Email/Password → Enable → Save

### Step 5 — Firestore database create pannunga
1. Console la Build → Firestore Database → Create database
2. "Start in production mode" select pannunga (test mode venaam, namma already rules file vachurukom)
3. Region select pannunga (asia-south1 — Mumbai — best for Tamil Nadu users)
4. Create pannaachu apparam, Rules tab open pannunga, andha project root la irukura `firestore.rules` file content ah copy-paste pannunga → Publish

### Step 6 — Run pannunga
```
flutter pub get
flutter run
```
Signup screen la pudhu account create pannunga → Firebase console → Authentication tab la andha user kaanum, Firestore → `users` collection la doc kaanum. Adhu work aachunu confirm.

## Common errors & fix

- **"DefaultFirebaseOptions have not been configured"** → Step 3 innum pannala, `firebase_options.dart` still TODO placeholders.
- **App crash on launch, "google-services.json missing"** → Step 2 file wrong location la irukku, exact path `android/app/google-services.json` confirm pannunga.
- **Trips list la "failed-precondition" error console la varum** → Firestore composite index venum (`memberUids` array-contains + `createdAt` orderBy combo). Error message la oru direct link varum — click pannina automatic ah index create aagum, 1-2 nimisham wait pannunga.
- **applicationId mismatch** → Step 2 la package name and `android/app/build.gradle.kts` la `applicationId` rendும் same ah irukanum.
