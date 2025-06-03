import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soco_dart/soco_dart.dart';

// État de la file d'attente
class QueueState {
  final List<Track> items;
  final bool isLoading;
  final String? errorMessage;
  
  const QueueState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });
  
  QueueState copyWith({
    List<Track>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return QueueState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// Notifier pour gérer la file d'attente
class QueueNotifier extends StateNotifier<QueueState> {
  final Speaker speaker;
  late final SonosQueue _queue;
  
  QueueNotifier(this.speaker) : super(const QueueState(isLoading: true)) {
    _queue = SonosQueue(speaker);
    loadQueue();
  }
  
  Future<void> loadQueue() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final items = await _queue.getQueue();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors du chargement: $e',
      );
    }
  }
  
  Future<void> playTrack(int index) async {
    try {
      await _queue.playTrack(index);
      // Optionnel: mettre à jour l'état après lecture
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de la lecture: $e',
      );
    }
  }
  
  Future<void> clearQueue() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      await _queue.clearQueue();
      state = state.copyWith(items: [], isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors de la suppression: $e',
      );
      // Recharger au cas où pour rester synchronisé
      loadQueue();
    }
  }
  
  Future<void> removeTrack(int index) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      await _queue.removeFromQueue([index]);
      await loadQueue(); // Recharger pour obtenir la liste mise à jour
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors de la suppression: $e',
      );
    }
  }
}

// Provider pour la file d'attente
final queueProvider = StateNotifierProvider.family<QueueNotifier, QueueState, Speaker>(
  (ref, speaker) => QueueNotifier(speaker),
);

class QueuePage extends ConsumerWidget {
  final Speaker speaker;
  
  const QueuePage({Key? key, required this.speaker}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueProvider(speaker));
    
    return Scaffold(
      appBar: AppBar(
        title: Text('File d\'attente - ${speaker.playerName ?? "Sonos"}'),
        actions: [
          // Bouton de rafraîchissement
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.read(queueProvider(speaker).notifier).loadQueue(),
          ),
          // Bouton de vidage (uniquement visible si la liste n'est pas vide)
          if (queueState.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Vider la file d\'attente',
              onPressed: () => ref.read(queueProvider(speaker).notifier).clearQueue(),
            ),
        ],
      ),
      body: queueState.isLoading
        ? const Center(child: CircularProgressIndicator())
        : queueState.errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Une erreur est survenue',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    queueState.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(queueProvider(speaker).notifier).loadQueue(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : queueState.items.isEmpty
            ? const Center(
                child: Text(
                  'La file d\'attente est vide',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: queueState.items.length,
                itemBuilder: (context, index) {
                  final track = queueState.items[index];
                  return Dismissible(
                    key: Key('track-${track.uri}-$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      ref.read(queueProvider(speaker).notifier).removeTrack(index);
                    },
                    child: ListTile(
                      leading: track.albumArtUri != null && track.albumArtUri!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              track.albumArtUri!.startsWith('http') 
                                ? track.albumArtUri! 
                                : 'http://${speaker.ipAddress}:1400${track.albumArtUri}',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.music_note, size: 24, color: Colors.white),
                                ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.music_note, size: 24, color: Colors.white),
                          ),
                      title: Text(
                        track.title ?? 'Sans titre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.artist ?? 'Artiste inconnu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (track.album != null && track.album!.isNotEmpty)
                            Text(
                              track.album!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => ref.read(queueProvider(speaker).notifier).playTrack(index),
                      ),
                      onTap: () => ref.read(queueProvider(speaker).notifier).playTrack(index),
                    ),
                  );
                },
              ),
    );
  }
}