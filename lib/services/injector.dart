import 'dart:async';
import 'package:breez/services/breezlib/breez_bridge.dart';
import 'package:breez/services/breez_server/server.dart';
import 'package:breez/services/deep_links.dart';
import 'package:breez/services/device.dart';
import 'package:breez/services/notifications.dart';
import 'package:breez/services/nfc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:breez/services/lightning_links.dart';

class ServiceInjector {
  static final _singleton = new ServiceInjector._internal();
  static ServiceInjector _injector;

  BreezServer _breezServer;  
  FirebaseNotifications _notifications;
  BreezBridge _breezBridge;
  NFCService _nfcService;
  DeepLinksService _deepLinksService;
  LightningLinksService _lightningLinksService;
  Device _device;

  factory ServiceInjector() {
    return _injector != null ? _injector : _singleton;
  }

  ServiceInjector._internal();

  static void configure(ServiceInjector injector) {
    _injector = injector;
  }

  Notifications get notifications {
    return _notifications ??= FirebaseNotifications();
  }

  NFCService get nfc {
    return _nfcService ??= new NFCService();
  }

  BreezServer get breezServer {
    return _breezServer ??= new BreezServer()..initChannel();
  }

  BreezBridge get breezBridge {
    return _breezBridge ??= new BreezBridge();
  }

  Device get device => _device ?? Device();

  DeepLinksService get deepLinks => _deepLinksService ??= new DeepLinksService();
  LightningLinksService get lightningLinks => _lightningLinksService ??= new LightningLinksService();

  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();
}
