import 'package:soco_dart/src/models/speaker.dart';
import 'package:soco_dart/src/models/track.dart';
import 'package:soco_dart/src/services/av_transport.dart';
import 'package:soco_dart/src/services/content_directory.dart';

/// Manages the playback queue for a Sonos speaker
class SonosQueue {
  // ignore: unused_field
  final Speaker _speaker;
  final AVTransportService _avTransportService;
  final ContentDirectoryService _contentDirectoryService;

  /// Creates a new queue manager for the specified speaker
  SonosQueue(this._speaker)
      : _avTransportService = AVTransportService(_speaker.ipAddress),
        _contentDirectoryService = ContentDirectoryService(_speaker.ipAddress);

  /// Get the current queue contents
  /// 
  /// [startIndex] First item to return (0-based)
  /// [maxItems] Maximum number of items to return
  Future<List<Track>> getQueue({int startIndex = 0, int maxItems = 100}) async {
    final result = await _contentDirectoryService.browse(
      objectId: 'Q:0',
      browseFlag: 'BrowseDirectChildren',
      filter: '*',
      startingIndex: startIndex,
      requestedCount: maxItems,
    );

    if (result.containsKey('Result')) {
      final xmlResult = result['Result'] as String;
      return _parseQueueXml(xmlResult);
    }
    
    return [];
  }

  /// Add one or more tracks to the queue
  /// 
  /// [uris] URIs of the tracks to add
  /// [position] Position in the queue to add the tracks (default: end)
  /// [asNext] Whether to insert immediately after current track
  Future<int> addToQueue({
    required List<String> uris, 
    int? position,
    bool asNext = false,
  }) async {
    if (uris.isEmpty) return 0;
    
    int insertPosition = position ?? 0;
    
    if (asNext && position == null) {
      // Get current track position and insert after it
      final positionInfo = await _avTransportService.getPositionInfo();
      insertPosition = int.tryParse(positionInfo['Track'] ?? '0') ?? 0;
    } else if (position == null) {
      // Add to the end by default
      insertPosition = 2147483647; // Max int as per Sonos API docs
    }
    
    final firstUri = uris.first;
    final result = await _avTransportService.addToQueue(
      uri: firstUri,
      enqueuedUri: firstUri,
      desiredFirstTrackNumberEnqueued: insertPosition,
      enqueueAsNext: asNext,
    );
    
    // Add remaining tracks if there are multiple
    if (uris.length > 1) {
      for (int i = 1; i < uris.length; i++) {
        await _avTransportService.addToQueue(
          uri: uris[i],
          enqueuedUri: uris[i],
          desiredFirstTrackNumberEnqueued: insertPosition + i,
          enqueueAsNext: false,
        );
      }
    }

    final firstTrack = int.tryParse(result['FirstTrackNumberEnqueued'] ?? '0') ?? 0;
    return firstTrack;
  }

  /// Remove one or more tracks from the queue
  /// 
  /// [positions] List of track positions to remove (0-based)
  Future<void> removeFromQueue(List<int> positions) async {
    if (positions.isEmpty) return;
    
    // Sort positions in descending order to avoid index shifting issues
    positions.sort((a, b) => b.compareTo(a));
    
    for (final position in positions) {
      await _avTransportService.removeTrackFromQueue(
        objectID: 'Q:0',
        updateID: 0,
        trackNumber: position + 1, // Convert to 1-based index for Sonos API
      );
    }
  }

  /// Clear all tracks from the queue
  Future<void> clearQueue() async {
    await _avTransportService.removeAllTracksFromQueue();
  }
  
  /// Parse XML response from queue browsing
  List<Track> _parseQueueXml(String xml) {
    final List<Track> tracks = [];
    
    // Basic XML parsing - could be improved with a proper XML parser
    final itemRegex = RegExp(r'<item id="Q:0/(\d+)".*?>(.*?)</item>', dotAll: true);
    final matches = itemRegex.allMatches(xml);
    
    for (final match in matches) {
      final queuePosition = int.tryParse(match.group(1) ?? '0') ?? 0;
      final itemXml = match.group(2) ?? '';
      
      final titleMatch = RegExp(r'<dc:title>(.*?)</dc:title>').firstMatch(itemXml);
      final creatorMatch = RegExp(r'<dc:creator>(.*?)</dc:creator>').firstMatch(itemXml);
      final albumMatch = RegExp(r'<upnp:album>(.*?)</upnp:album>').firstMatch(itemXml);
      final albumArtUriMatch = RegExp(r'<upnp:albumArtURI>(.*?)</upnp:albumArtURI>').firstMatch(itemXml);
      final resMatch = RegExp(r'<res[^>]*>(.*?)</res>').firstMatch(itemXml);
      
      tracks.add(Track(
        title: titleMatch?.group(1) ?? 'Unknown',
        artist: creatorMatch?.group(1) ?? 'Unknown',
        album: albumMatch?.group(1) ?? '',
        albumArtUri: albumArtUriMatch?.group(1) ?? '',
        uri: resMatch?.group(1) ?? '',
        queuePosition: queuePosition,
      ));
    }
    
    return tracks;
  }

  /// Play a specific track in the queue by position
  Future<void> playTrack(int position) async {
    await _avTransportService.seek(
      unit: 'TRACK_NR',
      target: (position + 1).toString(), // Convert to 1-based index
    );
    await _avTransportService.play();
  }
}