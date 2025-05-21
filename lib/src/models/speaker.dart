import 'package:soco_flutter/soco_flutter.dart';
import 'package:soco_flutter/src/utils/utils.dart';

class Speaker {
  Map<String, dynamic> speakerInfo = {};

  late String _ipAddress;
  int volume = 0;

  String? _uid;
  String? get uid => _uid;

  String? _householdId;
  String? get householdId => _householdId;

  String? _playerName;
  String? get playerName => _playerName;

  Track? _currentTrack;
  Track? get currentTrack => _currentTrack;

  String get ipAddress => _ipAddress;

  // Services
  late final AVTransportService avTransport;
  late final DeviceProperties deviceProperties;
  late final RenderingControlService renderingControl;

  // Constructor
  Speaker(String ipAddress) {
    _ipAddress = ipAddress;
    avTransport = AVTransportService(ipAddress);
    deviceProperties = DeviceProperties(ipAddress);
    renderingControl = RenderingControlService(ipAddress);
    
    _initializeSpeaker();
  }
  
  Future<void> _initializeSpeaker() async {
    try {
      final info = await deviceProperties.getDeviceInfo();
      _playerName = info['zone_name'];
      _uid = info['UDN'];
      _householdId = info['householdID'];
      speakerInfo = info;
    } catch (e) {
      myPrint('Erreur lors de l\'initialisation: $e');
    }
  }

  Future<int> getVolume() async {
    return await renderingControl.getVolume();
  }

  Future<void> play() => avTransport.play();

  Future<void> pause() => avTransport.pause();

  Future<void> setVolume(int value) {
    volume = value;
    return renderingControl.setVolume(value);
  }

  Future<void> mute() => renderingControl.setMute(true);

  Future<void> unmute() => renderingControl.setMute(false);

  /// Récupère des informations sur la piste en cours de lecture
  Future<Track> getCurrentTrackInfo() async {
    _currentTrack = await avTransport.getCurrentTrackInfo(_ipAddress);
    return _currentTrack!;
  }

  /// Récupère des informations sur le média en cours de lecture
  Future<Map<String, dynamic>> getCurrentMediaInfo() async {
    return await avTransport.getCurrentMediaInfo();
  }
  
  /// Récupère l'état de lecture actuel
  Future<Map<String, String>> getCurrentTransportInfo() async {
    return await avTransport.getTransportInfo();
  }

  Future<void> previousTrack() async {
    await avTransport.previous();
    await getCurrentTrackInfo();
  }

  Future<void> nextTrack() async {
    await avTransport.next();
    await getCurrentTrackInfo();
  }

  Future<bool> isPlaying() async {
    return await avTransport.isPlaying();
  }
}
