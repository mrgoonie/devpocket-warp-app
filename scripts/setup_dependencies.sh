#!/bin/bash

# DevPocket Build Environment Setup Script
# Automates installation and configuration of development dependencies

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check if running on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Check if running on Linux
is_linux() {
    [[ "$OSTYPE" == "linux-gnu"* ]]
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print banner
print_banner() {
    echo "🚀 DevPocket Build Environment Setup"
    echo "===================================="
    echo "This script will help set up your development environment"
    echo "for building the DevPocket Flutter application."
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "pubspec.yaml" ]]; then
        print_error "Please run this script from the DevPocket project root directory"
        exit 1
    fi
    
    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "Internet connection required for downloading dependencies"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Install Homebrew on macOS
install_homebrew() {
    if is_macos && ! command_exists brew; then
        print_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add to PATH
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
            export PATH="/opt/homebrew/bin:$PATH"
        fi
        
        print_success "Homebrew installed"
    fi
}

# Install Java JDK 17
install_java() {
    print_info "Checking Java JDK 17..."
    
    if command_exists java; then
        java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [[ "$java_version" -ge 17 ]]; then
            print_success "Java JDK $java_version already installed"
            return
        fi
    fi
    
    print_info "Installing Java JDK 17..."
    
    if is_macos; then
        if command_exists brew; then
            brew install openjdk@17
            
            # Set up environment
            echo 'export JAVA_HOME=/opt/homebrew/opt/openjdk@17' >> ~/.zshrc
            echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
            export JAVA_HOME=/opt/homebrew/opt/openjdk@17
            export PATH="$JAVA_HOME/bin:$PATH"
        else
            print_warning "Please install Java JDK 17 manually from https://adoptium.net/"
        fi
    elif is_linux; then
        if command_exists apt; then
            sudo apt update
            sudo apt install -y openjdk-17-jdk
            
            # Set JAVA_HOME
            echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
            export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
        elif command_exists yum; then
            sudo yum install -y java-17-openjdk-devel
        else
            print_warning "Please install Java JDK 17 manually"
        fi
    fi
    
    print_success "Java JDK 17 installation completed"
}

