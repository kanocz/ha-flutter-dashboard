import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';
import 'package:ha_flutter_dashboard/utils/debug_logger.dart';

// Events
abstract class DashboardEvent {}

class LoadDashboardWidgets extends DashboardEvent {}
class AddDashboardWidget extends DashboardEvent {
  final DashboardWidget widget;
  AddDashboardWidget(this.widget);
}
class UpdateDashboardWidget extends DashboardEvent {
  final DashboardWidget widget;
  UpdateDashboardWidget(this.widget);
}
class DeleteDashboardWidget extends DashboardEvent {
  final String id;
  DeleteDashboardWidget(this.id);
}
class ReorderDashboardWidget extends DashboardEvent {
  final String widgetId;
  final int newPosition;
  ReorderDashboardWidget(this.widgetId, this.newPosition);
}
class UpdateEntityState extends DashboardEvent {
  final EntityState entityState;
  UpdateEntityState(this.entityState);
}
class SetApiService extends DashboardEvent {
  final HomeAssistantApiService apiService;
  SetApiService(this.apiService);
}

class UpdateWidgetPosition extends DashboardEvent {
  final String widgetId;
  final double positionX;
  final double positionY;
  
  UpdateWidgetPosition(this.widgetId, this.positionX, this.positionY);
}

class UpdateWidgetSizeAndPosition extends DashboardEvent {
  final String widgetId;
  final int width;
  final int height;
  final double positionX;
  final double positionY;
  
  UpdateWidgetSizeAndPosition(this.widgetId, this.width, this.height, this.positionX, this.positionY);
}

// States
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}
class DashboardLoaded extends DashboardState {
  final List<DashboardWidget> widgets;
  final Map<String, EntityState> entityStates;
  
  DashboardLoaded({
    required this.widgets,
    required this.entityStates,
  });
  
  DashboardLoaded copyWith({
    List<DashboardWidget>? widgets,
    Map<String, EntityState>? entityStates,
  }) {
    return DashboardLoaded(
      widgets: widgets ?? this.widgets,
      entityStates: entityStates ?? this.entityStates,
    );
  }
}
class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

// BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final StorageService _storageService;
  HomeAssistantApiService? _apiService;
  StreamSubscription? _stateUpdateSubscription;

  HomeAssistantApiService? get apiService => _apiService;
  
  DashboardBloc({
    required StorageService storageService,
    HomeAssistantApiService? apiService,
  }) : _storageService = storageService,
       _apiService = apiService,
       super(DashboardInitial()) {
    on<LoadDashboardWidgets>(_onLoadDashboardWidgets);
    on<AddDashboardWidget>(_onAddDashboardWidget);
    on<UpdateDashboardWidget>(_onUpdateDashboardWidget);
    on<DeleteDashboardWidget>(_onDeleteDashboardWidget);
    on<UpdateEntityState>(_onUpdateEntityState);
    on<SetApiService>(_onSetApiService);
    on<ReorderDashboardWidget>(_onReorderDashboardWidget);
    on<UpdateWidgetPosition>(_onUpdateWidgetPosition);
    on<UpdateWidgetSizeAndPosition>(_onUpdateWidgetSizeAndPosition);
    
    // Initialize real-time updates if API service is available
    if (_apiService != null) {
      _initRealTimeUpdates();
    }
  }
  
  void _initRealTimeUpdates() {
    debugPrint('DashboardBloc: Initializing real-time updates');
    DebugLogger.log('DashboardBloc: Initializing real-time updates');
    _apiService?.initializeRealTimeUpdates();
    _stateUpdateSubscription = _apiService?.stateUpdateStream?.listen((entityState) {
      debugPrint('DashboardBloc: Received state update for \\${entityState.entityId}: \\${entityState.state}');
      DebugLogger.log('DashboardBloc: Received state update for \\${entityState.entityId}: \\${entityState.state}');
      add(UpdateEntityState(entityState));
    });
    // Listen for reconnects and reload all entity states
    _apiService?.reconnectStream?.listen((_) {
      debugPrint('DashboardBloc: Detected reconnect, reloading all entity states');
      DebugLogger.log('DashboardBloc: Detected reconnect, reloading all entity states');
      add(LoadDashboardWidgets());
    });
  }
  
  @override
  Future<void> close() {
    _stateUpdateSubscription?.cancel();
    _apiService?.disposeRealTimeUpdates();
    return super.close();
  }
  
  void _onSetApiService(SetApiService event, Emitter<DashboardState> emit) {
    _apiService = event.apiService;
    _initRealTimeUpdates();
    
    // Reload widgets if already loaded
    if (state is DashboardLoaded) {
      add(LoadDashboardWidgets());
    }
  }
  
  Future<void> _onLoadDashboardWidgets(LoadDashboardWidgets event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    debugPrint('DashboardBloc: LoadDashboardWidgets called');
    try {
      // Load widgets from storage
      final widgets = _storageService.getDashboardWidgets();
      debugPrint('DashboardBloc: Loaded \\${widgets.length} widgets from storage');
      // Get the entity states for all entities used in widgets
      final List<String> entityIds = widgets
          .where((widget) => widget.entityId.isNotEmpty)
          .map((widget) => widget.entityId)
          .toList();
      debugPrint('DashboardBloc: Will fetch states for entityIds: \\${entityIds.join(", ")}');
      final Map<String, EntityState> entityStates = {};
      if (entityIds.isNotEmpty) {
        try {
          // Get all states at once
          final allStates = await _apiService?.getStates() ?? [];
          debugPrint('DashboardBloc: getStates() returned \\${allStates.length} states');
          // Filter for only the entity IDs we need
          for (final state in allStates) {
            if (entityIds.contains(state.entityId)) {
              entityStates[state.entityId] = state;
            }
          }
        } catch (e) {
          debugPrint('DashboardBloc: Error in getStates: \\${e.toString()}');
        }
      }
      debugPrint('DashboardBloc: entityStates map now has \\${entityStates.length} entries');
      emit(DashboardLoaded(
        widgets: widgets,
        entityStates: entityStates,
      ));
      // Force widget rebuilds by emitting UpdateEntityState for each entity
      for (final state in entityStates.values) {
        add(UpdateEntityState(state));
      }
    } catch (e) {
      debugPrint('DashboardBloc: Exception in LoadDashboardWidgets: \\${e.toString()}');
      emit(DashboardError('Failed to load dashboard: $e'));
    }
  }
  
  Future<void> _onAddDashboardWidget(AddDashboardWidget event, Emitter<DashboardState> emit) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      // Save the widget to storage
      await _storageService.saveDashboardWidget(event.widget);
      
      // Get the entity state if it has an entity ID
      Map<String, EntityState> updatedEntityStates = Map.from(currentState.entityStates);
      
      if (event.widget.entityId.isNotEmpty) {
        try {
          final entityState = await _apiService?.getState(event.widget.entityId);
          if (entityState != null) {
            updatedEntityStates[event.widget.entityId] = entityState;
          }
        } catch (e) {
          // Handle error, but continue
        }
      }
      
      // Get all widgets again to ensure we have the updated list
      final widgets = _storageService.getDashboardWidgets();
      
      emit(currentState.copyWith(
        widgets: widgets,
        entityStates: updatedEntityStates,
      ));
    }
  }
  
  Future<void> _onUpdateDashboardWidget(UpdateDashboardWidget event, Emitter<DashboardState> emit) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      // Save the updated widget to storage
      await _storageService.saveDashboardWidget(event.widget);
      
      // Get all widgets again to ensure we have the updated list
      final widgets = _storageService.getDashboardWidgets();
      
      emit(currentState.copyWith(widgets: widgets));
    }
  }
  
  Future<void> _onDeleteDashboardWidget(DeleteDashboardWidget event, Emitter<DashboardState> emit) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      // Delete the widget from storage
      await _storageService.deleteDashboardWidget(event.id);
      
      // Get all widgets again to ensure we have the updated list
      final widgets = _storageService.getDashboardWidgets();
      
      emit(currentState.copyWith(widgets: widgets));
    }
  }
  
  void _onUpdateEntityState(UpdateEntityState event, Emitter<DashboardState> emit) {
    debugPrint('DashboardBloc: Handling UpdateEntityState for ${event.entityState.entityId}: ${event.entityState.state}');
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      // Update the entity state in the map
      final updatedEntityStates = Map<String, EntityState>.from(currentState.entityStates);
      updatedEntityStates[event.entityState.entityId] = event.entityState;
      
      debugPrint('DashboardBloc: Updated entityStates map, now contains ${updatedEntityStates.length} entries');
      emit(currentState.copyWith(entityStates: updatedEntityStates));
      debugPrint('DashboardBloc: Emitted new state with updated entity states');
    } else {
      debugPrint('DashboardBloc: Could not update entity state: current state is not DashboardLoaded');
    }
  }
  
  Future<void> _onReorderDashboardWidget(ReorderDashboardWidget event, Emitter<DashboardState> emit) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      // Get all widgets
      List<DashboardWidget> widgets = List.from(currentState.widgets);
      
      // Find the widget to reorder
      final int oldIndex = widgets.indexWhere((widget) => widget.id == event.widgetId);
      
      if (oldIndex != -1) {
        // Get the widget to move
        final widgetToMove = widgets[oldIndex];
        
        // Remove from old position
        widgets.removeAt(oldIndex);
        
        // Reinsert at new position, ensuring it's within bounds
        final newIndex = event.newPosition.clamp(0, widgets.length);
        widgets.insert(newIndex, widgetToMove);
        
        // Update all widgets with new positions for storage
        for (int i = 0; i < widgets.length; i++) {
          final widget = widgets[i];
          // Update the position (row for now, we can make this more sophisticated later)
          final updatedWidget = widget.copyWith(row: i);
          
          // Save to storage
          await _storageService.saveDashboardWidget(updatedWidget);
          
          // Update our list
          widgets[i] = updatedWidget;
        }
        
        // Emit the new state
        emit(currentState.copyWith(widgets: widgets));
      }
    }
  }
  
  Future<void> _onUpdateWidgetPosition(UpdateWidgetPosition event, Emitter<DashboardState> emit) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      // Find the widget to update
      final int widgetIndex = currentState.widgets.indexWhere((w) => w.id == event.widgetId);
      
      if (widgetIndex != -1) {
        final widget = currentState.widgets[widgetIndex];
        
        // Create updated widget with new position
        final updatedWidget = widget.copyWith(
          positionX: event.positionX,
          positionY: event.positionY,
        );
        
        // Save to storage
        await _storageService.saveDashboardWidget(updatedWidget);
        
        // Update the widget list
        final updatedWidgets = List<DashboardWidget>.from(currentState.widgets);
        updatedWidgets[widgetIndex] = updatedWidget;
        
        // Emit the new state
        emit(currentState.copyWith(widgets: updatedWidgets));
      }
    }
  }
  
  Future<void> _onUpdateWidgetSizeAndPosition(UpdateWidgetSizeAndPosition event, Emitter<DashboardState> emit) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      // Find the widget to update
      final int widgetIndex = currentState.widgets.indexWhere((w) => w.id == event.widgetId);
      
      if (widgetIndex != -1) {
        final widget = currentState.widgets[widgetIndex];
        
        // Create updated widget with new size and position
        final updatedWidget = widget.copyWith(
          widthPx: event.width.toDouble(),
          heightPx: event.height.toDouble(),
          positionX: event.positionX,
          positionY: event.positionY,
        );
        
        // Save to storage
        await _storageService.saveDashboardWidget(updatedWidget);
        
        // Update the widget list
        final updatedWidgets = List<DashboardWidget>.from(currentState.widgets);
        updatedWidgets[widgetIndex] = updatedWidget;
        
        // Emit the new state
        emit(currentState.copyWith(widgets: updatedWidgets));
      }
    }
  }
}
