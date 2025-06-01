# Home Assistant Dashboard for Android - Developer Documentation

This document explains the key components of the Home Assistant Dashboard app and recent changes made to improve functionality.

## Overview

The Home Assistant Dashboard for Android is designed to:
- Act as a launcher (blocks app switching, starts on reboot)
- Discover Home Assistant instances on network with manual URL entry option
- Require long-term token authentication
- Display various widgets with live updates
- Support configurable captions and icons

## Key Components

### Architecture

The app follows a BLoC pattern architecture:
- **BLoCs**: Handle state management (dashboard_bloc, home_assistant_bloc, theme_bloc, launcher_bloc)
- **Services**: Handle API communication and storage
- **Widgets**: UI components for different entity types
- **Screens**: Main app screens (dashboard, settings, setup)

### Real-time Updates

The app uses WebSocket connections to Home Assistant for real-time state updates:
1. `home_assistant_api_service.dart` establishes WebSocket connection to `/api/websocket`
2. Authenticates with the long-term access token
3. Subscribes to `state_changed` events
4. Streams state updates to listeners (primarily the DashboardBloc)
5. UI updates automatically when state changes occur

### Widget System

Widgets are created using a factory pattern:
- `WidgetCardFactory` creates appropriate widget instances
- All widgets extend `BaseWidgetCard`
- Widget types include: Time, Light, Switch, Blind, Lock, Climate, Static

### Recent Fixes

#### Icon Display Fix

Fixed issues with MDI (Material Design Icons) display:
- Removed unsupported icon names from `IconHelper` class
- Added better error logging for missing icons
- Expanded support for common Home Assistant icons

#### Switch Widget Improvements

Enhanced the switch widget functionality:
- Made the entire widget area clickable
- Improved visual feedback with color changes and bold text for ON state
- Ensured switches respond to both:
  - Direct user interaction via taps
  - External state changes from Home Assistant

## Testing

When testing the app, verify:
1. Icons display correctly, including "mdi:ceiling-light"
2. Switches can be toggled by tapping anywhere in the widget
3. Switch state updates when toggled from Home Assistant UI
4. App starts automatically after device reboot

## Future Improvements

Potential areas for enhancement:
1. Add more widget types (media player, camera)
2. Support for Home Assistant custom themes
3. Improved grid layout with drag-and-drop positioning
4. Quick action panel for commonly used entities