# Install Flutter SDK
install_flutter() {
    print_info "Checking Flutter SDK..."
    
    if command_exists flutter; then
        flutter_version=$(flutter --version | grep "Flutter" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        # Compare version (simplified - assumes semantic versioning)
        if [[ "$flutter_version" > "3.24.0" ]] || [[ "$flutter_version" == "3.24.0" ]]; then
            print_success "Flutter $flutter_version already installed"
            return
        fi
    fi
    
    print_info "Flutter not found or version too old. Please install Flutter manually."
    print_info "Visit: https://docs.flutter.dev/get-started/install"
    
    if is_macos && command_exists brew; then
        print_info "You can also install Flutter via Homebrew:"
        print_info "brew install --cask flutter"
    fi
    
    print_warning "Please install Flutter and add it to your PATH, then re-run this script"
    exit 1
}

# Install Android Studio or SDK tools
install_android() {
    print_info "Checking Android development environment..."
    
    # Check if Android SDK is already configured
    if [[ -n "$ANDROID_HOME" ]] && [[ -d "$ANDROID_HOME" ]]; then
        print_success "Android SDK found at: $ANDROID_HOME"
        return
    fi
    
    print_warning "Android SDK not found"
    print_info "Android development requires Android Studio or SDK command line tools"
    print_info ""
    print_info "Options:"
    print_info "1. Install Android Studio (Recommended): https://developer.android.com/studio"
    print_info "2. Install command line tools only: https://developer.android.com/studio#downloads"
    print_info ""
    
    if is_macos && command_exists brew; then
        print_info "You can install Android Studio via Homebrew:"
        print_info "brew install --cask android-studio"
        echo ""
        read -p "Install Android Studio via Homebrew? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install --cask android-studio
            print_success "Android Studio installed via Homebrew"
            print_info "Please launch Android Studio to complete SDK setup"
        fi
    fi
    
    # Set up environment variables
    if is_macos; then
        android_sdk_path="$HOME/Library/Android/sdk"
    elif is_linux; then
        android_sdk_path="$HOME/Android/Sdk"
    fi
    
    if [[ -d "$android_sdk_path" ]]; then
        echo "export ANDROID_HOME=$android_sdk_path" >> ~/.zshrc 2>/dev/null || echo "export ANDROID_HOME=$android_sdk_path" >> ~/.bashrc
        echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> ~/.zshrc 2>/dev/null || echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> ~/.bashrc
        echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc 2>/dev/null || echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc
        
        export ANDROID_HOME=$android_sdk_path
        export PATH=$PATH:$ANDROID_HOME/emulator
        export PATH=$PATH:$ANDROID_HOME/platform-tools
        
        print_success "Android environment variables configured"
    fi
}

# Install iOS dependencies (macOS only)
install_ios() {
    if ! is_macos; then
        return
    fi
    
    print_info "Checking iOS development environment..."
    
    # Check Xcode
    if ! command_exists xcode-select || ! xcode-select -p >/dev/null 2>&1; then
        print_warning "Xcode not found"
        print_info "Please install Xcode from the Mac App Store"
        print_info "After installation, run: sudo xcode-select --install"
    else
        print_success "Xcode found"
    fi
    
    # Check CocoaPods
    if ! command_exists pod; then
        print_info "Installing CocoaPods..."
        if command_exists brew; then
            brew install cocoapods
        else
            sudo gem install cocoapods
        fi
        print_success "CocoaPods installed"
    else
        print_success "CocoaPods already installed"
    fi
}

# Install Flutter dependencies
install_flutter_dependencies() {
    print_info "Installing Flutter dependencies..."
    
    # Clean any existing build files
    flutter clean
    
    # Get dependencies
    flutter pub get
    
    print_success "Flutter dependencies installed"
}

# Install iOS dependencies if on macOS
install_ios_dependencies() {
    if ! is_macos; then
        return
    fi
    
    if [[ -f "ios/Podfile" ]]; then
        print_info "Installing iOS dependencies..."
        cd ios
        pod install --repo-update
        cd ..
        print_success "iOS dependencies installed"
    fi
}

# Configure Android local.properties
configure_android() {
    print_info "Configuring Android build..."
    
    if [[ ! -f "android/local.properties" ]]; then
        if [[ -f "android/local.properties.example" ]]; then
            print_info "Creating android/local.properties from example..."
            
            # Copy example file
            cp android/local.properties.example android/local.properties
            
            # Update paths
            if [[ -n "$ANDROID_HOME" ]]; then
                if is_macos; then
                    sed -i '' "s|/Users/\[USERNAME\]/Library/Android/sdk|$ANDROID_HOME|g" android/local.properties
                    sed -i '' "s|/Users/\[USERNAME\]/flutter|$(which flutter | sed 's|/bin/flutter||')|g" android/local.properties
                else
                    sed -i "s|/Users/\[USERNAME\]/Library/Android/sdk|$ANDROID_HOME|g" android/local.properties
                    sed -i "s|/Users/\[USERNAME\]/flutter|$(which flutter | sed 's|/bin/flutter||')|g" android/local.properties
                fi
            fi
            
            print_success "android/local.properties configured"
        else
            print_warning "android/local.properties.example not found"
            print_info "Flutter will generate local.properties automatically"
        fi
    else
        print_success "android/local.properties already exists"
    fi
}

# Run validation
validate_setup() {
    print_info "Validating setup..."
    
    if [[ -f "scripts/validate_build_env.dart" ]]; then
        dart scripts/validate_build_env.dart
    else
        print_warning "Validation script not found - running flutter doctor instead"
        flutter doctor
    fi
}

# Display next steps
show_next_steps() {
    echo ""
    print_success "Setup completed!"
    echo ""
    print_info "Next steps:"
    echo "1. Restart your terminal or run: source ~/.zshrc (or ~/.bashrc on Linux)"
    echo "2. Run: flutter doctor    # to verify installation"
    echo "3. Run: flutter run       # to start the app"
    echo ""
    
    if is_macos; then
        print_info "iOS Development:"
        echo "• Make sure Xcode is installed from the Mac App Store"
        echo "• Run iOS simulator: open -a Simulator"
    fi
    
    print_info "Android Development:"
    echo "• Launch Android Studio to complete SDK setup"
    echo "• Create an Android Virtual Device (AVD) for testing"
    echo "• Accept Android SDK licenses: flutter doctor --android-licenses"
    echo ""
    print_info "For detailed setup instructions, see: docs/BUILD_ENVIRONMENT.md"
}

# Main execution
main() {
    print_banner
    check_prerequisites
    
    # Install dependencies
    install_homebrew
    install_java
    install_flutter
    install_android
    install_ios
    
    # Configure project
    install_flutter_dependencies
    configure_android
    install_ios_dependencies
    
    # Validate
    validate_setup
    
    # Show next steps
    show_next_steps
}

# Run main function
main "$@"