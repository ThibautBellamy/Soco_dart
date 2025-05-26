import 'dart:async';
import 'package:example/queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soco_flutter/soco_flutter.dart';
import 'main.dart';
import 'providers/audio_capture_provider.dart';

// Provider pour suivre la position de lecture actuelle
final trackPositionProvider = StateNotifierProvider.family<TrackPositionNotifier, TrackPositionState, Speaker>(
  (ref, speaker) => TrackPositionNotifier(speaker),
);

// État pour la position de la piste
class TrackPositionState {
  final double currentPosition;
  final double totalDuration;

  TrackPositionState({
    this.currentPosition = 0.0,
    this.totalDuration = 100.0,
  });

  TrackPositionState copyWith({
    double? currentPosition,
    double? totalDuration,
  }) {
    return TrackPositionState(
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}

// StateNotifier pour gérer la position de lecture
class TrackPositionNotifier extends StateNotifier<TrackPositionState> {
  final Speaker speaker;
  Timer? _positionTimer;

  TrackPositionNotifier(this.speaker) : super(TrackPositionState()) {
    _updatePosition();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updatePosition();
    });
  }

  Future<void> _updatePosition() async {
    try {
      final track = speaker.currentTrack;
      if (track != null) {
        final position = _parseTime(track.position);
        final duration = _parseTime(track.duration);

        if (duration > 0) {
          state = state.copyWith(
            currentPosition: position,
            totalDuration: duration,
          );
        }
      }
    } catch (e) {
      myPrint('Erreur lors de la mise à jour de la position: $e');
    }
  }

  double _parseTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return 0;

    try {
      final parts = timeString.split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = int.tryParse(parts[2]) ?? 0;
        return (hours * 3600 + minutes * 60 + seconds).toDouble();
      }
    } catch (e) {
      myPrint('Erreur de parsing de durée: $e');
    }
    return 0;
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    super.dispose();
  }
}

class SpeakerDetailPage extends ConsumerWidget {
  final Speaker device;

  const SpeakerDetailPage({Key? key, required this.device}) : super(key: key);

  String _formatTime(double seconds) {
    final int mins = (seconds / 60).floor();
    final int secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildMicrophoneButton(BuildContext context, WidgetRef ref) {
    final streamState = ref.watch(audioStreamProvider);
    final isStreaming = streamState.state == StreamingState.streaming;
    final isStarting = streamState.state == StreamingState.starting;

    return Column(
      children: [
        // Message d'erreur s'il y en a un
        if (streamState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              streamState.errorMessage!,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),

        // Bouton principal
        FloatingActionButton(
          backgroundColor: isStreaming
              ? Colors.red
              : isStarting
                  ? Colors.orange
                  : Theme.of(context).primaryColor,
          onPressed: isStarting
              ? null // Désactiver pendant l'initialisation
              : () {
                  if (isStreaming) {
                    ref.read(audioStreamProvider.notifier).stopStreaming();
                  } else {
                    ref.read(audioStreamProvider.notifier).startStreaming(device);
                  }
                },
          tooltip: isStreaming
              ? 'Arrêter de parler'
              : isStarting
                  ? 'Démarrage...'
                  : 'Parler au Sonos',
          child: Icon(
            isStreaming
                ? Icons.mic_off
                : isStarting
                    ? Icons.hourglass_bottom
                    : Icons.mic,
            color: Colors.white,
          ),
        ),

        // Texte explicatif sous le bouton
        const SizedBox(height: 8),
        Text(
          isStreaming
              ? 'Streaming en direct...'
              : isStarting
                  ? 'Initialisation...'
                  : 'Parler au Sonos',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakerState = ref.watch(speakerProvider(device));
    final trackPosition = ref.watch(trackPositionProvider(device));
    final track = device.currentTrack;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.playerName ?? 'Lecteur Sonos'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image de l'album
                if (track?.albumArt != null && track!.albumArt!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      track.albumArt!,
                      height: 200,
                      // width: 280,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        // width: 280,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.music_note, size: 80, color: Colors.white),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 280,
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.music_note, size: 80, color: Colors.white),
                  ),

                const SizedBox(height: 15),

                // Informations sur la piste
                Text(
                  track?.title ?? 'Pas de titre',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  track?.artist ?? 'Artiste inconnu',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 4),
                Text(
                  track?.album ?? 'Album inconnu',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  textAlign: TextAlign.left,
                ),

                const SizedBox(height: 15),

                // Barre de progression avec Riverpod
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.0),
                  child: Column(
                    children: [
                      Slider(
                        min: 0,
                        max: trackPosition.totalDuration,
                        value: trackPosition.currentPosition.clamp(0, trackPosition.totalDuration),
                        onChanged: (value) {
                          // Fonctionnalité à implémenter si vous voulez naviguer dans la piste
                          // Cela nécessite une implémentation de SOAP pour SeekTime
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatTime(trackPosition.currentPosition)),
                            Text(_formatTime(trackPosition.totalDuration)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Contrôles de lecture
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 40),
                      onPressed: () async {
                        await device.previousTrack();
                        await device.getCurrentTrackInfo();
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: Icon(
                        speakerState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        size: 72,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        ref.read(speakerProvider(device).notifier).togglePlayPause();
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 40),
                      onPressed: () async {
                        await device.nextTrack();
                        await device.getCurrentTrackInfo();
                      },
                    ),

                    // Bouton pour afficher la file d'attente
                    IconButton(
                      icon: const Icon(Icons.queue_music),
                      tooltip: 'Voir la file d\'attente',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => QueuePage(speaker: device),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                _buildMicrophoneButton(context, ref),

                const SizedBox(height: 10),

                // Contrôle du volume avec Riverpod
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.volume_down),
                        onPressed: () {
                          ref.read(speakerProvider(device).notifier).setVolume(speakerState.volume.toInt() - 1);
                        }, 
                      ),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: 100,
                          value: speakerState.volume.toDouble(),
                          onChanged: (value) {
                            ref.read(speakerProvider(device).notifier).setVolume(value.toInt());
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: () {
                          ref.read(speakerProvider(device).notifier).setVolume(speakerState.volume.toInt() + 1);
                        }, 
                      ),
                      Text(
                        '${speakerState.volume}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
