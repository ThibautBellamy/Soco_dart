import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soco_dart/soco_dart.dart';
import 'speaker_detail_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SonosExampleApp(),
    ),
  );
}

// Provider pour découvrir les appareils Sonos
final deviceDiscoveryProvider = FutureProvider<List<Speaker>>((ref) async {
  final discovery = SonosDiscovery();
  return await discovery.startDiscovery(const Duration(seconds: 5));
});

// Provider pour gérer l'état d'un appareil spécifique
final speakerProvider = StateNotifierProvider.family<SpeakerNotifier, SpeakerState, Speaker>(
  (ref, speaker) => SpeakerNotifier(speaker),
);

class SonosExampleApp extends ConsumerWidget {
  const SonosExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceDiscovery = ref.watch(deviceDiscoveryProvider);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SoCo Flutter Example')),
        body: deviceDiscovery.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (devices) {
            if (devices.isEmpty) {
              return const Center(child: Text('No devices found'));
            }

            return ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ProviderScope(
                  overrides: [
                    speakerProvider.overrideWith((ref, speaker) => SpeakerNotifier(speaker)),
                  ],
                  child: SpeakerTile(device: device),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => ref.refresh(deviceDiscoveryProvider),
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

class SpeakerTile extends ConsumerWidget {
  final Speaker device;

  const SpeakerTile({super.key, required this.device});

  void showVolumeSliderOverlay(BuildContext context, WidgetRef ref) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Consumer(builder: (context, ref, _) {
          final speakerState = ref.watch(speakerProvider(device));
          return Positioned(
            left: position.dx + renderBox.size.width - 250, // Ajuste selon besoin
            top: position.dy + renderBox.size.height, // Juste sous le bouton
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                width: 200,
                height: 30,
                child: Slider(
                  min: 0,
                  max: 100,
                  value: speakerState.volume.toDouble(),
                  onChanged: (value) {
                    ref.read(speakerProvider(device).notifier).setVolume(value.toInt());
                  },
                ),
              ),
            ),
          );
        });
      },
    );

    overlay.insert(overlayEntry);

    // Fermer l'overlay si on clique ailleurs
    Future.delayed(const Duration(seconds: 10), () {
      overlayEntry?.remove();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakerState = ref.watch(speakerProvider(device));

    return MouseRegion(
      onEnter: (_) => ref.read(speakerProvider(device).notifier).setHovering(true),
      onExit: (_) => ref.read(speakerProvider(device).notifier).setHovering(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: speakerState.isHovering ? Colors.grey.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          // boxShadow: speakerState.isHovering ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: ListTile(
          title: Text(device.playerName ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('IP: ${device.ipAddress}'), Text('${device.currentTrack?.title} - ${device.currentTrack?.artist}', style: const TextStyle(fontStyle: FontStyle.italic))],
          ),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => ProviderScope(
                  overrides: [
                    speakerProvider(device).overrideWith((ref) => SpeakerNotifier(device)),
                  ],
                  child: SpeakerDetailPage(device: device),
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(position: offsetAnimation, child: child);
                },
              ),
            );
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contrôles basiques toujours visibles
              IconButton(
                icon: Icon(speakerState.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  ref.read(speakerProvider(device).notifier).togglePlayPause();
                },
              ),

              // Contrôles avancés visibles uniquement au survol
              if (speakerState.isHovering) ...[
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => device.previousTrack(),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => device.nextTrack(),
                ),
              ],

              // Contrôle du volume toujours visible
              TextButton.icon(
                icon: const Icon(Icons.volume_up),
                label: Text(speakerState.volume.toString()),
                onPressed: () {
                  // showVolumeSliderOverlay(context, ref);
                },
              ),
              if (speakerState.isHovering) ...[
                Slider(
                  min: 0,
                  max: 100,
                  value: speakerState.volume.toDouble(),
                  onChanged: (value) {
                    ref.read(speakerProvider(device).notifier).setVolume(value.toInt());
                  },
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// Modèle pour l'état d'un appareil
class SpeakerState {
  final int volume;
  final bool isPlaying;
  final bool isVolumeVisible;
  final bool isHovering; // Ajout de l'état de survol

  SpeakerState({
    required this.volume,
    required this.isPlaying,
    this.isVolumeVisible = true,
    this.isHovering = false, // Par défaut, pas de survol
  });

  SpeakerState copyWith({
    int? volume,
    bool? isPlaying,
    bool? isVolumeVisible,
    bool? isHovering,
  }) {
    return SpeakerState(
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
      isVolumeVisible: isVolumeVisible ?? this.isVolumeVisible,
      isHovering: isHovering ?? this.isHovering,
    );
  }
}

// Notifier pour gérer l'état d'un appareil
class SpeakerNotifier extends StateNotifier<SpeakerState> {
  final Speaker speaker;
  Timer? _refreshTimer;

  SpeakerNotifier(this.speaker) : super(SpeakerState(volume: 50, isPlaying: false)) {
    _initializeState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _initializeState(); // Met à jour l'état toutes les 2 secondes
    });
  }

  Future<void> _initializeState() async {
    try {
      // Récupérer le volume initial depuis l'appareil
      final initialVolume = await speaker.getVolume();
      final isPlaying = await speaker.isPlaying();
      await speaker.getCurrentTrackInfo(); // Met à jour les infos de la piste

      // Mettre à jour l'état avec les valeurs initiales
      state = state.copyWith(volume: initialVolume, isPlaying: isPlaying);
    } catch (e) {
      myPrint('Erreur lors de l\'initialisation de l\'état : $e');
    }
  }

  void setVolume(int newVolume) {
    speaker.setVolume(newVolume);
    state = state.copyWith(volume: newVolume);
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      speaker.pause();
    } else {
      speaker.play();
    }
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void toggleVolumeVisible() {
    // Toggle the visibility of the volume slider
    state = state.copyWith(isVolumeVisible: !state.isVolumeVisible);
  }

  void setHovering(bool isHovering) {
    state = state.copyWith(isHovering: isHovering);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Annuler toutes les autres ressources (streams, etc.)
    super.dispose();
  }
}
