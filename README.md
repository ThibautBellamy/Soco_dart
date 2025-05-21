# SoCo Flutter - Sonos Controller for Flutter

A Flutter library to control Sonos speakers, inspired by the Python SoCo library.

## Features

- Discovery of Sonos speakers on the local network
- Playback controls (play, pause, next, previous)
- Volume and audio settings management
- Playlist and queue management
- Information about currently playing tracks
- Support for speaker groups

## Installation

```yaml
dependencies:
  soco_flutter: ^0.1.0
```

## Usage

```dart
import 'package:soco_flutter/soco_flutter.dart';

void main() async {
  // Discover Sonos speakers on the network
  final devices = await SocoFlutter.discoverDevices();
  
  // Select the first speaker found
  final speaker = devices.first;
  
  // Control playback
  await speaker.play();
  await speaker.setVolume(50);
  
  // Get information about the current track
  final track = await speaker.getCurrentTrackInfo();
  print('Now playing: ${track.title} by ${track.artist}');
}
```

## Project Structure

- `lib/src/device.dart`: Class representing a Sonos speaker
- `lib/src/discovery.dart`: Device discovery features
- `lib/src/transport.dart`: Playback and transport control
- `lib/src/music_library.dart`: Music library management
- `lib/src/groups.dart`: Speaker group management
- `lib/src/models/`: Data models (track, album, etc.)
- `lib/src/services/`: SOAP/UPnP services for communication

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
- Support pour les groupes d'enceintes

## Installation

```yaml
dependencies:
  soco_flutter: ^0.1.0
```

## Utilisation

```dart
import 'package:soco_flutter/soco_flutter.dart';

void main() async {
  // Découvrir les enceintes Sonos sur le réseau
  final devices = await SocoFlutter.discoverDevices();
  
  // Sélectionner la première enceinte trouvée
  final speaker = devices.first;
  
  // Contrôler la lecture
  await speaker.play();
  await speaker.setVolume(50);
  
  // Obtenir des informations sur la piste en cours
  final track = await speaker.getCurrentTrackInfo();
  print('En cours de lecture: ${track.title} par ${track.artist}');
}
```

## Structure du projet

- `lib/src/device.dart`: Classe représentant une enceinte Sonos
- `lib/src/discovery.dart`: Fonctionnalités de découverte des appareils
- `lib/src/transport.dart`: Contrôle de lecture et transport
- `lib/src/music_library.dart`: Gestion des bibliothèques musicales
- `lib/src/groups.dart`: Gestion des groupes d'enceintes
- `lib/src/models/`: Modèles de données (piste, album, etc.)
- `lib/src/services/`: Services SOAP/UPnP pour la communication

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou à soumettre une pull request.



