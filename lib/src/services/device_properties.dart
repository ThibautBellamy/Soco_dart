import 'package:soco_dart/src/utils/utils.dart';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:convert';
import 'soap_service.dart';

/// Service pour gérer les propriétés des appareils Sonos
/// Implémente les fonctions présentes dans SoCo Python
class DeviceProperties {
  /// Service SOAP sous-jacent
  final SoapService _soapService;
  final String ipAddress;

  DeviceProperties(this.ipAddress)
      : _soapService = SoapService(
          baseUrl: "http://$ipAddress:1400", 
          controlURL: '/DeviceProperties/Control',
          serviceType: 'urn:schemas-upnp-org:service:DeviceProperties:1',
        );

  /// Récupère le nom de la zone (pièce)
  Future<String> getZoneName() async {
    final response = await _soapService.call('GetZoneAttributes', {});
    return response['CurrentZoneName'] ?? '';
  }

  /// Définit le nom de la zone (pièce)
  Future<void> setZoneName(String name) async {
    await _soapService.call('SetZoneAttributes', {
      'DesiredZoneName': name,
      'DesiredIcon': '',
      'DesiredConfiguration': '',
    });
  }

  /// Récupère l'état de la LED
  Future<bool> getLEDState() async {
    final response = await _soapService.call('GetLEDState', {});
    return response['CurrentLEDState'] == 'On';
  }

  /// Définit l'état de la LED
  Future<void> setLEDState(bool on) async {
    await _soapService.call('SetLEDState', {
      'DesiredLEDState': on ? 'On' : 'Off',
    });
  }

  /// Vérifie si les boutons sont verrouillés
  Future<bool> getButtonLockState() async {
    final response = await _soapService.call('GetButtonLockState', {});
    return response['CurrentButtonLockState'] == 'On';
  }

  /// Verrouille ou déverrouille les boutons de l'appareil
  Future<void> setButtonLockState(bool locked) async {
    await _soapService.call('SetButtonLockState', {
      'DesiredButtonLockState': locked ? 'On' : 'Off',
    });
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final parsedXml = await _getXmlDocument('/xml/device_description.xml');
      final deviceInfo = <String, dynamic>{};

      // Extraction des informations principales
      deviceInfo['zone_name'] = _findElementText(parsedXml, 'roomName');
      deviceInfo['player_icon'] = _findElementText(parsedXml, 'icon/url');
      deviceInfo['serial_number'] = _findElementText(parsedXml, 'serialNum');
      deviceInfo['software_version'] = _findElementText(parsedXml, 'softwareVersion');
      deviceInfo['hardware_version'] = _findElementText(parsedXml, 'hardwareVersion');
      deviceInfo['model_number'] = _findElementText(parsedXml, 'modelNumber');
      deviceInfo['model_name'] = _findElementText(parsedXml, 'modelName');
      deviceInfo['display_version'] = _findElementText(parsedXml, 'displayVersion');
      deviceInfo['UDN'] = _findElementText(parsedXml, 'UDN');
      deviceInfo['householdID'] = _findElementText(parsedXml, 'householdID');

      // Extraire l'adresse MAC du numéro de série
      if (deviceInfo['serial_number'] != null) {
        final mac = deviceInfo['serial_number'].split(':')[0];
        deviceInfo['mac_address'] = mac;
      }

      return deviceInfo;
    } catch (e) {
      myPrint('Erreur lors de la récupération des infos de l\'appareil: $e');
      return {};
    }
  }

  // Méthode utilitaire pour extraire du texte d'un élément XML
  String? _findElementText(xml.XmlDocument document, String elementName) {
    try {
      for (var node in document.findAllElements(elementName)) {
        final text = node.text;
        // Correction de l'encodage pour les caractères spéciaux
        if (text.isNotEmpty) {
          try {
            // Décode proprement les caractères UTF-8 qui pourraient être mal encodés
            return utf8.decode(text.codeUnits);
          } catch (e) {
            // Si l'encodage UTF-8 échoue, essayer avec latin1
            return utf8.decode(latin1.encode(text));
          }
        }
        return text;
      }
    } catch (e) {
      myPrint('Élément non trouvé ou problème d\'encodage: $elementName - $e');
    }
    return null;
  }

  Future<xml.XmlDocument> _getXmlDocument(String path) async {
    final url = Uri.parse('http://$ipAddress:1400$path');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'text/xml; charset=utf-8'},
    );

    if (response.statusCode != 200) {
      throw Exception('XML request failed: ${response.statusCode}');
    }

    return xml.XmlDocument.parse(response.body);
  }
}
