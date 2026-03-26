# 🚀 QUICK START GUIDE - Estate Capture App

## ⚡ Fast Setup (5 minutes)

### Step 1: Install Flutter (if not already installed)

**Windows:**
1. Download Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\src\flutter` (or any location)
3. Add to PATH: `C:\src\flutter\bin`
4. Open PowerShell and run:
   ```powershell
   flutter doctor
   ```

### Step 2: Install Android Tools

**Option A: Android Studio (Recommended)**
1. Download: https://developer.android.com/studio
2. Install with Android SDK
3. Open Android Studio → SDK Manager → Install latest SDK

**Option B: Command Line Tools Only**
1. Download: https://developer.android.com/studio#command-tools
2. Extract and set ANDROID_HOME environment variable

### Step 3: Setup Project

```powershell
# Navigate to the project
cd C:\Users\DELL.COM\Desktop\Darey\headcount\estate_capture_app

# Install dependencies
flutter pub get

# Check everything is ready
flutter doctor
```

### Step 4: Run the App

**Connect Phone via USB:**
```powershell
# Enable USB debugging on your Android phone:
# Settings → About Phone → Tap "Build Number" 7 times
# Settings → Developer Options → Enable USB Debugging

# Verify device is connected
flutter devices

# Run the app
flutter run
```

**OR Use Emulator:**
```powershell
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Run the app
flutter run
```

---

## 📱 Building APK for Installation

### Debug APK (for testing)
```powershell
flutter build apk --debug
```
**Output:** `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for production)
```powershell
flutter build apk --release
```
**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Install APK on Phone
```powershell
# Automatically install to connected device
flutter install

# OR manually copy APK to phone and install
```

---

## 🎯 App Usage Flow

### 1. First Launch
- App automatically loads 417 houses from CSV
- Shows splash screen with "Loading addresses..."
- Takes 1-2 seconds

### 2. Home Screen
- **Search bar** - Type to filter houses instantly
- **Filter icon** - Show only Occupied/Vacant/Follow-up needed
- **Info icon** - View statistics (total, visited, etc.)
- **Upload icon** - Export data to CSV

### 3. Edit House
- Tap any house card
- Update:
  - Occupancy (Occupied/Vacant)
  - Adults + Children (auto-calculates total)
  - Contact name, phone, role
  - Notes and follow-up
- **Save** - Returns to list
- **Save & Next** - Automatically opens next house

### 4. Quick Actions
- **Phone icon** - Call resident
- **Chat icon** - Open WhatsApp chat

### 5. Export Data
- Home → Upload icon
- Choose "All" or "Modified only"
- Tap "Export & Share"
- Share via WhatsApp, Email, or Drive

---

## 🛠️ Troubleshooting

### "Flutter not found"
```powershell
# Add Flutter to PATH
$env:Path += ";C:\src\flutter\bin"

# Verify
flutter --version
```

### "No devices found"
```powershell
# Check USB debugging is enabled
# Try different USB cable
# Install phone drivers

flutter devices
```

### "Build failed"
```powershell
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### "CSV not loading"
- Verify file exists: `assets/residents_seed.csv`
- Check `pubspec.yaml` includes `assets:` section

### "Can't make calls"
- Ensure phone app is installed
- Grant phone permission in app settings
- Check phone number is 11 digits

---

## 📊 Data Format

**CSV Columns (27 total):**
- S/N, House Address, Zone/Block, House Type, Unit/Flat
- Occupied?, Record Status, # Households, Monthly Due
- Payment Status, Last Payment Date, Adults, Children, Total Headcount
- Main Contact Name, Contact Role, Phone Number, WhatsApp Number, Email
- App Registered?, Phone Type, Notes/Issues
- Visit Date, Visited By, Data Verified?, Follow-up Needed?, Follow-up Date

**Import:** Place CSV at `assets/residents_seed.csv`  
**Export:** Tap upload icon → Export & Share

---

## ⚙️ Advanced Options

### Change App Name
Edit: `android/app/src/main/AndroidManifest.xml`
```xml
android:label="Your App Name"
```

### Change Package Name
Edit: `android/app/build.gradle`
```gradle
applicationId "com.yourcompany.appname"
```

### Generate Signed APK (for Play Store)
1. Create keystore:
   ```powershell
   keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
   ```

2. Create `android/key.properties`:
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=my-key-alias
   storeFile=<location of key>/my-release-key.jks
   ```

3. Update `android/app/build.gradle` with signing config

4. Build:
   ```powershell
   flutter build apk --release
   ```

---

## 📞 Support Contacts

**Issues?**
- Check README.md for detailed docs
- Run `flutter doctor` to diagnose problems
- Check Flutter docs: https://docs.flutter.dev

---

## ✅ Checklist

Before deploying:
- [ ] CSV file is in `assets/` folder
- [ ] App runs on test device
- [ ] Search works correctly
- [ ] Can edit and save records
- [ ] Phone/WhatsApp launches work
- [ ] Export generates valid CSV
- [ ] APK builds successfully

**Ready to go!** 🎉
