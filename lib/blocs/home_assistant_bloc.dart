import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/models/home_assistant_instance.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_discovery_service.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';

// Events
abstract class HomeAssistantEvent {}

class DiscoverInstances extends HomeAssistantEvent {}
class AddManualInstance extends HomeAssistantEvent {
  final HomeAssistantInstance instance;
  AddManualInstance(this.instance);
}
class RemoveInstance extends HomeAssistantEvent {
  final String id;
  RemoveInstance(this.id);
}
class SelectInstance extends HomeAssistantEvent {
  final String id;
  SelectInstance(this.id);
}
class SetLongTermToken extends HomeAssistantEvent {
  final String token;
  SetLongTermToken(this.token);
}

// States
abstract class HomeAssistantState {}

class HomeAssistantInitial extends HomeAssistantState {}
class HomeAssistantLoading extends HomeAssistantState {}
class HomeAssistantLoaded extends HomeAssistantState {
  final List<HomeAssistantInstance> instances;
  final String? selectedInstanceId;
  final String? token;
  
  HomeAssistantLoaded({
    required this.instances,
    this.selectedInstanceId,
    this.token,
  });
  
  HomeAssistantInstance? get selectedInstance => 
      instances.where((instance) => instance.id == selectedInstanceId).firstOrNull;
      
  bool get isAuthenticated => token != null && token!.isNotEmpty;
  
  HomeAssistantLoaded copyWith({
    List<HomeAssistantInstance>? instances,
    String? selectedInstanceId,
    String? token,
  }) {
    return HomeAssistantLoaded(
      instances: instances ?? this.instances,
      selectedInstanceId: selectedInstanceId ?? this.selectedInstanceId,
      token: token ?? this.token,
    );
  }
}
class HomeAssistantError extends HomeAssistantState {
  final String message;
  HomeAssistantError(this.message);
}

// BLoC
class HomeAssistantBloc extends Bloc<HomeAssistantEvent, HomeAssistantState> {
  final HomeAssistantDiscoveryService _discoveryService;
  final StorageService _storageService;
  
  HomeAssistantBloc({
    required HomeAssistantDiscoveryService discoveryService,
    required StorageService storageService,
  }) : _discoveryService = discoveryService,
       _storageService = storageService,
       super(HomeAssistantInitial()) {
    on<DiscoverInstances>(_onDiscoverInstances);
    on<AddManualInstance>(_onAddManualInstance);
    on<RemoveInstance>(_onRemoveInstance);
    on<SelectInstance>(_onSelectInstance);
    on<SetLongTermToken>(_onSetLongTermToken);
    
    _init();
  }
  
  Future<void> _init() async {
    // Load the instances and selected instance from storage
    final instances = _storageService.getHomeAssistantInstances();
    final selectedInstanceId = _storageService.getSelectedHomeAssistantInstanceId();
    final token = _storageService.getLongTermToken();
    
    // Add the instances to the discovery service
    for (final instance in instances) {
      if (instance.isManuallyAdded) {
        _discoveryService.addManualInstance(instance);
      }
    }
    
    emit(HomeAssistantLoaded(
      instances: instances,
      selectedInstanceId: selectedInstanceId,
      token: token,
    ));
  }
  
  Future<void> _onDiscoverInstances(DiscoverInstances event, Emitter<HomeAssistantState> emit) async {
    if (state is HomeAssistantLoaded) {
      emit(HomeAssistantLoading());
      
      await _discoveryService.startDiscovery();
      
      // Get the instances from the discovery service
      final instances = _discoveryService.discoveredInstances;
      
      // Save the instances to storage
      await _storageService.saveHomeAssistantInstances(instances);
      
      final selectedInstanceId = _storageService.getSelectedHomeAssistantInstanceId();
      final token = _storageService.getLongTermToken();
      
      emit(HomeAssistantLoaded(
        instances: instances,
        selectedInstanceId: selectedInstanceId,
        token: token,
      ));
    }
  }
  
  Future<void> _onAddManualInstance(AddManualInstance event, Emitter<HomeAssistantState> emit) async {
    if (state is HomeAssistantLoaded) {
      final currentState = state as HomeAssistantLoaded;
      
      // Add the instance to the discovery service
      _discoveryService.addManualInstance(event.instance);
      
      // Get the updated instances
      final instances = _discoveryService.discoveredInstances;
      
      // Save the instances to storage
      await _storageService.saveHomeAssistantInstances(instances);
      
      emit(currentState.copyWith(instances: instances));
    }
  }
  
  Future<void> _onRemoveInstance(RemoveInstance event, Emitter<HomeAssistantState> emit) async {
    if (state is HomeAssistantLoaded) {
      final currentState = state as HomeAssistantLoaded;
      
      // Remove the instance from the discovery service
      _discoveryService.removeInstance(event.id);
      
      // Get the updated instances
      final instances = _discoveryService.discoveredInstances;
      
      // Save the instances to storage
      await _storageService.saveHomeAssistantInstances(instances);
      
      // If the removed instance was the selected one, clear the selection
      String? selectedInstanceId = currentState.selectedInstanceId;
      if (selectedInstanceId == event.id) {
        selectedInstanceId = null;
        await _storageService.setSelectedHomeAssistantInstanceId('');
      }
      
      emit(currentState.copyWith(
        instances: instances,
        selectedInstanceId: selectedInstanceId,
      ));
    }
  }
  
  Future<void> _onSelectInstance(SelectInstance event, Emitter<HomeAssistantState> emit) async {
    if (state is HomeAssistantLoaded) {
      final currentState = state as HomeAssistantLoaded;
      
      // Save the selected instance to storage
      await _storageService.setSelectedHomeAssistantInstanceId(event.id);
      
      emit(currentState.copyWith(selectedInstanceId: event.id));
    }
  }
  
  Future<void> _onSetLongTermToken(SetLongTermToken event, Emitter<HomeAssistantState> emit) async {
    if (state is HomeAssistantLoaded) {
      final currentState = state as HomeAssistantLoaded;
      
      // Save the token to storage
      await _storageService.setLongTermToken(event.token);
      
      emit(currentState.copyWith(token: event.token));
    }
  }
}
