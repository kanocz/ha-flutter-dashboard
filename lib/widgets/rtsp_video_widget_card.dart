import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';

class RtspVideoWidgetCard extends BaseWidgetCard {
  const RtspVideoWidgetCard({
    Key? key,
    required DashboardWidget widget,
    EntityState? entityState,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isEditing = false,
    bool isInteractive = true,
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
  Widget buildWidgetContent(
    BuildContext context, {
    bool isSmallWidget = false,
    bool useSimplifiedView = false,
  }) {
    final url = widget.config['url'] as String?;
    if (url == null || url.isEmpty) {
      return const Center(
        child: Text('No RTSP URL configured'),
      );
    }
    return _RtspVideoPlayer(url: url);
  }
}

class _RtspVideoPlayer extends StatefulWidget {
  final String url;
  const _RtspVideoPlayer({Key? key, required this.url}) : super(key: key);

  @override
  State<_RtspVideoPlayer> createState() => _RtspVideoPlayerState();
}

class _RtspVideoPlayerState extends State<_RtspVideoPlayer> {
  late final Player player;
  late final VideoController controller;
  bool _isPlayerInitialized = false;
  bool _isPlayerError = false;
  String _errorMessage = '';
  static _RtspVideoPlayerState? _lastInstance;

  final _lifecycleObserver = _RtspLifecycleObserver();
  Timer? _healthCheckTimer;
  ValueNotifier<bool>? _screensaverNotifier;
  VoidCallback? _screensaverListener;

  @override
  void initState() {
    _lastInstance = this;
    super.initState();
    _initializePlayer();
    // Add listeners for app lifecycle and periodic health check
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _startHealthCheckTimer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Create player with better buffering settings
      player = Player(
        configuration: PlayerConfiguration(
          bufferSize: 32 * 1024 * 1024, // 32MB buffer for better streaming
        ),
      );

      controller = VideoController(player);

      // Initialize player with RTSP URL
      await player.open(
        Media(widget.url),
        play: true,
      );

      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing RTSP video player: $e');
      if (mounted) {
        setState(() {
          _isPlayerError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted || _isPlayerError) return;
      // Check if player is still playing, if not, try to restart
      try {
        final state = player.state;
        if (!state.playing || state.completed) {
          await _restartPlayer();
        }
      } catch (e) {
        debugPrint('Health check error: $e');
        await _restartPlayer();
      }
    });
  }

  Future<void> _restartPlayer() async {
    try {
      await player.stop();
      await player.open(Media(widget.url), play: true);
      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
          _isPlayerError = false;
        });
      }
    } catch (e) {
      debugPrint('Error restarting RTSP player: $e');
      if (mounted) {
        setState(() {
          _isPlayerError = true;
          _errorMessage = 'Failed to reload video: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _healthCheckTimer?.cancel();
    // Fix: Check both notifier and listener are not null
    if (_screensaverNotifier != null && _screensaverListener != null) {
      _screensaverNotifier!.removeListener(_screensaverListener!);
    }
    try {
      player.dispose();
    } catch (e) {
      debugPrint('Error disposing player: $e');
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Remove old listener if it exists
    if (_screensaverNotifier != null && _screensaverListener != null) {
      _screensaverNotifier!.removeListener(_screensaverListener!);
    }
    
    // Get the screensaver notifier from context
    final screensaverNotifier = ScreensaverNotifier.of(context);
    debugPrint('RTSP Widget: ScreensaverNotifier found: \\${screensaverNotifier != null}');
    
    _screensaverNotifier = screensaverNotifier?.isScreensaverActive;
    
    if (_screensaverNotifier != null) {
      debugPrint('RTSP Widget: Setting up screensaver listener');
      _screensaverListener = () async {
        final isActive = _screensaverNotifier?.value ?? false;
        debugPrint('RTSP Widget: Screensaver state changed to: \\${isActive}');
        if (isActive) {
          if (_isPlayerInitialized && !_isPlayerError) {
            debugPrint('RTSP Widget: Stopping video due to screensaver');
            await player.stop();
          }
        } else {
          if (_isPlayerInitialized && !_isPlayerError) {
            debugPrint('RTSP Widget: Restarting video after screensaver');
            await _restartPlayer();
          }
        }
      };
      _screensaverNotifier!.addListener(_screensaverListener!);
      // Immediately apply the current state in case it changed while widget was not listening
      _screensaverListener!();
    } else {
      debugPrint('RTSP Widget: No screensaver notifier available');
    }
  }

  void _showFullscreenDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog.fullscreen(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player
              if (_isPlayerInitialized && !_isPlayerError)
                Video(
                  controller: controller,
                  fit: BoxFit.contain,
                  controls: null, // Hide time slider in fullscreen mode too
                ),

              if (!_isPlayerInitialized && !_isPlayerError)
                const Center(child: CircularProgressIndicator()),

              if (_isPlayerError)
                Center(child: Text(_errorMessage)),

              // Exit button
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.fullscreen_exit,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16.0 / 9.0, // Exact 16:9 aspect ratio
        child: Stack(
          children: [
            // Show loading indicator until player is initialized
            if (!_isPlayerInitialized && !_isPlayerError)
              const Center(child: CircularProgressIndicator()),

            // Show error message if player failed to initialize
            if (_isPlayerError)
              Center(child: Text(_errorMessage, textAlign: TextAlign.center)),

            // Video player - only show if initialized - hide controls with controls: null
            if (_isPlayerInitialized && !_isPlayerError)
              Video(
                controller: controller,
                fit: BoxFit.cover, // Force video to fill the container
                controls: null, // Hide time slider and all video controls
              ),

            // Custom fullscreen button overlay
            if (_isPlayerInitialized && !_isPlayerError)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _showFullscreenDialog(context);
                    },
                    iconSize: 24,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minHeight: 32,
                      minWidth: 32,
                    ),
                  ),
                ),
              ),

            // Retry button
            if (_isPlayerError)
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isPlayerError = false;
                      _isPlayerInitialized = false;
                    });
                    _initializePlayer();
                  },
                  child: const Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RtspLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // On wakeup, try to restart the player
      _RtspVideoPlayerState? stateObj = _RtspVideoPlayerState._lastInstance;
      stateObj?._restartPlayer();
    }
  }
}

class ScreensaverNotifier extends InheritedWidget {
  final ValueNotifier<bool> isScreensaverActive;
  const ScreensaverNotifier({
    Key? key,
    required this.isScreensaverActive,
    required Widget child,
  }) : super(key: key, child: child);

  static ScreensaverNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScreensaverNotifier>();
  }

  @override
  bool updateShouldNotify(ScreensaverNotifier oldWidget) =>
      isScreensaverActive != oldWidget.isScreensaverActive;
}
