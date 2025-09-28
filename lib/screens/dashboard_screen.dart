import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // No longer needed
import 'package:ha_flutter_dashboard/blocs/dashboard_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/home_assistant_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/launcher_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/theme_bloc.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/models/home_assistant_instance.dart';
import 'package:ha_flutter_dashboard/screens/settings_screen.dart';
import 'package:ha_flutter_dashboard/screens/widget_editor_screen.dart';
import 'package:ha_flutter_dashboard/screens/screensaver_screen.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';
import 'package:ha_flutter_dashboard/widgets/widget_card_factory.dart';
import 'package:ha_flutter_dashboard/widgets/numpad_pin_dialog.dart';
import 'package:ha_flutter_dashboard/widgets/rtsp_video_widget_card.dart';
import 'package:uuid/uuid.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isEditing = false;
  String? _selectedWidgetId;
  late HomeAssistantApiService? _apiService;
  late StorageService _storageService;
  final _passwordController = TextEditingController();
  // PIN entry controllers
  final _pinControllers = List.generate(4, (_) => TextEditingController());
  final _pinFocusNodes = List.generate(4, (_) => FocusNode());
  bool _isInitialized = false;
  Timer? _autoLockTimer;
  DateTime _lastInteractionTime = DateTime.now();
  Timer? _screensaverTimer;
  DateTime _lastScreensaverInteractionTime = DateTime.now();
  bool _isScreensaverActive = false;
  
  // State for dragging and resizing
  Offset? _draggingOffset;

  bool _snapToGrid = false;
  bool _snapTo10px = false;

  late final ValueNotifier<bool> _screensaverNotifier;

  @override
  void initState() {
    super.initState();
    _screensaverNotifier = ValueNotifier<bool>(false);
    // Do not call _applyOrientationLock here, _storageService is not initialized yet.
    // _applyOrientationLock will be called after _storageService is initialized in _initialize().
    _isEditing = false;
    _selectedWidgetId = null;
    _apiService = null;
    _autoLockTimer = null;
    _lastInteractionTime = DateTime.now();
    _draggingOffset = null;
    _snapToGrid = false;
    _snapTo10px = false;
    _isScreensaverActive = false;
    _isInitialized = false;
    // Initialize everything
    _initialize();
  }

  void _applyFullscreenMode() {
    if (_storageService.isFullscreenModeEnabled()) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _initialize() async {
    // Initialize storage service first
    _storageService = StorageService();
    await _storageService.init();

    // Set up the API service
    _setupApiService();

    // If in launcher mode, prevent app closing
    _checkLauncherMode();

    // Load the dashboard widgets
    context.read<DashboardBloc>().add(LoadDashboardWidgets());

    // Start auto-lock timer if enabled
    _setupAutoLockTimer();

    // Start screensaver timer if enabled
    _setupScreensaverTimer();

    // Apply orientation lock after storage is ready
    _applyOrientationLock();
    // Apply fullscreen mode after storage is ready
    _applyFullscreenMode();

    // Mark as initialized
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _applyOrientationLock() {
    final orientation = _storageService.getOrientationLock();
    if (orientation == "portrait") {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else if (orientation == "landscape") {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _setupAutoLockTimer() {
    if (_storageService.isAutoLockEnabled()) {
      _autoLockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _checkForAutoLock();
      });
    }
  }

  void _resetAutoLockTimer() {
    _lastInteractionTime = DateTime.now();
  }

  void _checkForAutoLock() {
    if (!_storageService.isAutoLockEnabled()) return;
    if (_storageService.isDashboardLocked()) return;

    final now = DateTime.now();
    final diff = now.difference(_lastInteractionTime).inMilliseconds;

    if (diff >= AppConstants.autoLockTimeoutMs) {
      _lockDashboard();
    }
  }

  void _lockDashboard() {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    if (mounted) {
      setState(() {
        if (_isEditing) {
          _isEditing = false;
          _selectedWidgetId = null;
        }
      });
    }
    _storageService.setDashboardLocked(true);
  }

  void _setupScreensaverTimer() {
    if (_storageService.isScreensaverEnabled()) {
      _screensaverTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _checkForScreensaver();
      });
    }
  }

  void _resetScreensaverTimer() {
    _lastScreensaverInteractionTime = DateTime.now();
    // Clear screensaver flag on user interaction as a safeguard
    _isScreensaverActive = false;
  }

  void _checkForScreensaver() {
    if (!_storageService.isScreensaverEnabled()) return;
    if (_isScreensaverActive) return; // Don't start screensaver if already active

    final now = DateTime.now();
    final diff = now.difference(_lastScreensaverInteractionTime).inMilliseconds;
    final timeoutMs = _storageService.getScreensaverTimeout();

    if (diff >= timeoutMs) {
      _showScreensaver();
    }
  }

  void _showScreensaver() {
    if (_isScreensaverActive) return; // Prevent multiple screensavers
    debugPrint('Dashboard: Showing screensaver, setting notifier to true');
    setState(() {
      _isScreensaverActive = true;
      _screensaverNotifier.value = true;
    });
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const ScreensaverScreen();
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ).then((_) {
      // Reset screensaver timer when returning from screensaver
      _resetScreensaverTimer();
      debugPrint('Dashboard: Hiding screensaver, setting notifier to false');
      setState(() {
        _isScreensaverActive = false;
        _screensaverNotifier.value = false;
      });
      // Restore fullscreen mode if enabled
      if (_storageService.isFullscreenModeEnabled()) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
    });
  }

  Future<void> _unlockDashboard() async {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    if (!_storageService.isPasswordProtectionEnabled() ||
        !_storageService.isPasswordSet()) {
      // No password protection, unlock directly
      await _storageService.setDashboardLocked(false);
      _resetAutoLockTimer();
      setState(() {});
      return;
    }

    _showUnlockDialog();
  }

  void _showUnlockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NumpadPinDialog(
        title: 'Unlock Dashboard',
        subtitle: 'Enter your 4-digit PIN',
        onPinEntered: (pin) {
          Navigator.of(context).pop();
          _verifyUnlockPin(pin);
        },
      ),
    );
  }

  void _verifyUnlockPin(String pin) {
    if (_storageService.verifyPin(pin)) {
      _storageService.setDashboardLocked(false);
      _resetAutoLockTimer();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard unlocked')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var focusNode in _pinFocusNodes) {
      focusNode.dispose();
    }
    _autoLockTimer?.cancel();
    _screensaverTimer?.cancel();
    _screensaverNotifier.dispose();
    super.dispose();
  }

  void _setupApiService() {
    final haState = context.read<HomeAssistantBloc>().state;

    if (haState is HomeAssistantLoaded &&
        haState.selectedInstance != null &&
        haState.token != null) {
      _apiService = HomeAssistantApiService(
        instance: haState.selectedInstance!,
        token: haState.token!,
        storageService: _storageService,
      );

      // Provide the API service to the dashboard bloc
      context.read<DashboardBloc>().add(SetApiService(_apiService!));
    } else {
      _apiService = null;
    }
  }

  void _checkLauncherMode() {
    final launcherState = context.read<LauncherBloc>().state;

    if (launcherState.isLauncher) {
      // Prevent the app from being exited on Android
      SystemChannels.platform.invokeMethod('SystemNavigator.preventPop');

      // Hide system UI for a more immersive launcher experience
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top],
      );
    }
  }

  void _toggleTheme() {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    final themeState = context.read<ThemeBloc>().state;
    ThemeMode newMode;

    if (themeState.themeMode == ThemeMode.light) {
      newMode = ThemeMode.dark;
    } else if (themeState.themeMode == ThemeMode.dark) {
      newMode = ThemeMode.system;
    } else {
      newMode = ThemeMode.light;
    }

    context.read<ThemeBloc>().add(ToggleThemeMode(newMode));
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NumpadPinDialog(
        title: 'Enter PIN',
        subtitle: 'Enter your 4-digit PIN to enable edit mode',
        onPinEntered: (pin) {
          Navigator.of(context).pop();
          _verifyPin(pin);
        },
      ),
    );
  }
  
  // Removed unused method

  void _verifyPin(String pin) {
    if (_storageService.verifyPin(pin)) {
      _toggleEditMode();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  void _tryEnterEditMode() {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App is still initializing. Please try again in a moment.')),
      );
      return;
    }

    if (_storageService.isPasswordProtectionEnabled() &&
        _storageService.isPasswordSet()) {
      _showPasswordDialog();
    } else {
      _toggleEditMode();
    }
  }

  void _toggleEditMode() {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    setState(() {
      _isEditing = !_isEditing;
      _selectedWidgetId = null;
      _draggingOffset = null; // Reset dragging offset to avoid position jumps
    });
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoFixWidgetPositions());
    }
  }

  void _autoFixWidgetPositions() {
    // Skip repositioning if the keyboard is open
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return;
    }
    final dashboardState = context.read<DashboardBloc>().state;
    if (dashboardState is! DashboardLoaded) return;
    final widgets = dashboardState.widgets;
    final maxGridWidth = getMaxGridWidth(context);
    final maxGridHeight = getMaxGridHeight(context);

    // Use physical screen size, not logical window size (to ignore keyboard)
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final double screenWidth = window.physicalSize.width / window.devicePixelRatio;
    final double screenHeight = window.physicalSize.height / window.devicePixelRatio;

    List<Rect> occupied = [];
    // First, mark all in-bounds widgets as occupied
    for (final widget in widgets) {
      double left = widget.positionX;
      double top = widget.positionY;
      bool inBounds = left >= 0 && top >= 0 &&
        left <= screenWidth - widget.widthPx &&
        top <= screenHeight - widget.heightPx;
      if (inBounds) {
        occupied.add(Rect.fromLTWH(left, top, widget.widthPx, widget.heightPx));
      }
    }
    // Now, only move out-of-bounds widgets
    for (final widget in widgets) {
      double left = widget.positionX;
      double top = widget.positionY;
      bool outOfBounds = left < 0 || top < 0 ||
        left > screenWidth - widget.widthPx ||
        top > screenHeight - widget.heightPx;
      if (outOfBounds) {
        // Find a free spot
        double newLeft = 0, newTop = 0;
        bool found = false;
        for (int row = 0; row < maxGridHeight && !found; row++) {
          for (int col = 0; col < maxGridWidth && !found; col++) {
            newLeft = col * (screenWidth / maxGridWidth);
            newTop = row * (screenWidth / maxGridWidth); // keep cells square
            Rect candidate = Rect.fromLTWH(newLeft, newTop, widget.widthPx, widget.heightPx);
            bool overlaps = occupied.any((r) => r.overlaps(candidate));
            if (!overlaps &&
                newLeft >= 0 && newTop >= 0 &&
                newLeft <= screenWidth - widget.widthPx &&
                newTop <= screenHeight - widget.heightPx) {
              found = true;
              occupied.add(candidate);
              context.read<DashboardBloc>().add(UpdateWidgetPosition(widget.id, newLeft, newTop));
            }
          }
        }
        if (!found) {
          // fallback: move to 0,0
          context.read<DashboardBloc>().add(UpdateWidgetPosition(widget.id, 0, 0));
        }
      }
    }
  }

  void _addNewWidget() {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    // Get current widget count to determine the new widget's row position
    final dashboardState = context.read<DashboardBloc>().state;
    int rowPosition = 0;

    if (dashboardState is DashboardLoaded) {
      rowPosition = dashboardState.widgets.length;
    }

    // Create a default widget
    final newWidget = DashboardWidget(
      id: const Uuid().v4(),
      type: AppConstants.widgetTypeTime,
      entityId: '',
      caption: 'New Widget',
      icon: 'mdi:clock',
      config: {},
      row: rowPosition,
      column: 0,
      width: 1,
      height: 1,
    );

    // Navigate to the editor screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WidgetEditorScreen(
          widget: newWidget,
          isNew: true,
        ),
      ),
    ).then((result) {
      if (result is DashboardWidget) {
        // Add the new widget
        context.read<DashboardBloc>().add(AddDashboardWidget(result));
      }
    });
  }

  void _editWidget(DashboardWidget widget) {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WidgetEditorScreen(
          widget: widget,
          isNew: false,
        ),
      ),
    ).then((result) {
      if (result is DashboardWidget) {
        // Update the widget
        context.read<DashboardBloc>().add(UpdateDashboardWidget(result));
      }
    });
  }

  void _deleteWidget(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Widget'),
        content: const Text('Are you sure you want to delete this widget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<DashboardBloc>().add(DeleteDashboardWidget(id));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Movement now handled by dragging

  Widget _buildDashboardGrid(List<DashboardWidget> widgets, Map<String, EntityState> entityStates) {
    return Expanded(
      child: widgets.isEmpty
          ? _buildEmptyState()
          : _isEditing
              ? _buildEditableGrid(widgets, entityStates)
              : _buildNormalGrid(widgets, entityStates),
    );
  }

  // Only free positioning mode is supported now
  Widget _buildNormalGrid(List<DashboardWidget> widgets, Map<String, EntityState> entityStates) {
    final maxGridWidth = getMaxGridWidth(context);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // Get physical screen size if keyboard is open
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final double physicalScreenWidth = window.physicalSize.width / window.devicePixelRatio;
    final double physicalScreenHeight = window.physicalSize.height / window.devicePixelRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double layoutWidth = isKeyboardOpen ? physicalScreenWidth : constraints.maxWidth;
        final double layoutHeight = isKeyboardOpen ? physicalScreenHeight : constraints.maxHeight;
        return Stack(
          children: [
            Container(
              height: layoutHeight,
              width: layoutWidth,
              color: Colors.transparent,
            ),
            ...widgets.map((widget) {
              final entityState = entityStates[widget.entityId];
              final isProtectedAndLocked = _storageService.isDashboardLocked() && widget.isProtected;
              final cellWidth = layoutWidth / maxGridWidth;
              final cellHeight = cellWidth;
              final widgetWidth = widget.widthPx;
              final widgetHeight = widget.heightPx;
              double left = widget.positionX;
              double top = widget.positionY;
              if ((left == 0 && top == 0 && (widget.row > 0 || widget.column > 0)) ||
                  left < 0 || top < 0 || left > layoutWidth - widgetWidth || top > layoutHeight - widgetHeight) {
                left = widget.column > 0 ? widget.column * cellWidth : 0;
                top = widget.row > 0 ? widget.row * cellHeight : 0;
                left = left.clamp(0.0, layoutWidth - widgetWidth);
                top = top.clamp(0.0, layoutHeight - widgetHeight);
                if (widget.id.isNotEmpty) {
                  Future.microtask(() {
                    context.read<DashboardBloc>().add(UpdateWidgetPosition(
                      widget.id,
                      left,
                      top,
                    ));
                  });
                }
              }
              return Positioned(
                left: left,
                top: top,
                child: SizedBox(
                  width: widgetWidth,
                  height: widgetHeight,
                  child: Stack(
                    children: [
                      WidgetCardFactory.createWidgetCard(
                        widget: widget,
                        apiService: _apiService!,
                        entityState: entityState,
                        isEditing: false,
                        isInteractive: !isProtectedAndLocked,
                        isDashboardLocked: _storageService.isDashboardLocked(),
                        onTap: isProtectedAndLocked 
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Widget is protected. Unlock dashboard to control it.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } 
                          : null,
                        onLongPress: () {},
                      ),
                      if (_storageService.isDashboardLocked() && widget.isProtected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildEditableGrid(List<DashboardWidget> widgets, Map<String, EntityState> entityStates) {
    final maxGridWidth = getMaxGridWidth(context);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final double physicalScreenWidth = window.physicalSize.width / window.devicePixelRatio;
    final double physicalScreenHeight = window.physicalSize.height / window.devicePixelRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double layoutWidth = isKeyboardOpen ? physicalScreenWidth : constraints.maxWidth;
        final double layoutHeight = isKeyboardOpen ? physicalScreenHeight : constraints.maxHeight;
        return Stack(
          children: [
            Container(
              height: layoutHeight,
              width: layoutWidth,
              color: Colors.transparent,
              child: CustomPaint(
                painter: _snapTo10px 
                  ? PixelGridPainter(
                      gridSize: 10.0,
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                    )
                  : GridPainter(
                      columns: maxGridWidth,
                      rows: getMaxGridHeight(context),
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                    ),
              ),
            ),
            ...widgets.map((widget) {
              final entityState = entityStates[widget.entityId];
              final isSelected = _selectedWidgetId == widget.id;
              final cellWidth = layoutWidth / maxGridWidth;
              final cellHeight = cellWidth;
              final widgetWidth = widget.widthPx;
              final widgetHeight = widget.heightPx;
              double left = widget.positionX;
              double top = widget.positionY;
              if ((left < 0 || top < 0 || left > layoutWidth - widgetWidth || top > layoutHeight - widgetHeight)) {
                left = widget.column > 0 ? widget.column * cellWidth : 0;
                top = widget.row > 0 ? widget.row * cellHeight : 0;
                left = left.clamp(0.0, layoutWidth - widgetWidth);
                top = top.clamp(0.0, layoutHeight - widgetHeight);
                if (widget.id.isNotEmpty) {
                  Future.microtask(() {
                    context.read<DashboardBloc>().add(UpdateWidgetPosition(
                      widget.id,
                      left,
                      top,
                    ));
                  });
                }
              }
              return Positioned(
                left: widget.id == _selectedWidgetId && _draggingOffset != null ? _draggingOffset!.dx : left,
                top: widget.id == _selectedWidgetId && _draggingOffset != null ? _draggingOffset!.dy : top,
                child: Stack(
                  children: [
                    SizedBox(
                      width: widgetWidth,
                      height: widgetHeight,
                      child: WidgetCardFactory.createWidgetCard(
                        widget: widget,
                        apiService: _apiService!,
                        entityState: entityState,
                        isEditing: true,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          _selectedWidgetId = widget.id;
                        });
                      },
                      onPanStart: isSelected ? (details) {
                        setState(() {
                          _draggingOffset = Offset(left, top);
                        });
                      } : null,
                      onPanUpdate: isSelected ? (details) {
                        if (_draggingOffset != null) {
                          final newX = _draggingOffset!.dx + details.delta.dx;
                          final newY = _draggingOffset!.dy + details.delta.dy;
                          final maxX = layoutWidth - widgetWidth;
                          final maxY = layoutHeight - widgetHeight;
                          setState(() {
                            _draggingOffset = Offset(
                              newX.clamp(0.0, maxX),
                              newY.clamp(0.0, maxY),
                            );
                          });
                        }
                      } : null,
                      onPanEnd: isSelected ? (details) {
                        if (_draggingOffset != null) {
                          double finalX = _draggingOffset!.dx;
                          double finalY = _draggingOffset!.dy;
                          
                          // Apply snap to grid if enabled
                          if (_snapToGrid) {
                            final gridSize = cellWidth; // Use cellWidth as grid size
                            finalX = (finalX / gridSize).round() * gridSize;
                            finalY = (finalY / gridSize).round() * gridSize;
                          } else if (_snapTo10px) {
                            // Snap to 10px grid
                            finalX = (finalX / 10.0).round() * 10.0;
                            finalY = (finalY / 10.0).round() * 10.0;
                          }
                          
                          context.read<DashboardBloc>().add(UpdateWidgetPosition(
                            widget.id,
                            finalX,
                            finalY,
                          ));
                          setState(() {
                            _draggingOffset = null;
                          });
                        }
                      } : null,
                      child: Container(
                        width: widgetWidth,
                        height: widgetHeight,
                        color: Colors.transparent,
                      ),
                    ),
                    if (isSelected) ...[
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -16,
                        left: -16,
                        child: _buildResizeHandle(context, widget, widgetWidth, widgetHeight, cellWidth, cellHeight, 'topLeft'),
                      ),
                      Positioned(
                        top: -16,
                        right: -16,
                        child: _buildResizeHandle(context, widget, widgetWidth, widgetHeight, cellWidth, cellHeight, 'topRight'),
                      ),
                      Positioned(
                        bottom: -16,
                        left: -16,
                        child: _buildResizeHandle(context, widget, widgetWidth, widgetHeight, cellWidth, cellHeight, 'bottomLeft'),
                      ),
                      Positioned(
                        bottom: -16,
                        right: -16,
                        child: _buildResizeHandle(context, widget, widgetWidth, widgetHeight, cellWidth, cellHeight, 'bottomRight'),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 2,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                              margin: const EdgeInsets.only(right: 4),
                              child: IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () => _editWidget(widget),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 2,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                color: Colors.red,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () => _deleteWidget(widget.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildResizeHandle(BuildContext context, DashboardWidget widget, double widgetWidth, double widgetHeight, double cellWidth, double cellHeight, String corner) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details) {
        double newWidth = widget.widthPx;
        double newHeight = widget.heightPx;
        double newLeft = widget.positionX;
        double newTop = widget.positionY;
        final dx = details.delta.dx;
        final dy = details.delta.dy;
        switch (corner) {
          case 'topLeft':
            newWidth = (widget.widthPx - dx).clamp(50, 800);
            newHeight = (widget.heightPx - dy).clamp(50, 800);
            newLeft = widget.positionX + dx;
            newTop = widget.positionY + dy;
            break;
          case 'topRight':
            newWidth = (widget.widthPx + dx).clamp(50, 800);
            newHeight = (widget.heightPx - dy).clamp(50, 800);
            newTop = widget.positionY + dy;
            break;
          case 'bottomLeft':
            newWidth = (widget.widthPx - dx).clamp(50, 800);
            newHeight = (widget.heightPx + dy).clamp(50, 800);
            newLeft = widget.positionX + dx;
            break;
          case 'bottomRight':
            newWidth = (widget.widthPx + dx).clamp(50, 800);
            newHeight = (widget.heightPx + dy).clamp(50, 800);
            break;
        }
        // Snap to grid if enabled and this widget is selected
        if ((_snapToGrid || _snapTo10px) && _selectedWidgetId == widget.id) {
          if (_snapToGrid) {
            final gridSize = cellWidth; // Use cellWidth as grid size
            newWidth = (newWidth / gridSize).round() * gridSize;
            newHeight = (newHeight / gridSize).round() * gridSize;
            newLeft = (newLeft / gridSize).round() * gridSize;
            newTop = (newTop / gridSize).round() * gridSize;
          } else if (_snapTo10px) {
            // Snap to 10px grid
            newWidth = (newWidth / 10.0).round() * 10.0;
            newHeight = (newHeight / 10.0).round() * 10.0;
            newLeft = (newLeft / 10.0).round() * 10.0;
            newTop = (newTop / 10.0).round() * 10.0;
          }
        }
        context.read<DashboardBloc>().add(UpdateWidgetSizeAndPosition(
          widget.id,
          newWidth.round(),
          newHeight.round(),
          newLeft,
          newTop,
        ));
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: const Icon(Icons.drag_handle, size: 18, color: Colors.blue),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.dashboard_customize,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No widgets added yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to add your first widget',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewWidget,
            icon: const Icon(Icons.add),
            label: const Text('Add Widget'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialogForSettings() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NumpadPinDialog(
        title: 'Enter PIN',
        subtitle: 'Enter your 4-digit PIN to access settings',
        onPinEntered: (pin) {
          Navigator.of(context).pop();
          _verifyPinForSettings(pin);
        },
      ),
    );
  }

  void _verifyPinForSettings(String pin) {
    if (_storageService.verifyPin(pin)) {
      // PIN correct - navigate to settings
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }
  
  void _navigateToSettings() {
    _resetScreensaverTimer(); // Reset screensaver timer on user interaction
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App is still initializing. Please try again in a moment.')),
      );
      return;
    }
    
    if (_storageService.isPasswordProtectionEnabled() &&
        _storageService.isPasswordSet()) {
      _showPasswordDialogForSettings();
    } else {
      // No password protection - navigate directly
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        ),
      );
    }
  }



  // Determine the grid dimensions based on orientation and user settings
  int getMaxGridWidth(BuildContext context) {
    final themeState = context.read<ThemeBloc>().state;
    return MediaQuery.of(context).orientation == Orientation.portrait 
        ? themeState.gridPortraitColumns 
        : themeState.gridLandscapeColumns;
  }
  
  int getMaxGridHeight(BuildContext context) {
    final themeState = context.read<ThemeBloc>().state;
    return MediaQuery.of(context).orientation == Orientation.portrait 
        ? themeState.gridPortraitRows 
        : themeState.gridLandscapeRows;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }
    
    if (_apiService == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(
          child: Text('Please complete Home Assistant setup.'),
        ),
      );
    }
    // Provide screensaver state to all widgets
    return ScreensaverNotifier(
      isScreensaverActive: _screensaverNotifier,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (_storageService.isFullscreenModeEnabled()) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
          }
          _resetScreensaverTimer();
        },
        child: WillPopScope(
          onWillPop: () async => false, // Block back navigation
          child: _buildDashboardContent(context),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    return BlocBuilder<HomeAssistantBloc, HomeAssistantState>(
      builder: (context, haState) {
        if (haState is HomeAssistantLoaded) {
          final HomeAssistantInstance? instance = haState.selectedInstance;

          return BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, dashboardState) {
              // Reset auto-lock timer on any rebuild
              _resetAutoLockTimer();
              // Note: Do NOT reset screensaver timer here - it should only reset on user interaction
              final isDashboardLocked = _storageService.isDashboardLocked();
              
              return Scaffold(
                appBar: AppBar(
                  title: Row(
                    children: [
                      !_isEditing 
                        ? Expanded(
                            child: Row(
                              children: [
                                Expanded(child: Text(instance?.name ?? 'Home Assistant Dashboard')),
                                // Display current time in normal mode
                                StreamBuilder(
                                  stream: Stream.periodic(const Duration(seconds: 1)),
                                  builder: (context, snapshot) {
                                    final now = DateTime.now();
                                    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                                    return Text(timeStr, style: Theme.of(context).textTheme.bodyLarge);
                                  },
                                ),
                              ],
                            ),
                          )
                        : Expanded(
                            child: Row(
                              children: [
                                const Text('Edit Mode'),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: _snapToGrid,
                                  onChanged: (val) {
                                    setState(() {
                                      _snapToGrid = val ?? false;
                                      if (_snapToGrid) _snapTo10px = false; // Disable 10px snap
                                    });
                                  },
                                ),
                                const Text('Snap'),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: _snapTo10px,
                                  onChanged: (val) {
                                    setState(() {
                                      _snapTo10px = val ?? false;
                                      if (_snapTo10px) _snapToGrid = false; // Disable grid snap
                                    });
                                  },
                                ),
                                const Text('10px'),
                                const Spacer(),
                                // Add Widget button in app bar
                                TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Widget'),
                                  onPressed: _addNewWidget,
                                ),
                                const SizedBox(width: 8),
                                // Done button in app bar
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.done),
                                  label: const Text('Done'),
                                  onPressed: _toggleEditMode,
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                  actions: [
                    if (!_isEditing) ...[
                      IconButton(
                        icon: Icon(isDashboardLocked ? Icons.lock : Icons.lock_open),
                        onPressed: isDashboardLocked ? _unlockDashboard : _lockDashboard,
                        tooltip: isDashboardLocked ? 'Unlock Dashboard' : 'Lock Dashboard',
                      ),
                      IconButton(
                        icon: const Icon(Icons.wb_sunny),
                        onPressed: _toggleTheme,
                        tooltip: 'Toggle theme',
                      ),
                      if (!isDashboardLocked)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _tryEnterEditMode,
                          tooltip: 'Edit Mode',
                        ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: _navigateToSettings,
                        tooltip: 'Settings',
                      ),
                    ],
                  ],
                ),
                body: Column(
                  children: [
                    if (dashboardState is DashboardLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (dashboardState is DashboardLoaded)
                      _buildDashboardGrid(dashboardState.widgets, dashboardState.entityStates)
                    else if (dashboardState is DashboardError)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(dashboardState.message),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<DashboardBloc>().add(LoadDashboardWidgets());
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Expanded(
                        child: Center(
                          child: Text('Unknown state'),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        }

        // Not authenticated or no instance selected
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Not connected to Home Assistant'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/setup');
                  },
                  child: const Text('Setup'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for drawing grid lines
class GridPainter extends CustomPainter {
  final int columns;
  final int rows;
  final Color color;

  GridPainter({
    required this.columns,
    required this.rows,
    this.color = Colors.grey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;

    // Draw vertical lines
    for (int i = 1; i < columns; i++) {
      final x = cellWidth * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (int i = 1; i < rows; i++) {
      final y = cellHeight * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Custom painter for drawing pixel grid lines (e.g., 10px grid)
class PixelGridPainter extends CustomPainter {
  final double gridSize;
  final Color color;

  PixelGridPainter({
    required this.gridSize,
    this.color = Colors.grey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Draw vertical lines
    for (double x = gridSize; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = gridSize; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
