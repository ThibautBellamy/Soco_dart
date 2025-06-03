# SoCo Dart - Sonos Controller for Flutter

A Flutter library to control Sonos speakers, inspired by the Python SoCo library.

## Features

- Discovery of Sonos speakers on the local network
- Playback controls (play, pause, next, previous)
- Volume and audio settings management
- Playlist and queue management
- Information about currently playing tracks
- Microphone streaming to Sonos speakers
- Speaker state saving and restoration

## Installation

```yaml
dependencies:
  soco_flutter: ^0.1.0
```

## Usage

```dart
import 'package:soco_flutter/soco_flutter.dart';

void main() async {
  // Initialize the discovery service
  final sonosDiscovery = SonosDiscovery();
  
  // Discover Sonos speakers on the network
  final speakers = await sonosDiscovery.startDiscovery(Duration(seconds: 5));
  
  if (speakers.isNotEmpty) {
    // Select the first speaker found
    final speaker = speakers.first;
    
    // Get speaker info
    print('Connected to: ${speaker.playerName}');
    
    // Control playback
    await speaker.play();
    await speaker.setVolume(50);
    
    // Get information about the current track
    final track = await speaker.getCurrentTrackInfo();
    print('Now playing: ${track.title} by ${track.artist}');
    
    // Stream microphone to speaker (example)
    final micService = MicrophoneStreamService();
    await micService.initialize();
    final streamUrl = await micService.startStreaming(speaker);
    print('Streaming from microphone: $streamUrl');
    
    // Later, stop streaming and restore previous state
    await micService.stopStreaming();
  }
}
```

## Project Structure

- `lib/src/models/`: Data models (speaker, track, etc.)
- `lib/src/services/`: SOAP/UPnP services for communication
- `lib/src/discovery.dart`: Device discovery
- `lib/src/utils/`: Helper utilities

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

# SoCo Flutter - Sonos Controller for Flutter

Une bibliothèque Flutter pour contrôler les enceintes Sonos, inspirée par la bibliothèque Python SoCo.

## Fonctionnalités

- Découverte des enceintes Sonos sur le réseau local
- Contrôle de lecture (play, pause, next, previous)
- Gestion du volume et des paramètres audio
- Gestion des playlists et des files d'attente
- Informations sur les pistes en cours de lecture
- Streaming du microphone vers les enceintes Sonos
- Sauvegarde et restauration de l'état des enceintes

## Installation

```yaml
dependencies:
  soco_flutter: ^0.1.0
```

## Utilisation

```dart
import 'package:soco_flutter/soco_flutter.dart';

void main() async {
  // Initialiser le service de découverte
  final sonosDiscovery = SonosDiscovery();
  
  // Découvrir les enceintes Sonos sur le réseau
  final speakers = await sonosDiscovery.startDiscovery(Duration(seconds: 5));
  
  if (speakers.isNotEmpty) {
    // Sélectionner la première enceinte trouvée
    final speaker = speakers.first;
    
    // Obtenir les informations sur l'enceinte
    print('Connecté à: ${speaker.playerName}');
    
    // Contrôler la lecture
    await speaker.play();
    await speaker.setVolume(50);
    
    // Obtenir des informations sur la piste en cours
    final track = await speaker.getCurrentTrackInfo();
    print('En cours de lecture: ${track.title} par ${track.artist}');
    
    // Streaming du microphone vers l'enceinte (exemple)
    final micService = MicrophoneStreamService();
    await micService.initialize();
    final streamUrl = await micService.startStreaming(speaker);
    print('Streaming depuis le microphone: $streamUrl');
    
    // Plus tard, arrêter le streaming et restaurer l'état précédent
    await micService.stopStreaming();
  }
}
```

## Structure du projet

- `lib/src/models/`: Modèles de données (speaker, track, etc.)
- `lib/src/services/`: Services SOAP/UPnP pour la communication
- `lib/src/discovery.dart`: Découverte des appareils
- `lib/src/utils/`: Utilitaires

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou à soumettre une pull request.



