# Estate Door-to-Door Capture App

A fast, offline-first Flutter mobile app for door-to-door estate headcount data collection.

## Features

✅ **Super-fast search** - Instantly filter 400+ houses by address, street, or zone  
✅ **Quick edit form** - Update occupancy, headcount, and contact info in seconds  
✅ **Offline-first** - All data stored locally with Hive (no internet required)  
✅ **Smart filtering** - Filter by Occupied/Vacant, Follow-up needed, Not visited  
✅ **Auto-calculations** - Total headcount auto-calculated from Adults + Children  
✅ **Export & Share** - Export CSV and share via WhatsApp, Email, or Drive  
✅ **Call/WhatsApp** - Quick actions to call or message residents  
✅ **Save & Next** - Quickly move through houses with one tap  

## Installation

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Android Studio or VS Code with Flutter extension
- Android device or emulator

### Setup Steps

1. **Clone or download this project**

2. **Navigate to the project directory**
   ```bash
   cd estate_capture_app
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Ensure CSV data is in place**
   - The CSV file should be at: `assets/residents_seed.csv`
   - Already included in the project

5. **Connect Android device or start emulator**
   ```bash
   flutter devices
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

## Building APK

### Debug APK (for testing)
```bash
flutter build apk --debug
```
APK will be at: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for distribution)
```bash
flutter build apk --release
```
APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Install APK on device
```bash
flutter install
```

## Usage

### Home Screen
1. **Search** - Type in the search bar to filter houses
2. **Filter** - Tap filter icon to show only Occupied/Vacant/Follow-up needed
3. **View Stats** - Tap info icon to see collection statistics
4. **Select House** - Tap any house to open the detail screen

### Edit House Details
1. **Update Status** - Select Occupied or Vacant
2. **Enter Headcount** - If occupied, enter Adults and Children (auto-calculates total)
3. **Add Contact** - Enter contact name, phone, and role
4. **Add Notes** - Add any notes or issues
5. **Set Follow-up** - Mark if follow-up is needed and set date
6. **Save** - Tap "Save" or "Save & Next" to move to the next house

### Quick Actions
- **Call** - Tap phone icon to call the resident
- **WhatsApp** - Tap chat icon to open WhatsApp conversation

### Export Data
1. Go to Home → Tap upload icon
2. Choose "All records" or "Modified only"
3. Tap "Export & Share CSV"
4. Choose how to share (WhatsApp, Email, Drive)

## Data Structure

The app imports and exports CSV files with these columns:

- S/N, House Address, Zone/Block, House Type, Unit/Flat
- Occupied?, Record Status, # Households, Monthly Due
- Payment Status, Last Payment Date
- Adults, Children, Total Headcount
- Main Contact Name, Contact Role, Phone Number
- WhatsApp Number, Email, App Registered?, Phone Type
- Notes/Issues, Visit Date, Visited By
- Data Verified?, Follow-up Needed?, Follow-up Date

## Technology Stack

- **Flutter** - UI framework
- **Riverpod** - State management
- **Hive** - Local NoSQL database (fast, offline-first)
- **CSV** - Data import/export
- **url_launcher** - Phone/WhatsApp integration
- **share_plus** - File sharing

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── resident.dart            # Data model
│   └── resident.g.dart          # Hive adapter (generated)
├── services/
│   └── database_service.dart    # Database operations
├── providers/
│   └── resident_provider.dart   # State management
└── screens/
    ├── home_screen.dart         # Main list view
    ├── resident_detail_screen.dart  # Edit form
    └── export_screen.dart       # Export functionality
```

## Performance

- Loads 417 records in < 2 seconds
- Search filters in < 100ms
- Instant save (no loading spinner)
- Works smoothly on low-end Android devices

## Troubleshooting

### App won't build
```bash
flutter clean
flutter pub get
flutter run
```

### Data not loading
- Check that `assets/residents_seed.csv` exists
- Verify `pubspec.yaml` includes assets section

### Can't make calls/open WhatsApp
- Ensure phone has dialer and WhatsApp installed
- Check app permissions in device settings

## Future Enhancements (Optional)

- Sync to Google Sheets via API
- Multi-user authentication
- Photo capture for houses
- GPS location tagging
- Offline maps integration

## License

This project is for private use.

## Support

For issues or questions, contact the development team.
"# Head-count-app" 
