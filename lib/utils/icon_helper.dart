import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/icon_map.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class IconHelper {
  static IconData getIconData(String icon) {
    // Handle material design icons with mdi: prefix
    var iconName = icon;
    if (icon.startsWith('mdi:')) {
      iconName = icon.substring(4); // Remove 'mdi:' prefix
    }

    final iconData = _getMdiIcon(iconName);
    if (iconData != null) {
      return iconData;
    }

    // Handle special cases for custom icons
    if (iconName == 'window-shutter' || iconName == 'windowShutter') {
      // Return a suitable alternative from Material icons
      return Icons.blinds;  // or Icons.vertical_split
    }
    if (iconName == 'window-shutter-closed' || iconName == 'windowShutterClosed') {
      // Return a suitable alternative from Material icons
      return Icons.blinds_closed;  // or Icons.vertical_split
    }

    // Fallback to a default icon if the specified one is not found
    return Icons.help_outline;
  }
  
  static IconData? _getMdiIcon(String iconName) {
    // Convert from kebab-case (used in HA) to camelCase (used in Flutter MDI)
    final camelCaseName = _convertToCamelCase(iconName);
    
    // Try to access the icon directly using reflection
    try {
      // Use the byName approach with dart:mirrors would be ideal, but it's not available in Flutter
      // Instead, try to access common icons directly
      switch (camelCaseName) {
        // Lighting related icons
        case 'lightbulb': return MdiIcons.lightbulb;
        case 'lightbulbOutline': return MdiIcons.lightbulbOutline;
        case 'lightbulbOn': return MdiIcons.lightbulbOn;
        case 'lightbulbOff': return MdiIcons.lightbulbOff;
        case 'ceilingLight': return MdiIcons.ceilingLight;
        case 'floorLamp': return MdiIcons.floorLamp;
        case 'lamp': return MdiIcons.lamp;
        case 'ledStrip': return MdiIcons.ledStrip;
        case 'lightSwitch': return MdiIcons.lightSwitch;
        
        // Blinds and curtains
        case 'blindsVertical': return MdiIcons.blindsVertical;
        case 'blindsHorizontal': return MdiIcons.blindsHorizontal;
        case 'windowShutter': return MdiIcons.windowShutter;
        case 'windowShutterOpen': return MdiIcons.windowShutterOpen;
        case 'windowShutterClosed': return Icons.blinds_closed;
        case 'curtains': return MdiIcons.curtains;
        case 'curtainsClosed': return MdiIcons.curtainsClosed;
        case 'blinds': return MdiIcons.blinds;
        case 'blindsOpen': return MdiIcons.blindsOpen;
        case 'blindsVerticalClosed': return MdiIcons.blindsVerticalClosed;
        case 'blindsHorizontalClosed': return MdiIcons.blindsHorizontalClosed;
        case 'window-shutter': return MdiIcons.windowShutter;
        case 'windowOpen': return MdiIcons.windowOpen;
        case 'windowClosed': return MdiIcons.windowClosed;
        case 'rollerShade': return MdiIcons.rollerShade;
        case 'rollerShadeClosed': return MdiIcons.rollerShadeClosed;


        // Power and switches
        case 'power': return MdiIcons.power;
        case 'powerOff': return MdiIcons.powerOff;
        case 'powerOn': return MdiIcons.powerOn;
        case 'powerSocket': return MdiIcons.powerSocket;
        case 'toggleSwitchOff': return MdiIcons.toggleSwitchOff;
        case 'toggleSwitchOffOutline': return MdiIcons.toggleSwitchOffOutline;
        case 'toggleSwitchOutline': return MdiIcons.toggleSwitchOutline;
        
        // Climate and temperature
        case 'thermometer': return MdiIcons.thermometer;
        case 'temperatureCelsius': return MdiIcons.temperatureCelsius;
        case 'airConditioner': return MdiIcons.airConditioner;
        case 'fan': return MdiIcons.fan;
        case 'thermostat': return MdiIcons.thermostat;
        case 'radiator': return MdiIcons.radiator;
        
        // Security
        case 'lock': return MdiIcons.lock;
        case 'lockOpen': return MdiIcons.lockOpen;
        case 'lockAlert': return MdiIcons.lockAlert;
        case 'doorClosed': return MdiIcons.doorClosed;
        case 'doorOpen': return MdiIcons.doorOpen;
        
        // General icons
        case 'home': return MdiIcons.home;
        case 'homeOutline': return MdiIcons.homeOutline;
        case 'clock': return MdiIcons.clock;
        case 'clockOutline': return MdiIcons.clockOutline;
        case 'cog': return MdiIcons.cog;
        case 'cogOutline': return MdiIcons.cogOutline;
        case 'alert': return MdiIcons.alert;
        case 'alertOutline': return MdiIcons.alertOutline;
        case 'information': return MdiIcons.information;
        case 'informationOutline': return MdiIcons.informationOutline;
        
        // Media and entertainment
        case 'television': return MdiIcons.television;
        case 'televisionBox': return MdiIcons.televisionBox;
        case 'speaker': return MdiIcons.speaker;
        case 'speakerOff': return MdiIcons.speakerOff;
        case 'volumeHigh': return MdiIcons.volumeHigh;
        case 'volumeMedium': return MdiIcons.volumeMedium;
        case 'volumeLow': return MdiIcons.volumeLow;
        case 'volumeOff': return MdiIcons.volumeOff;
        case 'play': return MdiIcons.play;
        case 'pause': return MdiIcons.pause;
        case 'stop': return MdiIcons.stop;
        
        // Weather
        case 'weather': return MdiIcons.weatherPartlyCloudy;
        case 'weatherSunny': return MdiIcons.weatherSunny;
        case 'weatherCloudy': return MdiIcons.weatherCloudy;
        case 'weatherRainy': return MdiIcons.weatherRainy;
        case 'weatherSnowy': return MdiIcons.weatherSnowy;
        case 'weatherWindy': return MdiIcons.weatherWindy;
        
        default: 
          // If the icon is not found, try iconMap
          final iconData = iconMap[camelCaseName];
          if (iconData != null) {
            return iconData;
          }

          print('Icon not found: $camelCaseName (from $iconName)');
          return MdiIcons.helpCircleOutline;
      }
    } catch (e) {
      print('Error accessing icon: $camelCaseName (from $iconName): $e');
      return MdiIcons.helpCircleOutline;
    }
  }
  
  static String _convertToCamelCase(String kebabCase) {
    List<String> parts = kebabCase.split('-');
    String camelCase = parts[0];
    
    for (int i = 1; i < parts.length; i++) {
      camelCase += parts[i][0].toUpperCase() + parts[i].substring(1);
    }
    
    return camelCase;
  }
}
