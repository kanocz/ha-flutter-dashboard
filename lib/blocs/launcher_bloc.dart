import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';

// Events
abstract class LauncherEvent {}

class ToggleLauncherMode extends LauncherEvent {
  final bool isLauncher;
  ToggleLauncherMode(this.isLauncher);
}

class CheckLauncherMode extends LauncherEvent {}

// States
class LauncherState {
  final bool isLauncher;
  
  LauncherState(this.isLauncher);
  
  LauncherState copyWith({bool? isLauncher}) {
    return LauncherState(isLauncher ?? this.isLauncher);
  }
}

// BLoC
class LauncherBloc extends Bloc<LauncherEvent, LauncherState> {
  final StorageService _storageService;
  
  LauncherBloc({required StorageService storageService}) 
    : _storageService = storageService,
      super(LauncherState(false)) {
    on<ToggleLauncherMode>(_onToggleLauncherMode);
    on<CheckLauncherMode>(_onCheckLauncherMode);
    
    // Check launcher mode on initialization
    add(CheckLauncherMode());
  }
  
  Future<void> _onToggleLauncherMode(ToggleLauncherMode event, Emitter<LauncherState> emit) async {
    await _storageService.setIsLauncher(event.isLauncher);
    emit(state.copyWith(isLauncher: event.isLauncher));
  }
  
  void _onCheckLauncherMode(CheckLauncherMode event, Emitter<LauncherState> emit) {
    final isLauncher = _storageService.isLauncher();
    emit(state.copyWith(isLauncher: isLauncher));
  }
}
