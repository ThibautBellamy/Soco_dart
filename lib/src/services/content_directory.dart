import 'package:soco_flutter/src/services/soap_service.dart';

class ContentDirectoryService {
  final SoapService _soapService;

  ContentDirectoryService(String ipAddress)
      : _soapService = SoapService(
          baseUrl: "http://$ipAddress:1400",
          controlURL: '/MediaServer/ContentDirectory/Control',
          serviceType: 'urn:schemas-upnp-org:service:ContentDirectory:1',
        );

  /// Browse content (including queue)
  Future<Map<String, String>> browse({
    required String objectId,
    required String browseFlag,
    required String filter,
    required int startingIndex,
    required int requestedCount,
  }) async {
    return await _soapService.call('Browse', {
      'ObjectID': objectId,
      'BrowseFlag': browseFlag,
      'Filter': filter,
      'StartingIndex': startingIndex.toString(),
      'RequestedCount': requestedCount.toString(),
      'SortCriteria': '',
    });
  }
}