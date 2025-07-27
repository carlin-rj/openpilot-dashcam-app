#!/bin/bash

# OpenPilot Dashcam Viewer Flutter App Setup Script

set -e

echo "🚀 OpenPilot Dashcam Viewer Flutter App Setup"
echo "=============================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter first:"
    echo "  macOS: brew install --cask flutter"
    echo "  Or download from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"

# Check Flutter doctor
echo ""
echo "🔍 Checking Flutter environment..."
flutter doctor

# Get dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate code
echo ""
echo "🔧 Generating code..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Check available devices
echo ""
echo "📱 Available devices:"
flutter devices

echo ""
echo "✅ Setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Start the dashcam server:"
echo "   cd ../../../"
echo "   python system/dashcam_server/dashcam_server.py"
echo ""
echo "2. Run the Flutter app:"
echo "   flutter run -d <device>"
echo ""
echo "Available run commands:"
echo "  flutter run -d macos     # Run on macOS"
echo "  flutter run -d windows   # Run on Windows"
echo "  flutter run -d android   # Run on Android device/emulator"
echo "  flutter run -d ios       # Run on iOS device/simulator"
echo ""
echo "🔧 Build release versions:"
echo "  flutter build macos --release"
echo "  flutter build windows --release"
echo "  flutter build apk --release"
echo "  flutter build ios --release"
