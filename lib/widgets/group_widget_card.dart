import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';
import 'package:ha_flutter_dashboard/utils/icon_helper.dart';
import 'package:ha_flutter_dashboard/widgets/widget_card_factory.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/dashboard_bloc.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/widgets/group_widget_helper.dart';

class GroupWidgetCard extends BaseWidgetCard {
  final bool isDashboardLocked;
  const GroupWidgetCard({
    Key? key,
    required DashboardWidget widget,
    EntityState? entityState,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isEditing = false,
    bool isInteractive = true,
    this.isDashboardLocked = false,
  }) : super(
          key: key,
          widget: widget,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );

  @override
  Widget buildWidgetContent(BuildContext context, {bool isSmallWidget = false, bool useSimplifiedView = false}) {
    // Check if we have any group widgets defined
    final hasWidgets = widget.config.containsKey('groupWidgets') && 
                       widget.config['groupWidgets'] is List && 
                       (widget.config['groupWidgets'] as List).isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            IconHelper.getIconData(widget.icon),
            size: isSmallWidget ? 24 : 40,
          ),
          const SizedBox(height: 8),
          Text(
            widget.caption,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (!hasWidgets && !isSmallWidget)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No widgets in group',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prevent popup if protected and dashboard is locked
    final bool isProtected = widget.isProtected;
    final bool isLocked = isDashboardLocked;
    return Card(
      child: InkWell(
        onTap: (isEditing || (isProtected && isLocked)) ? null : () => _showGroupPopup(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: buildWidgetContent(context),
        ),
      ),
    );
  }

  void _showGroupPopup(BuildContext context) {
    final dashboardState = context.read<DashboardBloc>().state;
    HomeAssistantApiService? apiService;
    Map<String, EntityState> entityStates = {};
    if (dashboardState is DashboardLoaded) {
      apiService = context.read<DashboardBloc>().apiService;
      entityStates = dashboardState.entityStates;
    }
    
    // Debug: print the full content of the widget config
    debugPrint('GroupWidgetCard config: ${widget.config}');
    
    // Ensure apiService is available
    if (apiService == null) {
      debugPrint('GroupWidgetCard: API service is null, cannot display group widgets');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to Home Assistant')),
      );
      return;
    }
    
    // Use our helper to ensure groupWidgets is properly formed
    final List<Map<String, dynamic>> groupWidgets = 
        GroupWidgetHelper.sanitizeGroupWidgets(widget.config);
    
    debugPrint('GroupWidgetCard: groupWidgets.length = ${groupWidgets.length}');
    for (final gw in groupWidgets) {
      debugPrint('GroupWidgetCard: widget = ${gw['caption']} type=${gw['type']} pos=(${gw['positionX']},${gw['positionY']}) size=(${gw['widthPx']},${gw['heightPx']})');
    }
    
    // Calculate the optimal popup size based on widget positions and sizes
    double maxWidth = 0;
    double maxHeight = 0;
    
    for (final gw in groupWidgets) {
      final double posX = (gw['positionX'] as double?) ?? 0.0;
      final double posY = (gw['positionY'] as double?) ?? 0.0;
      final double width = (gw['widthPx'] as double?) ?? 100.0;
      final double height = (gw['heightPx'] as double?) ?? 100.0;
      
      final double rightEdge = posX + width + 20; // Add padding
      final double bottomEdge = posY + height + 20; // Add padding
      
      maxWidth = maxWidth > rightEdge ? maxWidth : rightEdge;
      maxHeight = maxHeight > bottomEdge ? maxHeight : bottomEdge;
    }
    
    // Add minimum sizes
    maxWidth = maxWidth < 350 ? 350 : maxWidth;
    maxHeight = maxHeight < 300 ? 300 : maxHeight;
    
    // Add maximum sizes based on screen
    final screenSize = MediaQuery.of(context).size;
    maxWidth = maxWidth > screenSize.width * 0.9 ? screenSize.width * 0.9 : maxWidth;
    maxHeight = maxHeight > screenSize.height * 0.8 ? screenSize.height * 0.8 : maxHeight;
    
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissal in normal view
      builder: (ctx) {
        // Use responsive size based on widget positions
        final isDesktop = MediaQuery.of(ctx).size.width > 600;
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(widget.caption, overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
                padding: const EdgeInsets.all(0),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
          backgroundColor: Theme.of(ctx).dialogBackgroundColor, // Consistent background color
          content: SizedBox(
            width: maxWidth,
            height: maxHeight,
            child: groupWidgets.isEmpty
                ? const Center(child: Text('No widgets in this group.'))
                : _GroupPopupGrid(
                    widgets: groupWidgets,
                    apiService: apiService!,
                    entityStates: entityStates,
                    isDesktop: isDesktop,
                    isEditMode: false, // Disable editing in normal view
                  ),
          ),
        );
      },
    );
  }
}

