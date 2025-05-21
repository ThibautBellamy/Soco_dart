import 'dart:async';
import 'dart:io';
import 'package:soco_flutter/src/utils/utils.dart';

import 'models/speaker.dart';

class SonosDiscovery {
  final String multicastAddress = "239.255.255.250";
  final int multicastPort = 1900;
  final String searchTarget = "urn:schemas-upnp-org:device:ZonePlayer:1";

  RawDatagramSocket? _socket;

  String _buildSearchRequest() {
    return ["M-SEARCH * HTTP/1.1", "HOST: $multicastAddress:$multicastPort", "MAN: \"ssdp:discover\"", "MX: 3", "ST: $searchTarget", "", ""].join("\r\n");
  }

  String? _extractHeader(String response, String header) {
    final regex = RegExp("^$header: (.+)\$", multiLine: true, caseSensitive: false);
    final match = regex.firstMatch(response);
    return match?.group(1)?.trim();
  }

  Future<List<Speaker>> startDiscovery(Duration timeout) async {
    myPrint("Démarrage de la découverte Sonos...");
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    var result = <Speaker>[];
    var discoveredIPs = <String>{}; // Set pour éviter les doublons
    for (var interface in interfaces) {
      // Filtrer les interfaces virtuelles (VirtualBox, WSL, Docker...)
      if (interface.name.toLowerCase().contains('virtual') || interface.name.toLowerCase().contains('vmware') || interface.name.toLowerCase().contains('vethernet')) {
        continue;
      }
      try {
        // 1. Augmenter le timeout pour la création du socket
        myPrint("Découverte sur ${interface.name} (${interface.addresses.map((a) => a.address).join(', ')})");
        _socket = await RawDatagramSocket.bind(interface.addresses.first, 0).timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('Socket binding timeout'));
        _socket!.broadcastEnabled = true;
        myPrint("Socket ouvert sur le port ${_socket!.port}");

        // 2. Augmenter le nombre d'essais et leur intervalle
        for (var i = 0; i < 5; i++) {
          if (_socket == null) break;

          myPrint("Envoi de la requête SSDP #${i + 1}");
          final searchRequest = _buildSearchRequest();
          _socket!.send(
            searchRequest.codeUnits,
            InternetAddress(multicastAddress),
            multicastPort,
          );

          // Attendre plus longtemps entre les envois
          if (i < 4) await Future.delayed(const Duration(milliseconds: 300));
        }

        myPrint("En attente de réponses pendant ${timeout.inSeconds} secondes...");
        // Configuration du listener
        _socket!.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram != null) {
              final response = String.fromCharCodes(datagram.data);

              // Vérification plus détaillée
              if (response.contains("ST: $searchTarget") || response.contains("Sonos") || response.contains("ZonePlayer")) {
                final location = _extractHeader(response, "LOCATION");
                final address = datagram.address.address;
                myPrint("Appareil détecté: $address - Location: $location");

                // Éviter les doublons
                if (!discoveredIPs.contains(address)) {
                  discoveredIPs.add(address);
                  var speaker = Speaker(address);
                  result.add(speaker);
                  myPrint("Ajout d'un nouvel appareil Sonos: $address");
                }
              }
            }
          }
        });
        await Future.delayed(timeout);
      } catch (e) {
        myPrint("Erreur lors de la découverte: $e");
      } finally {
        // Nettoyage du socket
        if (_socket != null) {
          myPrint("Fermeture du socket de découverte");
          _socket!.close();
          _socket = null;
        }
      }
    }
    myPrint("Découverte terminée: ${result.length} appareils trouvés");
    return result;
  }
}


