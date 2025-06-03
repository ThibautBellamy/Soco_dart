import 'package:soco_dart/src/utils/utils.dart';
import 'package:xml/xml.dart' as xml;

/// Utilitaire pour gérer le parsing XML
class XmlHelper {
  /// Extrait le texte d'un élément XML
  static String? findElementText(xml.XmlDocument document, String elementName) {
    try {
      for (var node in document.findAllElements(elementName)) {
        return node.text;
      }
    } catch (e) {
      myPrint('Élément non trouvé: $elementName');
    }
    return null;
  }
  
  /// Parse un document XML
  static xml.XmlDocument parseXml(String xmlString) {
    return xml.XmlDocument.parse(xmlString);
  }
}