class _GroupPopupGrid extends StatefulWidget {
  final List<Map<String, dynamic>> widgets;
  final HomeAssistantApiService apiService;
  final Map<String, EntityState> entityStates;
  final bool isDesktop;
  final bool isEditMode;

  const _GroupPopupGrid({
    required this.widgets,
    required this.apiService,
    required this.entityStates,
    required this.isDesktop,
    this.isEditMode = false,
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

  // Helper method to safely convert values to double
  double _ensureDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  @override
  void initState() {
    super.initState();
    // Initialize positions from widget data - handle dynamic map properly
    _positions = widget.widgets.map<Map<String, dynamic>>((gw) {
      // Convert the values to double safely
      final posX = _ensureDouble(gw['positionX'], 0.0);
      final posY = _ensureDouble(gw['positionY'], 0.0);
      final width = _ensureDouble(gw['widthPx'], 100.0);
      final height = _ensureDouble(gw['heightPx'], 100.0);
      
      // Create a properly typed map
      return <String, dynamic>{
        'x': posX,
        'y': posY,
        'width': width,
        'height': height,
      };
    }).toList();
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
    
    // Persist new position to group config in popup (normal mode)
    for (int i = 0; i < widget.widgets.length; i++) {
      if (i < _positions.length) {
        widget.widgets[i]['positionX'] = _positions[i]['x'] as double;
        widget.widgets[i]['positionY'] = _positions[i]['y'] as double;
        widget.widgets[i]['widthPx'] = _positions[i]['width'] as double;
        widget.widgets[i]['heightPx'] = _positions[i]['height'] as double;
      }
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
    
    // Safety check before accessing widgets
    if (index < widget.widgets.length) {
      widget.widgets[index]['widthPx'] = _positions[index]['width'] as double;
      widget.widgets[index]['heightPx'] = _positions[index]['height'] as double;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.widgets.isEmpty) {
      debugPrint('_GroupPopupGrid: No widgets to display');
      return const Center(child: Text('No widgets in this group.'));
    }
    
    // Debug to check widget data integrity
    debugPrint('_GroupPopupGrid: Building grid with ${widget.widgets.length} widgets');
    for (final w in widget.widgets) {
      debugPrint('Widget: ${w['caption']} (${w['type']}) - ${w['id']}');
    }
    
    return Stack(
      children: [
        for (int i = 0; i < widget.widgets.length; i++)
          if (i < _positions.length) // Safety check to avoid index errors
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
                        child: WidgetCardFactory.createWidgetCard(
                          widget: DashboardWidget(
                            id: widget.widgets[i]['id']?.toString() ?? '',
                            type: widget.widgets[i]['type']?.toString() ?? '',
                            entityId: widget.widgets[i]['entityId']?.toString() ?? '',
                            caption: widget.widgets[i]['caption']?.toString() ?? '',
                            icon: widget.widgets[i]['icon']?.toString() ?? '',
                            config: Map<String, dynamic>.from(widget.widgets[i]['config'] ?? {}),
                            row: 0,
                            column: 0,
                            widthPx: _positions[i]['width'] as double,
                            heightPx: _positions[i]['height'] as double,
                            positionX: _positions[i]['x'] as double,
                            positionY: _positions[i]['y'] as double,
                          ),
                          apiService: widget.apiService,
                          entityState: _getEntityStateForWidget(i),
                          isEditing: false,
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
  
  // Helper method to get entity state for a specific widget
  EntityState? _getEntityStateForWidget(int index) {
    try {
      if (index < 0 || index >= widget.widgets.length) {
        debugPrint('_getEntityStateForWidget: Index $index out of bounds (${widget.widgets.length})');
        return null;
      }
      final String? entityId = widget.widgets[index]['entityId'];
      if (entityId == null || entityId.isEmpty) {
        debugPrint('_getEntityStateForWidget: Empty entityId for widget at index $index');
        return null;
      }
      // Check local cache first
      if (_fetchedEntityStates.containsKey(entityId)) {
        debugPrint('_getEntityStateForWidget: Using cached entity state for $entityId: ${_fetchedEntityStates[entityId]!.state}');
        return _fetchedEntityStates[entityId];
      }
      // Check if state exists in current cache
      EntityState? state = widget.entityStates[entityId];
      if (state != null) {
        debugPrint('_getEntityStateForWidget: Using original entity state for $entityId: ${state.state}');
        _fetchedEntityStates[entityId] = state;
        return state;
      }
      // Debug logging
      debugPrint('_getEntityStateForWidget: No entity state found for $entityId, trying to fetch');
      widget.apiService.getState(entityId).then((fetchedState) {
        if (mounted) {
          debugPrint('_getEntityStateForWidget: Fetched state for $entityId: ${fetchedState.state}');
          setState(() {
            _fetchedEntityStates[entityId] = fetchedState;
          });
        }
      }).catchError((error) {
        debugPrint('_getEntityStateForWidget: Error fetching state for $entityId: $error');
      });
      return null;
    } catch (e) {
      debugPrint('Error in _getEntityStateForWidget: $e');
      return null;
    }
  }
}
