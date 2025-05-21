import 'package:soco_flutter/src/utils/utils.dart';

import 'soap_service.dart';
import '../utils/xml_helper.dart';
import '../models/track.dart';

class AVTransportService {
  final SoapService _soapService;

  AVTransportService(String ipAddress)
      : _soapService = SoapService(
          baseUrl: "http://$ipAddress:1400",
          controlURL: '/MediaRenderer/AVTransport/Control',
          serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
        );

  Future<void> play() async {
    await _soapService.call('Play', {
      'InstanceID': '0',
      'Speed': '1',
    });
  }

  Future<void> pause() async {
    await _soapService.call('Pause', {
      'InstanceID': '0',
    });
  }

  Future<void> stop() async {
    await _soapService.call('Stop', {
      'InstanceID': '0',
    });
  }

  Future<void> next() async {
    await _soapService.call('Next', {
      'InstanceID': '0',
    });
  }

  Future<void> previous() async {
    await _soapService.call('Previous', {
      'InstanceID': '0',
    });
  }

  Future<Map<String, String>> getPositionInfo() async {
    return await _soapService.call('GetPositionInfo', {
      'InstanceID': '0',
    });
  }

  Future<Map<String, String>> getTransportInfo() async {
    return await _soapService.call('GetTransportInfo', {
      'InstanceID': '0',
    });
  }

  Future<Map<String, String>> getMediaInfo() async {
    return await _soapService.call('GetMediaInfo', {
      'InstanceID': '0',
    });
  }

  /// Récupère des informations sur la piste en cours de lecture
  Future<Track> getCurrentTrackInfo(String ipAddress) async {
    final response = await getPositionInfo();

    final trackMap = {
      'title': '',
      'artist': '',
      'album': '',
      'album_art': '',
      'position': response['RelTime'] ?? '',
      'duration': response['TrackDuration'] ?? '',
      'uri': response['TrackURI'] ?? '',
      'playlist_position': response['Track'] ?? '',
      'metadata': response['TrackMetaData'] ?? '',
    };

    final metadata = response['TrackMetaData'];
    if (metadata != null && metadata.isNotEmpty && metadata != 'NOT_IMPLEMENTED') {
      try {
        final parsedXml = XmlHelper.parseXml(metadata);

        // Extraction des métadonnées
        trackMap['title'] = XmlHelper.findElementText(parsedXml, 'dc:title') ?? '';
        trackMap['artist'] = XmlHelper.findElementText(parsedXml, 'dc:creator') ?? '';
        trackMap['album'] = XmlHelper.findElementText(parsedXml, 'upnp:album') ?? '';

        // Récupération de l'image d'album
        final albumArtUrl = XmlHelper.findElementText(parsedXml, 'upnp:albumArtURI');
        if (albumArtUrl != null) {
          trackMap['album_art'] = 'http://$ipAddress:1400$albumArtUrl';
        }
      } catch (e) {
        myPrint('Erreur lors du parsing XML: $e');
      }
    }

    return Track.fromMap(trackMap);
  }

  /// Récupère des informations sur le média en cours de lecture
  Future<Map<String, dynamic>> getCurrentMediaInfo() async {
    final response = await getMediaInfo();

    final media = {'uri': response['CurrentURI'] ?? '', 'channel': ''};

    // Traiter les métadonnées si elles existent
    final metadata = response['CurrentURIMetaData'];
    if (metadata != null && metadata.isNotEmpty) {
      try {
        final parsedXml = XmlHelper.parseXml(metadata);
        final title = XmlHelper.findElementText(parsedXml, 'dc:title');
        if (title != null) {
          media['channel'] = title;
        }
      } catch (e) {
        myPrint('Erreur lors du parsing XML: $e');
      }
    }

    return media;
  }

  /// Vérifie si le lecteur est en train de jouer
  Future<bool> isPlaying() async {
    final response = await getTransportInfo();
    final state = response['CurrentTransportState'];
    return state == 'PLAYING' || state == 'TRANSITIONING';
  }

  /// Add a track to the queue
  ///
  /// [uri] URI of the track to add
  /// [enqueuedUri] URI of the track to add (usually same as uri)
  /// [desiredFirstTrackNumberEnqueued] Position in queue (1-based, use 2147483647 for end)
  /// [enqueueAsNext] Whether to insert immediately after current track
  Future<Map<String, String>> addToQueue({required String uri, required String enqueuedUri, required int desiredFirstTrackNumberEnqueued, required bool enqueueAsNext}) async {
    return await _soapService.call('AddURIToQueue', {
      'InstanceID': '0',
      'EnqueuedURI': uri,
      'EnqueuedURIMetaData': '',
      'DesiredFirstTrackNumberEnqueued': desiredFirstTrackNumberEnqueued.toString(),
      'EnqueueAsNext': enqueueAsNext ? '1' : '0',
    });
  }

  /// Remove a track from the queue
  ///
  /// [objectID] The queue ID (typically 'Q:0')
  /// [updateID] Update ID (typically 0)
  /// [trackNumber] Position of track to remove (1-based)
  Future<void> removeTrackFromQueue({required String objectID, required int updateID, required int trackNumber}) async {
    await _soapService.call('RemoveTrackFromQueue', {
      'InstanceID': '0',
      'ObjectID': objectID,
      'UpdateID': updateID.toString(),
      'TrackNumber': trackNumber.toString(),
    });
  }

  /// Clear all tracks from the queue
  Future<void> removeAllTracksFromQueue() async {
    await _soapService.call('RemoveAllTracksFromQueue', {
      'InstanceID': '0',
    });
  }

  /// Seek to a specific position in current track or to a specific track
  ///
  /// [unit] Type of seek ('REL_TIME' for time position or 'TRACK_NR' for track)
  /// [target] Target value (time format 'HH:MM:SS' or track number)
  Future<void> seek({required String unit, required String target}) async {
    await _soapService.call('Seek', {
      'InstanceID': '0',
      'Unit': unit,
      'Target': target,
    });
  }

  Future<void> startLiveAudioStream(String streamUrl) async {
    try {
      // Formater l'URL pour Sonos
      final radioUrl = "x-rincon-mp3radio://$streamUrl";
      // final radioUrl = "x-rincon-mp3radio://http://icecast.radiofrance.fr/fip-hifi.aac";
      myPrint("Tentative de streaming audio vers Sonos: $radioUrl");
      // Arrêter la lecture en cours
      try {
        await stop();
      } catch (e) {
        myPrint("Erreur lors de l'arrêt (peut être ignorée): $e");
      }

      // Envoyer l'URL de streaming au Sonos
      await _soapService.call('SetAVTransportURI', {
        'InstanceID': '0',
        'CurrentURI': radioUrl,
        'CurrentURIMetaData': '',
      });

      // Démarrer la lecture
      await play();

      myPrint("Streaming audio en direct vers Sonos");
    } catch (e) {
      myPrint("Erreur lors du démarrage du stream: $e");
      throw Exception("Impossible de démarrer le stream audio: $e");
    }
  }

}
