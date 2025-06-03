import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:soco_dart/src/utils/utils.dart';
import 'package:soco_dart/src/models/speaker.dart';

class MicrophoneStreamService {
  final _audioRecorder = AudioRecorder();
  HttpServer? _server;
  bool _isStreamingActive = false;
  final int _streamPort = 8090;
  String? _localIp;
  StreamSubscription? _audioStreamSubscription;

  // Buffer pour stocker les données audio
  final List<int> _audioBuffer = [];
  final int _maxBufferSize = 64 * 1024; // Réduire de 1MB à 64KB

  // Liste des clients connectés pour remplacer forEach
  final List<HttpResponse> _clients = [];

  Speaker? _targetSpeaker;

  Future<void> initialize() async {
    _localIp = await _getLocalIpAddress();
    if (_localIp == null) {
      throw Exception("Impossible de déterminer l'adresse IP locale");
    }
  }

  Future<String?> _getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    for (var interface in interfaces) {
      if (!interface.name.toLowerCase().contains('virtual') && !interface.name.toLowerCase().contains('vmware') && !interface.name.toLowerCase().contains('vethernet')) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    }
    return null;
  }

  Future<String?> startStreaming(Speaker speaker) async {
    if (_isStreamingActive) {
      myPrint("Streaming déjà actif, arrêt avant redémarrage");
      await stopStreaming();
    }

    if (_localIp == null) return null;

    try {
      _targetSpeaker = speaker;

      // Sauvegarder l'état actuel du speaker
      await _targetSpeaker!.saveState();

      // Vider le buffer et la liste des clients
      _audioBuffer.clear();
      _clients.clear();

      // Démarrer le serveur HTTP
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _streamPort);
      myPrint("Serveur HTTP démarré sur $_localIp:$_streamPort");
      myPrint("Pour tester la connexion au serveur audio, ouvrez: http://$_localIp:$_streamPort dans un navigateur");

      // Utiliser un nouvel écouteur pour gérer les nouvelles connexions
      _server!.listen((request) {
        myPrint("Nouvelle connexion audio reçue");

        // Configurer pour streaming à faible latence
        request.response.bufferOutput = false; // Désactiver la mise en tampon

        // En-têtes pour streaming audio
        request.response.headers.add('Content-Type', 'audio/aac'); // Format plus standard
        request.response.headers.add('Connection', 'Keep-Alive');
        request.response.headers.add('Cache-Control', 'no-cache, no-store');
        request.response.headers.add('X-Accel-Buffering', 'no');
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Transfer-Encoding', 'chunked');

        // Envoyer une fraction minimale des dernières données du buffer
        if (_audioBuffer.isNotEmpty) {
          // Limiter à ~0.1 seconde de données
          final int startIndex = _audioBuffer.length > 2048 ? _audioBuffer.length - 2048 : 0;
          request.response.add(Uint8List.fromList(_audioBuffer.sublist(startIndex)));
        }

        // Ajouter à la liste des clients
        _clients.add(request.response);

        // Gérer la déconnexion
        request.response.done.then((_) {
          _clients.remove(request.response);
        }).catchError((e) {
          _clients.remove(request.response);
        });
      });

      // Démarrer le flux audio avec des paramètres optimisés
      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.aacLc, // Garder AAC-LC qui fonctionne
        sampleRate: 44100, // Revenir à 44100 Hz pour plus de stabilité
        numChannels: 1,
        bitRate: 96000, // Bitrate modéré
      ));

      // Écouter le flux audio
      _audioStreamSubscription = stream.listen((data) {
        // Ajouter directement au buffer (données brutes)
        _audioBuffer.addAll(data);

        // Limiter la taille du buffer
        if (_audioBuffer.length > 16 * 1024) {
          // Réduire davantage à 16KB
          _audioBuffer.removeRange(0, _audioBuffer.length - (16 * 1024));
        }

        // Envoyer aux clients - IMPORTANT: ne pas utiliser forEach ici
        for (var i = _clients.length - 1; i >= 0; i--) {
          try {
            _clients[i].add(data); // Garder l'envoi des données brutes qui fonctionnait
          } catch (e) {
            // Client déconnecté, le supprimer
            myPrint("Erreur d'envoi au client: $e");
            try {
              _clients.removeAt(i);
            } catch (_) {}
          }
        }
      });

      _isStreamingActive = true;

      return "$_localIp:$_streamPort/audio.aac";
      // Format d'URL pour Sonos avec paramètre de buffer réduit
      // return "$_localIp:$_streamPort/audio.aac?buffer=minimal";
    } catch (e) {
      myPrint("Erreur de démarrage du streaming: $e");
      await stopStreaming();
      return null;
    }
  }

  Future<void> stopStreaming() async {
    if (!_isStreamingActive) return;

    // Annuler l'abonnement au stream audio
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    // Arrêter l'enregistreur
    try {
      await _audioRecorder.stop();
    } catch (e) {
      myPrint("Erreur lors de l'arrêt de l'enregistreur: $e");
    }

    // Fermer toutes les connexions clients
    for (var client in List.from(_clients)) {
      try {
        await client.close();
      } catch (e) {
        myPrint("Erreur lors de la fermeture du client: $e");
      }
    }
    _clients.clear();

    // Fermer le serveur
    await _server?.close(force: true);
    _server = null;

    // Restaurer l'état du speaker s'il existe
    if (_targetSpeaker != null) {
      await _targetSpeaker!.restoreState();
      _targetSpeaker = null;
    }

    _isStreamingActive = false;
    myPrint("Streaming audio arrêté");
  }

  Uint8List _addADTSHeaderToAAC(Uint8List aacData) {
    // Paramètres pour AAC-LC à 44.1kHz, mono
    final int profile = 2; // AAC-LC = 2
    final int freqIdx = 4; // 44.1kHz = 4
    final int chanCfg = 1; // mono = 1

    // Calculer la taille du paquet avec l'en-tête ADTS (7 octets)
    final int packetLen = aacData.length + 7;

    // Créer l'en-tête ADTS
    final Uint8List header = Uint8List(7);

    // Syncword: 0xFFF (tous les bits à 1)
    header[0] = 0xFF;
    header[1] = 0xF1; // +protection absent

    // Profile, sampling freq, private bit, channel config, etc.
    header[2] = ((profile - 1) << 6) | (freqIdx << 2) | (chanCfg >> 2);
    header[3] = ((chanCfg & 3) << 6) | (packetLen >> 11);
    header[4] = (packetLen >> 3) & 0xFF;
    header[5] = ((packetLen & 7) << 5) | 0x1F;
    header[6] = 0xFC;

    // Combiner l'en-tête et les données AAC
    final Uint8List result = Uint8List(header.length + aacData.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, aacData);

    return result;
  }

  void logData(data) {
    if (data.isNotEmpty) {
      // Calculer le niveau audio (mesure simple d'intensité)
      int sum = 0;
      for (int i = 0; i < data.length; i += 2) {
        if (i + 1 < data.length) {
          // Convertir deux octets en valeur 16 bits
          int sample = data[i] | (data[i + 1] << 8);
          // Si c'est une valeur signée (généralement le cas)
          if (sample > 32767) sample -= 65536;
          sum += sample.abs();
        }
      }
      int avgLevel = sum ~/ (data.length / 2);
      myPrint("Audio reçu: ${data.length} octets, niveau: $avgLevel");
    } else {
      myPrint("Alerte: trame audio vide reçue");
    }
  }
}
