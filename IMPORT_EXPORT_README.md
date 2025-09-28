# Widget Configuration Import/Export Feature

## Description
Added the ability to import and export Dashboard widget configuration in JSON format. Supports both local file operations and remote server communication via HTTP.

## Functions

### Export Configuration
1. **Local file** - Save configuration to device file
2. **Remote server** - Send configuration to server via POST request

### Import Configuration  
1. **Local file** - Load configuration from device file
2. **Remote server** - Get configuration from server via GET request

## Access to Function
The Import/Export functionality is now integrated into the main Settings screen. Navigate to Settings → Import/Export section at the bottom of the screen.

## JSON file format

```json
{
  "version": "1.0.0",
  "exportedAt": "2025-01-28T10:30:00.000Z",
  "appName": "Home Assistant Dashboard",
  "widgets": [
    {
      "id": "widget-id",
      "type": "switch|light|climate|label|...",
      "entityId": "entity.id",
      "caption": "Widget Caption",
      "icon": "mdi:icon-name",
      "config": {
        "useSimplifiedView": false,
        "protected": false
      },
      "row": 0,
      "column": 0,
      "widthPx": 100.0,
      "heightPx": 100.0,
      "positionX": 0.0,
      "positionY": 0.0
    }
  ],
  "metadata": {
    "platform": "android|ios|web|linux",
    "exportSource": "mobile_app"
  }
}
```

## Usage

### Export to File
1. Open Settings screen
2. Scroll down to "Import/Export" section
3. Click "Export to File" button
4. Choose save location

### Export to Server (POST)
1. Open Settings screen
2. Scroll down to "Import/Export" section
3. Enter server URL in the text field
4. Click "POST to Server" button

### Import from File  
1. Open Settings screen
2. Scroll down to "Import/Export" section
3. Click "Import from File" button
4. Select JSON configuration file
5. Review the preview
6. Click "Apply"

### Import from Server (GET)
1. Open Settings screen
2. Scroll down to "Import/Export" section
3. Enter server URL in the text field
4. Click "GET from Server" button
5. Review the preview
6. Click "Apply"

## ⚠️ Important Notes

- **Import will replace ALL existing widgets!**
- It's recommended to create a backup of current configuration before importing
- URL must be in `http://` or `https://` format
- JSON file must match the expected schema
- When working with HTTP servers, ensure CORS is configured correctly
- **URL persistence**: The server URL is automatically saved and restored when you return to settings
