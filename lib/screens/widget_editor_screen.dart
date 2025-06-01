import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/home_assistant_bloc.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';
import 'package:ha_flutter_dashboard/utils/icon_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:ha_flutter_dashboard/widgets/widget_card_factory.dart';
import 'package:ha_flutter_dashboard/widgets/popup_grid_helper.dart';
import 'package:ha_flutter_dashboard/widgets/group_widget_helper.dart';

class WidgetEditorScreen extends StatefulWidget {
  final DashboardWidget widget;
  final bool isNew;

  const WidgetEditorScreen({
    Key? key,
    required this.widget,
    required this.isNew,
  }) : super(key: key);

  @override
  State<WidgetEditorScreen> createState() => _WidgetEditorScreenState();
}

class _WidgetEditorScreenState extends State<WidgetEditorScreen> {
  late final TextEditingController _captionController;
  late final TextEditingController _iconController;
  late final TextEditingController _entityIdController;
  late String _selectedWidgetType;
  late Map<String, dynamic> _config;
  late double _widthPx;
  late double _heightPx;

  // For entity selection
  bool _isLoadingEntities = false;
  Map<String, List<EntityState>> _entitiesByDomain = {};
  List<DropdownMenuItem<String>> _entityItems = [];
  HomeAssistantApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.widget.caption);
    _iconController = TextEditingController(text: widget.widget.icon);
    _entityIdController = TextEditingController(text: widget.widget.entityId);
    _selectedWidgetType = widget.widget.type;
    _config = Map<String, dynamic>.from(widget.widget.config);
    _widthPx = widget.widget.widthPx;
    _heightPx = widget.widget.heightPx;

    // Initialize API service and load entities
    final haState = context.read<HomeAssistantBloc>().state;
    if (haState is HomeAssistantLoaded &&
        haState.selectedInstance != null &&
        haState.token != null) {
      final storageService = context.read<StorageService>();
      _apiService = HomeAssistantApiService(
        instance: haState.selectedInstance!,
        token: haState.token!,
        storageService: storageService,
      );
      _loadEntities();
    }
  }

  Future<void> _loadEntities() async {
    setState(() {
      _isLoadingEntities = true;
    });

    try {
      if (_apiService != null) {
        final entitiesByDomain = await _apiService!.getEntitiesByDomain();
        setState(() {
          _entitiesByDomain = entitiesByDomain;
          _buildEntityDropdownItems();
          _isLoadingEntities = false;
        });
      }
    } catch (e) {
      print('Error loading entities: $e');
      setState(() {
        _isLoadingEntities = false;
      });
    }
  }

  void _buildEntityDropdownItems() {
    List<DropdownMenuItem<String>> items = [];

    // Add empty item
    items.add(const DropdownMenuItem<String>(
      value: '',
      child: Text('Select an entity'),
    ));

    // Get relevant domain types based on the selected widget type
    List<String> relevantDomains = _getRelevantDomainsForWidgetType();

    // Add entities by domain
    _entitiesByDomain.forEach((domain, entities) {
      // Skip domains that aren't relevant for this widget type if not using static widget
      if (!relevantDomains.contains(domain) &&
          _selectedWidgetType != AppConstants.widgetTypeStatic) {
        return;
      }

      // Add domain header
      items.add(DropdownMenuItem<String>(
        value: null,
        enabled: false,
        child: Text(
          domain.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ));

      // Add entities for this domain
      for (final entity in entities) {
        final friendlyName = entity.attributes['friendly_name'] ?? entity.entityId;
        items.add(DropdownMenuItem<String>(
          value: entity.entityId,
          child: Text(friendlyName.toString()),
        ));
      }
    });

    setState(() {
      _entityItems = items;
    });
  }

  List<String> _getRelevantDomainsForWidgetType() {
    switch (_selectedWidgetType) {
      case AppConstants.widgetTypeLight:
        return ['light'];
      case AppConstants.widgetTypeSwitch:
        return ['switch', 'input_boolean'];
      case AppConstants.widgetTypeBlind:
        return ['cover'];
      case AppConstants.widgetTypeLock:
        return ['lock'];
      case AppConstants.widgetTypeClimate:
        return ['climate'];
      case AppConstants.widgetTypeStatic:
        // For static widgets, all domains are relevant
        return _entitiesByDomain.keys.toList();
      case AppConstants.widgetTypeSeparator:
      case AppConstants.widgetTypeLabel:
      case AppConstants.widgetTypeTime:
        // No entities needed for these widget types
        return [];
      default:
        return [];
    }
  }

  void _onEntitySelected(String? entityId) {
    if (entityId == null || entityId.isEmpty) {
      return;
    }

    setState(() {
      _entityIdController.text = entityId;
    });

    // Find the selected entity
    EntityState? selectedEntity;
    for (final entities in _entitiesByDomain.values) {
      for (final entity in entities) {
        if (entity.entityId == entityId) {
          selectedEntity = entity;
          break;
        }
      }
      if (selectedEntity != null) break;
    }

    // Auto-fill caption and icon if entity was found
    if (selectedEntity != null) {
      // Set caption from friendly_name
      if (selectedEntity.attributes.containsKey('friendly_name')) {
        setState(() {
          _captionController.text = selectedEntity!.attributes['friendly_name'].toString();
        });
      }

      // Set icon if available
      if (selectedEntity.attributes.containsKey('icon')) {
        final icon = selectedEntity.attributes['icon'];
        if (icon != null && icon.toString().isNotEmpty) {
          setState(() {
            _iconController.text = icon.toString();
          });
        }
      } else {
        // Set default icon based on domain
        final domain = entityId.split('.').first;
        String defaultIcon = 'mdi:help-circle-outline';

        switch (domain) {
          case 'light':
            defaultIcon = 'mdi:lightbulb';
            break;
          case 'switch':
            defaultIcon = 'mdi:toggle-switch';
            break;
          case 'cover':
            defaultIcon = 'mdi:window-shutter';
            break;
          case 'climate':
            defaultIcon = 'mdi:thermostat';
            break;
          case 'lock':
            defaultIcon = 'mdi:lock';
            break;
          case 'sensor':
            defaultIcon = 'mdi:gauge';
            break;
          case 'binary_sensor':
            defaultIcon = 'mdi:checkbox-marked-circle-outline';
            break;
        }

        setState(() {
          _iconController.text = defaultIcon;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _iconController.dispose();
    _entityIdController.dispose();
    super.dispose();
  }

  bool _requiresEntityId() {
    if (_selectedWidgetType == AppConstants.widgetTypeRtspVideo) {
      return false;
    }
    // Group widget does not require entity ID
    return _selectedWidgetType != AppConstants.widgetTypeTime && 
           _selectedWidgetType != AppConstants.widgetTypeSeparator &&
           _selectedWidgetType != AppConstants.widgetTypeLabel &&
           _selectedWidgetType != AppConstants.widgetTypeGroup;
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Widget Type'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedWidgetType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          items: [
            DropdownMenuItem(
              value: AppConstants.widgetTypeTime,
              child: _buildDropdownItem(Icons.access_time, 'Time'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeLight,
              child: _buildDropdownItem(Icons.lightbulb_outline, 'Light'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeSwitch,
              child: _buildDropdownItem(Icons.toggle_on, 'Switch'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeBlind,
              child: _buildDropdownItem(Icons.blinds, 'Blind/Cover'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeLock,
              child: _buildDropdownItem(Icons.lock_outline, 'Lock'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeClimate,
              child: _buildDropdownItem(Icons.thermostat, 'Climate'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeStatic,
              child: _buildDropdownItem(Icons.info_outline, 'Static State'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeSeparator,
              child: _buildDropdownItem(Icons.horizontal_rule, 'Separator'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeLabel,
              child: _buildDropdownItem(Icons.text_fields, 'Label'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeRtspVideo,
              child: _buildDropdownItem(Icons.videocam, 'RTSP Video'),
            ),
            DropdownMenuItem(
              value: AppConstants.widgetTypeGroup,
              child: _buildDropdownItem(Icons.folder, 'Group'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedWidgetType = value;
                // Reset config when changing type
                _config = {};
                // Rebuild entity dropdown items to filter by new type
                _buildEntityDropdownItems();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdownItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Widget Size (pixels)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Width (px)'),
                  Slider(
                    value: _widthPx,
                    min: 50,
                    max: 800,
                    divisions: 75,
                    label: _widthPx.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        _widthPx = value;
                      });
                    },
                  ),
                  Text('${_widthPx.round()} px'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Height (px)'),
                  Slider(
                    value: _heightPx,
                    min: 50,
                    max: 800,
                    divisions: 75,
                    label: _heightPx.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        _heightPx = value;
                      });
                    },
                  ),
                  Text('${_heightPx.round()} px'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSpecificConfig() {
    switch (_selectedWidgetType) {
      case AppConstants.widgetTypeRtspVideo:
        return _buildRtspVideoConfig();
      case AppConstants.widgetTypeTime:
        return _buildTimeConfig();
      case AppConstants.widgetTypeLight:
        return _buildLightConfig();
      case AppConstants.widgetTypeSwitch:
        return _buildSimplifiedViewConfig();
      case AppConstants.widgetTypeBlind:
        return _buildSimplifiedViewConfig();
      case AppConstants.widgetTypeLock:
        return _buildSimplifiedViewConfig();
      case AppConstants.widgetTypeClimate:
        return _buildSimplifiedViewConfig();
      case AppConstants.widgetTypeSeparator:
        return _buildSeparatorConfig();
      case AppConstants.widgetTypeLabel:
        return _buildLabelConfig();
      case AppConstants.widgetTypeStatic:
        return Container(); // No specific config for static
      case AppConstants.widgetTypeGroup:
        return _buildGroupConfig();
      default:
        return Container();
    }
  }

  Widget _buildLightConfig() {
    // Get current simplified view setting
    final useSimplifiedView = _config[AppConstants.configUseSimplifiedView] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Light Widget Options'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Use Simplified View'),
          subtitle: const Text('Shows minimal controls with detailed popup on long press'),
          value: useSimplifiedView,
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configUseSimplifiedView] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSimplifiedViewConfig() {
    // Get current simplified view setting
    final useSimplifiedView = _config[AppConstants.configUseSimplifiedView] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Widget Display Options'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Use Simplified View'),
          subtitle: const Text('Shows minimal controls with detailed popup on long press'),
          value: useSimplifiedView,
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configUseSimplifiedView] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTimeConfig() {
    final showSeconds = _config['showSeconds'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Time Widget Options'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Show Seconds'),
          value: showSeconds,
          onChanged: (value) {
            setState(() {
              _config['showSeconds'] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSeparatorConfig() {
    // Get current values from config or use defaults
    final separatorStyle = _config[AppConstants.configSeparatorStyle] ?? 'line';
    final separatorColor = _config[AppConstants.configSeparatorColor] ?? 'grey';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Separator Style'),
        const SizedBox(height: 8),
        // Dropdown for separator style selection
        DropdownButtonFormField<String>(
          value: separatorStyle,
          decoration: const InputDecoration(
            labelText: 'Style',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'line', child: Text('Line')),
            DropdownMenuItem(value: 'thick', child: Text('Thick Line')),
            DropdownMenuItem(value: 'dashed', child: Text('Dashed Line')),
            DropdownMenuItem(value: 'dotted', child: Text('Dotted Line')),
            DropdownMenuItem(value: 'empty', child: Text('Empty Space')),
          ],
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configSeparatorStyle] = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Dropdown for separator color selection
        DropdownButtonFormField<String>(
          value: separatorColor,
          decoration: const InputDecoration(
            labelText: 'Color',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'grey', child: Text('Grey')),
            DropdownMenuItem(value: 'black', child: Text('Black')),
            DropdownMenuItem(value: 'white', child: Text('White')),
            DropdownMenuItem(value: 'red', child: Text('Red')),
            DropdownMenuItem(value: 'blue', child: Text('Blue')),
            DropdownMenuItem(value: 'green', child: Text('Green')),
            DropdownMenuItem(value: 'yellow', child: Text('Yellow')),
            DropdownMenuItem(value: 'orange', child: Text('Orange')),
            DropdownMenuItem(value: 'purple', child: Text('Purple')),
            DropdownMenuItem(value: 'pink', child: Text('Pink')),
          ],
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configSeparatorColor] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildLabelConfig() {
    // Get current values from config or use defaults
    final labelSize = _config[AppConstants.configLabelSize] ?? 'medium';
    final labelAlign = _config[AppConstants.configLabelAlign] ?? 'center';
    final labelBold = _config[AppConstants.configLabelBold] ?? false;
    final labelItalic = _config[AppConstants.configLabelItalic] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Label Style'),
        const SizedBox(height: 8),
        
        // Dropdown for text size selection
        DropdownButtonFormField<String>(
          value: labelSize,
          decoration: const InputDecoration(
            labelText: 'Text Size',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'small', child: Text('Small')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'large', child: Text('Large')),
            DropdownMenuItem(value: 'xlarge', child: Text('Extra Large')),
          ],
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configLabelSize] = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Dropdown for text alignment selection
        DropdownButtonFormField<String>(
          value: labelAlign,
          decoration: const InputDecoration(
            labelText: 'Text Alignment',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'left', child: Text('Left')),
            DropdownMenuItem(value: 'center', child: Text('Center')),
            DropdownMenuItem(value: 'right', child: Text('Right')),
          ],
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configLabelAlign] = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Checkboxes for text style options
        CheckboxListTile(
          title: const Text('Bold Text'),
          value: labelBold,
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configLabelBold] = value;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Italic Text'),
          value: labelItalic,
          onChanged: (value) {
            setState(() {
              _config[AppConstants.configLabelItalic] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRtspVideoConfig() {
    final url = _config['url'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RTSP Stream URL'),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'RTSP URL',
            border: OutlineInputBorder(),
            hintText: 'rtsp://...',
          ),
          controller: TextEditingController(text: url),
          onChanged: (value) {
            setState(() {
              _config['url'] = value;
            });
          },
        ),
        const SizedBox(height: 8),
        const Text('No audio will be played. Only video is supported.'),
      ],
    );
  }

  Widget _buildGroupConfig() {
    // Ensure _config and groupWidgets are initialized properly
    if (_config['groupWidgets'] == null) {
      _config['groupWidgets'] = [];
    }
    
    // Use our helper to ensure consistent formatting of group widgets
    final List<Map<String, dynamic>> groupWidgets = 
        GroupWidgetHelper.sanitizeGroupWidgets(_config['groupWidgets']);
    
    // Make sure the config always has an updated sanitized version with proper typing
    _config['groupWidgets'] = List<Map<String, dynamic>>.from(groupWidgets);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Group Widgets'),
        const SizedBox(height: 8),
        if (groupWidgets.isEmpty)
          const Text('No widgets in this group.'),
        if (groupWidgets.isNotEmpty)
          ...groupWidgets.asMap().entries.map<Widget>((entry) {
            final int index = entry.key;
            final gw = entry.value;
            return ListTile(
              leading: const Icon(Icons.widgets),
              title: Text(gw['caption'] ?? 'Widget'),
              subtitle: Text(gw['type'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      // Open full widget editor for this child
                      final DashboardWidget childWidget = DashboardWidget(
                        id: gw['id']?.toString() ?? '',
                        type: gw['type']?.toString() ?? '',
                        entityId: gw['entityId']?.toString() ?? '',
                        caption: gw['caption']?.toString() ?? '',
                        icon: gw['icon']?.toString() ?? '',
                        config: gw['config'] != null ? Map<String, dynamic>.from(gw['config']) : <String, dynamic>{},
                        row: 0,
                        column: 0,
                        widthPx: gw['widthPx'] is double ? gw['widthPx'] : (gw['widthPx'] != null ? double.tryParse(gw['widthPx'].toString()) ?? 100.0 : 100.0),
                        heightPx: gw['heightPx'] is double ? gw['heightPx'] : (gw['heightPx'] != null ? double.tryParse(gw['heightPx'].toString()) ?? 100.0 : 100.0),
                        positionX: gw['positionX'] is double ? gw['positionX'] : (gw['positionX'] != null ? double.tryParse(gw['positionX'].toString()) ?? 0.0 : 0.0),
                        positionY: gw['positionY'] is double ? gw['positionY'] : (gw['positionY'] != null ? double.tryParse(gw['positionY'].toString()) ?? 0.0 : 0.0),
                      );
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WidgetEditorScreen(
                            widget: childWidget,
                            isNew: false,
                          ),
                        ),
                      );
                      if (result is DashboardWidget) {
                        setState(() {
                          // Create a proper Map<String, dynamic> for the updated widget
                          final updatedWidget = <String, dynamic>{
                            'id': result.id,
                            'type': result.type,
                            'entityId': result.entityId,
                            'caption': result.caption,
                            'icon': result.icon,
                            'config': Map<String, dynamic>.from(result.config),
                            'widthPx': result.widthPx,
                            'heightPx': result.heightPx,
                            'positionX': result.positionX,
                            'positionY': result.positionY,
                          };
                          
                          // Update the widget at the specific index
                          groupWidgets[index] = updatedWidget;
                          
                          // Ensure a proper sanitized list is stored in config
                          _config['groupWidgets'] = List<Map<String, dynamic>>.from(groupWidgets);
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        groupWidgets.removeAt(index);
                        // Ensure we store a properly typed list
                        _config['groupWidgets'] = List<Map<String, dynamic>>.from(groupWidgets);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Widget to Group'),
          onPressed: () async {
            // Open full widget editor for a new child widget
            final DashboardWidget newChild = DashboardWidget(
              id: const Uuid().v4(),
              type: AppConstants.widgetTypeStatic,
              entityId: '',
              caption: 'New Widget',
              icon: 'mdi:widgets',
              config: {},
              row: 0,
              column: 0,
              widthPx: 100,
              heightPx: 100,
              positionX: 0,
              positionY: 0,
            );
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WidgetEditorScreen(
                  widget: newChild,
                  isNew: true,
                ),
              ),
            );
            if (result is DashboardWidget) {
              setState(() {
                // Create a properly typed Map<String, dynamic>
                final newWidget = <String, dynamic>{
                  'id': result.id,
                  'type': result.type,
                  'entityId': result.entityId,
                  'caption': result.caption,
                  'icon': result.icon,
                  'config': Map<String, dynamic>.from(result.config),
                  'widthPx': result.widthPx,
                  'heightPx': result.heightPx,
                  'positionX': result.positionX,
                  'positionY': result.positionY,
                };
                
                // Add to group widgets
                groupWidgets.add(newWidget);
                
                // Ensure we store a properly typed list
                _config['groupWidgets'] = List<Map<String, dynamic>>.from(groupWidgets);
              });
            }
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.grid_on),
          label: const Text('Edit Layout'),
          onPressed: () async {
            // Open draggable/resizable layout editor for group children
            final result = await showDialog<List<Map<String, dynamic>>>(
              context: context,
              barrierDismissible: false, // Prevent dismissal when tapping outside
              builder: (ctx) => Dialog(
                child: Stack(
                  children: [
                    SizedBox(
                      width: 700,
                      height: 500,
                      child: _GroupPopupGrid(
                        widgets: groupWidgets,
                        apiService: _apiService!,
                        entityStates: _entitiesByDomain.isEmpty ? {} : 
                          _entitiesByDomain.values.expand((list) => list)
                            .fold<Map<String, EntityState>>({}, (map, entity) {
                              map[entity.entityId] = entity;
                              return map;
                            }),
                        isDesktop: true,
                        isEditMode: true, // Enable edit mode for layout editor
                        onLayoutChanged: (updated) {
                          // Don't pop here, let the Done button handle it
                          // Navigator.of(ctx).pop(updated);
                        },
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: ElevatedButton(
                        onPressed: () {
                          // Save current layout and close dialog
                          Navigator.of(ctx).pop(groupWidgets);
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (result != null) {
              setState(() {
                // Make sure we store a properly typed list
                _config['groupWidgets'] = List<Map<String, dynamic>>.from(result);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildIconPreview() {
    IconData iconData = IconHelper.getIconData(_iconController.text);

    return Row(
      children: [
        const Text('Icon Preview: '),
        const SizedBox(width: 8),
        Icon(iconData, size: 24),
      ],
    );
  }

  void _saveWidget() {
    // Validate required fields
    if (_captionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption is required')),
      );
      return;
    }
    if (_iconController.text.isEmpty && 
        _selectedWidgetType != AppConstants.widgetTypeSeparator &&
        _selectedWidgetType != AppConstants.widgetTypeLabel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Icon is required')),
      );
      return;
    }
    if (_requiresEntityId() && _entityIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entity ID is required for this widget type')),
      );
      return;
    }
    
    // Special handling for group widgets to ensure proper format
    if (_selectedWidgetType == AppConstants.widgetTypeGroup) {
      // Ensure group widgets are properly sanitized before saving
      _config['groupWidgets'] = GroupWidgetHelper.sanitizeGroupWidgets(_config['groupWidgets']);
      debugPrint('Sanitized and saved ${(_config['groupWidgets'] as List).length} group widgets');
    }
    // Create updated widget
    final updatedWidget = widget.widget.copyWith(
      id: widget.isNew ? const Uuid().v4() : widget.widget.id,
      type: _selectedWidgetType,
      entityId: _entityIdController.text,
      caption: _captionController.text,
      icon: _iconController.text,
      config: _config,
      widthPx: _widthPx,
      heightPx: _heightPx,
      row: widget.widget.row,
      column: widget.widget.column,
      positionX: widget.widget.positionX,
      positionY: widget.widget.positionY,
    );
    Navigator.pop(context, updatedWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add Widget' : 'Edit Widget'),
        actions: [
          TextButton(
            onPressed: _saveWidget,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                labelText: 'Caption',
                border: const OutlineInputBorder(),
                helperText: _selectedWidgetType == AppConstants.widgetTypeLabel 
                    ? 'This text will be displayed as the label content'
                    : _selectedWidgetType == AppConstants.widgetTypeSeparator
                        ? 'Optional caption for the separator'
                        : null,
              ),
            ),
            const SizedBox(height: 16),

            // Security Settings
            const Text(
              'Security',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Protected Widget'),
              subtitle: const Text('Requires dashboard to be unlocked to interact with this widget'),
              value: _config[AppConstants.configProtected] ?? false,
              onChanged: (value) {
                setState(() {
                  _config[AppConstants.configProtected] = value;
                });
              },
            ),
            const Divider(),
            const SizedBox(height: 8),

            TextField(
              controller: _iconController,
              decoration: InputDecoration(
                labelText: 'Icon (mdi:icon-name)',
                border: const OutlineInputBorder(),
                hintText: 'e.g., mdi:lightbulb',
                helperText: (_selectedWidgetType == AppConstants.widgetTypeSeparator || 
                             _selectedWidgetType == AppConstants.widgetTypeLabel)
                    ? 'Optional: Icon will be shown before text (if provided)'
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            _buildIconPreview(),
            const SizedBox(height: 16),

            if (_requiresEntityId()) ...[
              _isLoadingEntities 
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Entity',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      value: _entityIdController.text.isEmpty ? '' : _entityIdController.text,
                      items: _entityItems,
                      onChanged: _onEntitySelected,
                    ),
              const SizedBox(height: 8),
              TextField(
                controller: _entityIdController,
                decoration: const InputDecoration(
                  labelText: 'Entity ID (manual edit)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., light.living_room',
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildTypeSelector(),
            const SizedBox(height: 16),

            _buildSizeSelector(),
            const SizedBox(height: 16),

            _buildTypeSpecificConfig(),
          ],
        ),
      ),
    );
  }
}

class _GroupPopupGrid extends StatefulWidget {
  final List<Map<String, dynamic>> widgets;
  final HomeAssistantApiService apiService;
  final Map<String, EntityState> entityStates;
  final bool isDesktop;
  final bool isEditMode;
  final void Function(List<Map<String, dynamic>> updated)? onLayoutChanged;

  const _GroupPopupGrid({
    required this.widgets,
    required this.apiService,
    required this.entityStates,
    required this.isDesktop,
    this.isEditMode = true, // Default to edit mode in widget editor
    this.onLayoutChanged,
  });

  @override
  State<_GroupPopupGrid> createState() => _GroupPopupGridState();
}

class _GroupPopupGridState extends State<_GroupPopupGrid> {
  late List<Map<String, dynamic>> _positions;
  int? _selectedIndex;
  Offset? _dragOffset;
  // Add a local cache for fetched entity states
  final Map<String, EntityState> _fetchedEntityStates = {};

  @override
  void initState() {
    super.initState();
    _positions = widget.widgets.map<Map<String, dynamic>>((Map<String, dynamic> gw) => {
      'x': (gw['positionX'] as double?) ?? 0.0,
      'y': (gw['positionY'] as double?) ?? 0.0,
      'width': (gw['widthPx'] as double?) ?? 100.0,
      'height': (gw['heightPx'] as double?) ?? 100.0,
    }).toList();
    
    // Initialize entity states from props
    _initEntityStates();
    
    // Then pre-fetch any missing entity states
    _prefetchMissingEntityStates();
  }
  
  // Initialize our local cache with entity states from props
  void _initEntityStates() {
    // First copy all entity states from parent component
    for (final entry in widget.entityStates.entries) {
      _fetchedEntityStates[entry.key] = entry.value;
    }
  }
  
  // Pre-fetch entity states for all widgets that don't have states yet
  void _prefetchMissingEntityStates() {
    // Collect all entity IDs that need prefetching
    final List<String> entityIdsToFetch = [];
    
    for (final widgetData in widget.widgets) {
      final String? entityId = widgetData['entityId']?.toString();
      if (entityId != null && entityId.isNotEmpty && !_fetchedEntityStates.containsKey(entityId)) {
        entityIdsToFetch.add(entityId);
      }
    }
    
    if (entityIdsToFetch.isNotEmpty) {
      debugPrint('Prefetching ${entityIdsToFetch.length} entity states: ${entityIdsToFetch.join(', ')}');
      
      // Fetch all missing entity states in parallel for better performance
      Future.wait(
        entityIdsToFetch.map((entityId) => 
          widget.apiService.getState(entityId)
            .then((fetchedState) {
              // Only update state if still mounted
              if (mounted) {
                setState(() {
                  _fetchedEntityStates[entityId] = fetchedState;
                });
                debugPrint('✓ Entity state fetched for $entityId: ${fetchedState.state}');
              }
              return fetchedState;
            })
            .catchError((error) {
              debugPrint('✗ Error fetching state for $entityId: $error');
              // Need to return an EntityState or rethrow to match Future<EntityState> type
              throw error;
            })
        ),
      ).then((_) {
        // Force a rebuild of the UI if needed
        if (mounted) {
          setState(() {});
        }
      });
    }
    
  }

  void _onDragStart(int index, DragStartDetails details) {
    setState(() {
      _selectedIndex = index;
      _dragOffset = details.globalPosition;
    });
  }

  void _onDragUpdate(int index, DragUpdateDetails details) {
    if (_selectedIndex != index || _dragOffset == null) return;
    if (index < 0 || index >= _positions.length) return;
    
    setState(() {
      final dx = details.globalPosition.dx - _dragOffset!.dx;
      final dy = details.globalPosition.dy - _dragOffset!.dy;
      _positions[index]['x'] = (_positions[index]['x'] as double) + dx;
      _positions[index]['y'] = (_positions[index]['y'] as double) + dy;
      _dragOffset = details.globalPosition;
    });
  }

  void _onDragEnd(int index, DragEndDetails details) {
    setState(() {
      _selectedIndex = null;
      _dragOffset = null;
    });
    
    // Persist new position to group config if in edit mode
    if (widget.onLayoutChanged != null) {
      // Update the original widget list with new positions
      for (int i = 0; i < widget.widgets.length; i++) {
        if (i < _positions.length) {
          widget.widgets[i]['positionX'] = _positions[i]['x'] as double;
          widget.widgets[i]['positionY'] = _positions[i]['y'] as double;
          widget.widgets[i]['widthPx'] = _positions[i]['width'] as double;
          widget.widgets[i]['heightPx'] = _positions[i]['height'] as double;
        }
      }
      widget.onLayoutChanged!(widget.widgets);
    }
  }

  void _onResize(int index, double dx, double dy) {
    // Safety check
    if (index < 0 || index >= _positions.length) return;
    
    setState(() {
      final double currentWidth = _positions[index]['width'] as double;
      final double currentHeight = _positions[index]['height'] as double;
      _positions[index]['width'] = (currentWidth + dx).clamp(50.0, 800.0);
      _positions[index]['height'] = (currentHeight + dy).clamp(50.0, 800.0);
    });
    
    // Persist new size to group config if in edit mode
    if (widget.onLayoutChanged != null && index < widget.widgets.length) {
      widget.widgets[index]['widthPx'] = _positions[index]['width'] as double;
      widget.widgets[index]['heightPx'] = _positions[index]['height'] as double;
      widget.onLayoutChanged!(widget.widgets);
    }
  }
  
  // Helper method to get entity state for a specific widget
  // This ensures proper handling of entity state for widgets in the editor
  EntityState? _getEntityStateForWidget(int index) {
    try {
      // Check index is valid
      if (index < 0 || index >= widget.widgets.length) {
        debugPrint('_getEntityStateForWidget: Index $index out of bounds (${widget.widgets.length})');
        return null;
      }
      final String? entityId = widget.widgets[index]['entityId']?.toString();
      debugPrint('_getEntityStateForWidget: Called for index=$index entityId=$entityId');
      if (entityId == null || entityId.isEmpty) {
        debugPrint('_getEntityStateForWidget: Empty entityId for widget at index $index');
        return null;
      }
      // First check our local cache of fetched states
      if (_fetchedEntityStates.containsKey(entityId)) {
        debugPrint('_getEntityStateForWidget: Using cached entity state for $entityId: ${_fetchedEntityStates[entityId]!.state}');
        return _fetchedEntityStates[entityId];
      }
      // Then check if state exists in the provided entityStates
      EntityState? state = widget.entityStates[entityId];
      if (state != null) {
        debugPrint('_getEntityStateForWidget: Using original entity state for $entityId: ${state.state}');
        _fetchedEntityStates[entityId] = state;
        return state;
      }
      // Debug logging
      debugPrint('_getEntityStateForWidget: No entity state found for $entityId, fetching now');
      debugPrint('_getEntityStateForWidget: [MICROTASK SCHEDULED] $entityId');
      Future.microtask(() async {
        debugPrint('_getEntityStateForWidget: [MICROTASK STARTED] $entityId');
        try {
          debugPrint('_getEntityStateForWidget: [FETCH-START] $entityId');
          final fetchedState = await widget.apiService.getState(entityId);
          debugPrint('_getEntityStateForWidget: [FETCH-END] $entityId result=${fetchedState.state}');
          if (mounted) {
            debugPrint('_getEntityStateForWidget: Fetched state for $entityId: ${fetchedState.state}');
            setState(() {
              _fetchedEntityStates[entityId] = fetchedState;
            });
          } else {
            debugPrint('_getEntityStateForWidget: Not mounted after fetch for $entityId');
          }
        } catch (error, stack) {
          debugPrint('_getEntityStateForWidget: Error fetching state for $entityId: $error\n$stack');
        }
      });
      // Return null for now, the setState will trigger a rebuild with the fetched state
      return null;
    } catch (e, stack) {
      debugPrint('Error retrieving entity state: $e\n$stack');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('_GroupPopupGrid: _fetchedEntityStates=${_fetchedEntityStates.map((k,v)=>MapEntry(k,v.state))}');
    if (widget.widgets.isEmpty) {
      return const Center(child: Text('No widgets in this group.'));
    }
    
    // Log widget data for debugging
    debugPrint('_GroupPopupGrid: Building with ${_fetchedEntityStates.length} cached entity states');
    for (final gw in widget.widgets) {
      final entityId = gw['entityId']?.toString() ?? '';
      final hasEntityState = entityId.isNotEmpty && 
          (_fetchedEntityStates.containsKey(entityId) || widget.entityStates.containsKey(entityId));
      final stateValue = entityId.isNotEmpty ? 
          (_fetchedEntityStates[entityId]?.state ?? widget.entityStates[entityId]?.state ?? 'no data') : 'n/a';
      
      debugPrint('GroupPopupGrid: widget = ${gw['caption']} type=${gw['type']} entityId=$entityId hasState=$hasEntityState state=$stateValue pos=(${gw['positionX']},${gw['positionY']}) size=(${gw['widthPx']},${gw['heightPx']})');
    }
    
    return Stack(
      children: [
        for (int i = 0; i < widget.widgets.length; i++)
          Positioned(
            left: _positions[i]['x'],
            top: _positions[i]['y'],
            width: _positions[i]['width'],
            height: _positions[i]['height'],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // Ensure tap is captured and not passed through
              onTap: () => setState(() => widget.isEditMode ? _selectedIndex = i : null),
              onPanStart: widget.isDesktop && widget.isEditMode ? (details) => _onDragStart(i, details) : null,
              onPanUpdate: widget.isDesktop && widget.isEditMode ? (details) => _onDragUpdate(i, details) : null,
              onPanEnd: widget.isDesktop && widget.isEditMode ? (details) => _onDragEnd(i, details) : null,
              child: Stack(
                children: [
                  Material(
                    elevation: _selectedIndex == i ? 8 : 2,
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).cardColor, // Consistent background color
                    child: SizedBox(
                      width: _positions[i]['width'],
                      height: _positions[i]['height'],
                      child: Builder(
                        builder: (context) {
                          final entityId = widget.widgets[i]['entityId']?.toString() ?? '';
                          
                          // Get entity state, prioritizing our local cache
                          EntityState? entityState;
                          if (entityId.isNotEmpty) {
                            entityState = _fetchedEntityStates[entityId] ?? widget.entityStates[entityId];
                            
                            // If still null, trigger a fetch but show loading state
                            if (entityState == null) {
                              _getEntityStateForWidget(i);
                            }
                          }
                          debugPrint('WidgetCardFactory.createWidgetCard: entityId=$entityId entityState=${entityState?.state}');
                          return WidgetCardFactory.createWidgetCard(
                            widget: DashboardWidget(
                              id: widget.widgets[i]['id']?.toString() ?? '',
                              type: widget.widgets[i]['type']?.toString() ?? '',
                              entityId: entityId,
                              caption: widget.widgets[i]['caption']?.toString() ?? '',
                              icon: widget.widgets[i]['icon']?.toString() ?? '',
                              config: Map<String, dynamic>.from(widget.widgets[i]['config'] ?? {}),
                              row: 0,
                              column: 0,
                              widthPx: (_positions[i]['width'] as double),
                              heightPx: (_positions[i]['height'] as double),
                              positionX: (_positions[i]['x'] as double),
                              positionY: (_positions[i]['y'] as double),
                            ),
                            apiService: widget.apiService,
                            entityState: entityState,
                            isEditing: false,
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.isDesktop && widget.isEditMode && _selectedIndex == i)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque, // This makes the entire area respond to gestures
                        onPanUpdate: (details) => _onResize(i, details.delta.dx, details.delta.dy),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.open_in_full, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
