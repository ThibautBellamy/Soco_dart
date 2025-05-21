import 'soap_service.dart';

/// Service pour contrôler les aspects audio d'une enceinte Sonos comme
/// le volume, la mise en sourdine, l'égalisation, etc.
class RenderingControlService {
  /// Service SOAP sous-jacent
  final SoapService _soapService;
  
  /// Crée un nouveau service de contrôle du rendu
  /// 
  /// [ipAddress] est l'adresse IP de l'enceinte Sonos
  RenderingControlService(String ipAddress)
      : _soapService = SoapService(
          baseUrl: "http://$ipAddress:1400",  // Ajout du protocole et du port
          controlURL: '/MediaRenderer/RenderingControl/Control',
          serviceType: 'urn:schemas-upnp-org:service:RenderingControl:1',
        );

  /// Récupère le volume actuel (0-100)
  Future<int> getVolume([String channel = 'Master']) async {
    final response = await _soapService.call('GetVolume', {
      'InstanceID': '0',
      'Channel': channel,
    });
    
    return int.tryParse(response['CurrentVolume'] ?? '0') ?? 0;
  }

  /// Définit le volume (0-100)
  Future<void> setVolume(int volume, [String channel = 'Master']) async {
    // S'assurer que le volume est dans la plage valide
    int safeVolume = volume.clamp(0, 100);
    
    await _soapService.call('SetVolume', {
      'InstanceID': '0',
      'Channel': channel,
      'DesiredVolume': safeVolume.toString(),
    });
  }

  /// Augmente le volume de la valeur spécifiée
  Future<void> setRelativeVolume(int adjustment, [String channel = 'Master']) async {
    await _soapService.call('SetRelativeVolume', {
      'InstanceID': '0',
      'Channel': channel,
      'Adjustment': adjustment.toString(),
    });
  }

  /// Vérifie si l'enceinte est en sourdine
  Future<bool> getMute([String channel = 'Master']) async {
    final response = await _soapService.call('GetMute', {
      'InstanceID': '0',
      'Channel': channel,
    });
    
    return response['CurrentMute'] == '1';
  }

  /// Active ou désactive la sourdine
  Future<void> setMute(bool mute, [String channel = 'Master']) async {
    await _soapService.call('SetMute', {
      'InstanceID': '0',
      'Channel': channel,
      'DesiredMute': mute ? '1' : '0',
    });
  }
  
  /// Récupère les niveaux d'égalisation
  Future<Map<String, int>> getEQ() async {
    final bass = await _getBass();
    final treble = await _getTreble();
    
    return {
      'bass': bass,
      'treble': treble,
    };
  }

  /// Récupère le niveau de basses (-10 à +10)
  Future<int> _getBass() async {
    final response = await _soapService.call('GetBass', {
      'InstanceID': '0',
      'Channel': 'Master',
    });
    
    return int.tryParse(response['CurrentBass'] ?? '0') ?? 0;
  }

  /// Définit le niveau de basses (-10 à +10)
  Future<void> setBass(int level) async {
    // S'assurer que le niveau est dans la plage valide
    int safeLevel = level.clamp(-10, 10);
    
    await _soapService.call('SetBass', {
      'InstanceID': '0',
      'DesiredBass': safeLevel.toString(),
    });
  }

  /// Récupère le niveau d'aigus (-10 à +10)
  Future<int> _getTreble() async {
    final response = await _soapService.call('GetTreble', {
      'InstanceID': '0',
      'Channel': 'Master',
    });
    
    return int.tryParse(response['CurrentTreble'] ?? '0') ?? 0;
  }

  /// Définit le niveau d'aigus (-10 à +10)
  Future<void> setTreble(int level) async {
    // S'assurer que le niveau est dans la plage valide
    int safeLevel = level.clamp(-10, 10);
    
    await _soapService.call('SetTreble', {
      'InstanceID': '0',
      'DesiredTreble': safeLevel.toString(),
    });
  }
  
  /// Récupère l'état d'activation de la fonction Loudness
  Future<bool> getLoudness([String channel = 'Master']) async {
    final response = await _soapService.call('GetLoudness', {
      'InstanceID': '0',
      'Channel': channel,
    });
    
    return response['CurrentLoudness'] == '1';
  }
  
  /// Active ou désactive la fonction Loudness
  Future<void> setLoudness(bool enable, [String channel = 'Master']) async {
    await _soapService.call('SetLoudness', {
      'InstanceID': '0',
      'Channel': channel,
      'DesiredLoudness': enable ? '1' : '0',
    });
  }
}