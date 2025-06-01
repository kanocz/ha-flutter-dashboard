import 'dart:async';
import 'dart:io';

import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/models/home_assistant_instance.dart';
import 'package:multicast_dns/multicast_dns.dart';

class HomeAssistantDiscoveryService {
  final List<HomeAssistantInstance> _discoveredInstances = [];
  StreamController<List<HomeAssistantInstance>>? _instancesController;
  Stream<List<HomeAssistantInstance>>? instancesStream;
  
  bool _isScanning = false;
  Timer? _scanTimer;
  
  HomeAssistantDiscoveryService() {
    _instancesController = StreamController<List<HomeAssistantInstance>>.broadcast();
    instancesStream = _instancesController?.stream;
  }
  
  void dispose() {
    _scanTimer?.cancel();
    _instancesController?.close();
  }
  
  List<HomeAssistantInstance> get discoveredInstances => List.from(_discoveredInstances);
  
  Future<void> startDiscovery({Duration duration = const Duration(seconds: 30)}) async {
    if (_isScanning) return;
    
    _isScanning = true;
    _discoveredInstances.clear();
    _instancesController?.add(_discoveredInstances);
    
    try {
      final MDnsClient client = MDnsClient();
      await client.start();
      
      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(AppConstants.haDiscoveryUrl),
      )) {
        await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final IPAddressResourceRecord ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            final String hostIP = ip.address.address;
            
            // Try to determine if this is HTTP or HTTPS
            String url = 'http://$hostIP:${srv.port}';
            
            final instance = HomeAssistantInstance(
              id: srv.name,
              name: srv.name.split('.').first,
              url: url,
            );
            
            if (!_discoveredInstances.any((element) => element.id == instance.id)) {
              _discoveredInstances.add(instance);
              _instancesController?.add(_discoveredInstances);
            }
          }
        }
      }
      
      client.stop();
    } on SocketException catch (_) {
      // Handle network unavailable errors
    } catch (e) {
      // Handle other exceptions
    } finally {
      _scanTimer?.cancel();
      _scanTimer = Timer(duration, () {
        _isScanning = false;
      });
    }
  }
  
  void addManualInstance(HomeAssistantInstance instance) {
    final manualInstance = HomeAssistantInstance(
      id: instance.id,
      name: instance.name,
      url: instance.url,
      isManuallyAdded: true,
    );
    
    if (!_discoveredInstances.any((element) => element.id == manualInstance.id)) {
      _discoveredInstances.add(manualInstance);
      _instancesController?.add(_discoveredInstances);
    }
  }
  
  void removeInstance(String id) {
    _discoveredInstances.removeWhere((instance) => instance.id == id);
    _instancesController?.add(_discoveredInstances);
  }
}
