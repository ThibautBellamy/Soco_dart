import 'package:http/http.dart' as http;
import 'package:soco_dart/src/utils/utils.dart';
import 'package:xml/xml.dart' as xml;

class SoapService {
  final String baseUrl;
  final String controlURL;
  final String serviceType;

  SoapService({
    required this.baseUrl,
    required this.controlURL,
    required this.serviceType,
  });

  Future<Map<String, String>> call(String action, Map<String, dynamic> arguments) async {
    final url = Uri.parse('$baseUrl$controlURL');
    final body = _buildSoapRequest(action, arguments);

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPAction': '"$serviceType#$action"',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('SOAP request failed: ${response.statusCode}');
    }

    return _parseSoapResponse(response.body);
  }

  String _buildSoapRequest(String action, Map<String, dynamic> arguments) {
    final buffer = StringBuffer();
    buffer.writeln('<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">');
    buffer.writeln('  <s:Body>');
    buffer.writeln('    <u:$action xmlns:u="$serviceType">');

    arguments.forEach((key, value) {
      buffer.writeln('      <$key>$value</$key>');
    });

    buffer.writeln('    </u:$action>');
    buffer.writeln('  </s:Body>');
    buffer.writeln('</s:Envelope>');

    return buffer.toString();
  }

  Map<String, String> _parseSoapResponse(String responseBody) {
    final result = <String, String>{};
    try {
      final document = xml.XmlDocument.parse(responseBody);
      final elements = document.findAllElements('*');

      for (final element in elements) {
        if (element.name.local != 'Envelope' && element.name.local != 'Body' && element.name.local != 'soapenv:Envelope' && element.name.local != 'soapenv:Body' && element.name.local != 's:Envelope' && element.name.local != 's:Body') {
          final text = element.innerText.trim();
          if (text.isNotEmpty) {
            result[element.name.local] = text;
          }
        }
      }
    } catch (e) {
      myPrint('Error parsing SOAP response: $e');
    }

    return result;
  }

  Future<xml.XmlDocument> getXmlDocument(String path) async {
    final url = Uri.parse('$baseUrl$path');
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
