import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

final _picker = ImagePicker();
final _geocoding = Geocoding();

/// `PhotosPicker` for one image, re-encoded as JPEG at ~0.8 quality like
/// `jpegData(compressionQuality: 0.8)`.
Future<Uint8List?> pickImage() async {
  final file =
      await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
  return file?.readAsBytes();
}

/// `PhotosPicker(maxSelectionCount: 10)`.
Future<List<Uint8List>> pickImages({int limit = 10}) async {
  final files = await _picker.pickMultiImage(imageQuality: 80, limit: limit);
  return Future.wait(files.map((f) => f.readAsBytes()));
}

/// `.fileImporter(allowedContentTypes: [.pdf, .image])`.
Future<File?> pickDocument() async {
  final picked = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
  );
  final path = picked?.path;
  return path == null ? null : File(path);
}

/// `CLGeocoder().geocodeAddressString`, via the platform geocoder.
Future<({double lat, double lng})> geocode(String address) async {
  final results = await _geocoding.locationFromAddress(address);
  if (results.isEmpty) {
    throw Exception('Could not find a location for "$address".');
  }
  return (lat: results.first.latitude, lng: results.first.longitude);
}

/// `SFSafariViewController` / `openURL` for documents.
Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}

/// `MKMapItem.openInMaps` with driving directions; Google Maps on Android.
Future<void> openDirections(double lat, double lng, String name) async {
  final uri = Platform.isIOS
      ? Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d'
          '&q=${Uri.encodeComponent(name)}')
      : Uri.parse('https://www.google.com/maps/dir/?api=1'
          '&destination=$lat,$lng&travelmode=driving');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
