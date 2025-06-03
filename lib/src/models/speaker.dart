import 'package:soco_flutter/soco_dart.dart';
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

  // Ajouter cette variable pour stocker l'état
  SpeakerState? _savedState;

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

  // Sauvegarder l'état actuel du speaker
  Future<void> saveState() async {
    try {
      // Récupérer les informations nécessaires
      final Track? track = await getCurrentTrackInfo();
      final transportInfo = await getCurrentTransportInfo();
      final position = await avTransport.getPositionInfo();
      final volume = await getVolume();
      
      // Récupérer la queue actuelle
      final sonosQueue = SonosQueue(this);
      final queue = await sonosQueue.getQueue(maxItems: 1000);
      
      // Récupérer les modes de lecture
      final playMode = await avTransport.getPlayMode();
      
      // Créer l'objet d'état
      _savedState = SpeakerState(
        currentTrackUri: track?.uri,
        positionInTrack:  int.tryParse(position['RelTime'] ?? '0') ?? 0 ,
        queue: queue.map((item) => item.uri).toList(),
        volumeLevel: volume,
        isPlaying: transportInfo['CurrentTransportState'] == 'PLAYING',
        shuffle: playMode['SHUFFLE'] == 'ON',
        repeat: playMode['REPEAT'] == 'ALL',
      );
      
      myPrint("État sauvegardé pour $playerName: ${track?.title ?? 'Aucune piste en cours'}");
      return;
    } catch (e) {
      myPrint("Erreur lors de la sauvegarde de l'état du speaker: $e");
      _savedState = null;
    }
  }
  
  // Restaurer l'état précédemment sauvegardé
  Future<void> restoreState() async {
    if (_savedState == null) {
      myPrint("Aucun état à restaurer");
      return;
    }
    
    try {
      // Restaurer le volume en premier pour éviter les sons forts non désirés
      myPrint("Restaurer le volume à ${_savedState!.volumeLevel}");
      await setVolume(_savedState!.volumeLevel);
      
      // Restaurer la queue si nécessaire
      if (_savedState!.queue.isNotEmpty) {
        myPrint("Restaurer la queue");
        await avTransport.restoreQueue(_savedState!.queue);
        
        // Si nous avions une piste en cours, déterminer son index dans la queue
        if (_savedState!.currentTrackUri != null) {
          // Trouver l'index de la piste actuelle dans la queue
          final currentTrackIndex = _savedState!.queue.indexOf(_savedState!.currentTrackUri);
          
          if (currentTrackIndex >= 0) {
            // Sélectionner la piste par numéro dans la queue (les numéros commencent à 1)
            myPrint("Sélectionner la piste à l'index ${currentTrackIndex + 1}");
            await avTransport.seek(unit: 'TRACK_NR', target: (currentTrackIndex + 1).toString());
            
            // Restaurer la position dans la piste
            if (_savedState!.positionInTrack > 0) {
              final timeFormat = _formatTime(_savedState!.positionInTrack);
              await avTransport.seek(unit: 'REL_TIME', target: timeFormat);
            }
            
            // Reprendre la lecture si nécessaire
            if (_savedState!.isPlaying) {
              myPrint("Reprendre la lecture");
              await play();
            }
          } else {
            // Si la piste n'est pas dans la queue, essayer de la restaurer directement
            // Cela peut fonctionner pour certains types d'URI comme les radios
            if (!_savedState!.currentTrackUri!.startsWith('x-sonos-')) {
              myPrint("Essayer de restaurer la source directement: ${_savedState!.currentTrackUri}");
              await avTransport.setAVTransportURI(_savedState!.currentTrackUri!);
              
              if (_savedState!.isPlaying) {
                await play();
              }
            }
          }
        }
      }
      
      // Restaurer les modes de lecture
      await avTransport.setPlayMode(
        shuffle: _savedState!.shuffle,
        repeat: _savedState!.repeat
      );
      
      myPrint("État restauré avec succès pour $playerName");
    } catch (e) {
      myPrint("Erreur lors de la restauration de l'état: $e");
    } finally {
      // Libérer la mémoire
      _savedState = null;
    }
  }
  
  // Méthode utilitaire pour formater le temps en format HH:MM:SS
  String _formatTime(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final remainingSeconds = seconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${remainingSeconds.toString().padLeft(2, '0')}';
  }
}


class SpeakerState {
  final String? currentTrackUri;
  final int positionInTrack; // en millisecondes
  final List<String?> queue;
  final int volumeLevel;
  final bool isPlaying;
  final bool shuffle;
  final bool repeat;

  SpeakerState({
    this.currentTrackUri,
    this.positionInTrack = 0,
    this.queue = const [],
    this.volumeLevel = 20,
    this.isPlaying = false,
    this.shuffle = false,
    this.repeat = false,
  });
}