import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';

// Events
abstract class ThemeEvent {}

class ToggleThemeMode extends ThemeEvent {
  final ThemeMode mode;
  ToggleThemeMode(this.mode);
}

class UpdateGridDimensions extends ThemeEvent {
  final int portraitColumns;
  final int portraitRows;
  final int landscapeColumns;
  final int landscapeRows;

  UpdateGridDimensions({
    required this.portraitColumns,
    required this.portraitRows,
    required this.landscapeColumns,
    required this.landscapeRows,
  });
}

// States
class ThemeState {
  final ThemeMode themeMode;
  final int gridPortraitColumns;
  final int gridPortraitRows;
  final int gridLandscapeColumns;
  final int gridLandscapeRows;
  
  ThemeState({
    required this.themeMode,
    this.gridPortraitColumns = AppConstants.defaultGridWidthPortrait,
    this.gridPortraitRows = AppConstants.defaultGridHeightPortrait,
    this.gridLandscapeColumns = AppConstants.defaultGridWidthLandscape,
    this.gridLandscapeRows = AppConstants.defaultGridHeightLandscape,
  });
  
  ThemeState copyWith({
    ThemeMode? themeMode,
    int? gridPortraitColumns,
    int? gridPortraitRows,
    int? gridLandscapeColumns,
    int? gridLandscapeRows,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      gridPortraitColumns: gridPortraitColumns ?? this.gridPortraitColumns,
      gridPortraitRows: gridPortraitRows ?? this.gridPortraitRows,
      gridLandscapeColumns: gridLandscapeColumns ?? this.gridLandscapeColumns,
      gridLandscapeRows: gridLandscapeRows ?? this.gridLandscapeRows,
    );
  }
}

// BLoC
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final StorageService _storageService;
  
  ThemeBloc({required StorageService storageService}) 
    : _storageService = storageService,
      super(ThemeState(themeMode: ThemeMode.system)) {
    on<ToggleThemeMode>(_onToggleThemeMode);
    on<UpdateGridDimensions>(_onUpdateGridDimensions);
    
    _init();
  }
  
  void _init() {
    final themeMode = _storageService.getThemeMode();
    final gridDimensions = _storageService.getGridDimensions();
    
    emit(ThemeState(
      themeMode: themeMode,
      gridPortraitColumns: gridDimensions['portraitColumns'] as int,
      gridPortraitRows: gridDimensions['portraitRows'] as int,
      gridLandscapeColumns: gridDimensions['landscapeColumns'] as int,
      gridLandscapeRows: gridDimensions['landscapeRows'] as int,
    ));
  }
  
  Future<void> _onToggleThemeMode(ToggleThemeMode event, Emitter<ThemeState> emit) async {
    await _storageService.setThemeMode(event.mode);
    emit(state.copyWith(themeMode: event.mode));
  }
  
  Future<void> _onUpdateGridDimensions(UpdateGridDimensions event, Emitter<ThemeState> emit) async {
    await _storageService.setGridDimensions(
      portraitColumns: event.portraitColumns,
      portraitRows: event.portraitRows,
      landscapeColumns: event.landscapeColumns,
      landscapeRows: event.landscapeRows,
    );
    
    emit(state.copyWith(
      gridPortraitColumns: event.portraitColumns,
      gridPortraitRows: event.portraitRows,
      gridLandscapeColumns: event.landscapeColumns,
      gridLandscapeRows: event.landscapeRows,
    ));
  }
}
