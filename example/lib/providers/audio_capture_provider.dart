import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soco_flutter/soco_flutter.dart';

// États possibles pour le streaming
enum StreamingState {
  idle,
  starting,
  streaming,
  error,
}

// État du provider
class AudioStreamState {
  final StreamingState state;
  final String? errorMessage;

  AudioStreamState({
    this.state = StreamingState.idle,
    this.errorMessage,
  });

  AudioStreamState copyWith({
    StreamingState? state,
    String? errorMessage,
  }) {
    return AudioStreamState(
      state: state ?? this.state,
      errorMessage: state == StreamingState.error ? errorMessage : null,
    );
  }
}

// Notifier pour gérer l'état de streaming
class AudioStreamNotifier extends StateNotifier<AudioStreamState> {
  final MicrophoneStreamService _streamService = MicrophoneStreamService();

  bool _initialized = false;

  AudioStreamNotifier() : super(AudioStreamState());

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _streamService.initialize();
      _initialized = true;
    }
  }

  Future<void> startStreaming(Speaker speaker) async {
    // 1. Vérification explicite des permissions
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        state = state.copyWith(state: StreamingState.error, errorMessage: "Permission microphone refusée");
        return;
      }
    }
    await _ensureInitialized();
    state = state.copyWith(state: StreamingState.starting);

    try {
      // Tester d'abord si Sonos accepte les streams
      // await _streamService.testSonosCompatibility(speaker.ipAddress);

      final streamUrl = await _streamService.startStreaming();
      if (streamUrl != null) {
        final avTransport = AVTransportService(speaker.ipAddress);
        await avTransport.startLiveAudioStream(streamUrl);
        state = state.copyWith(state: StreamingState.streaming);
      } else {
        state = state.copyWith(
          state: StreamingState.error,
          errorMessage: "Impossible de démarrer le stream",
        );
      }
    } catch (e) {
      state = state.copyWith(
        state: StreamingState.error,
        errorMessage: "Erreur: $e",
      );
    }
  }

  Future<void> stopStreaming() async {
    await _streamService.stopStreaming();
    state = state.copyWith(state: StreamingState.idle);
  }

  // @override
  // void dispose() {
  //   _streamService.dispose();
  //   super.dispose();
  // }
}

// Provider pour le streaming audio
final audioStreamProvider = StateNotifierProvider<AudioStreamNotifier, AudioStreamState>(
  (ref) => AudioStreamNotifier(),
);
