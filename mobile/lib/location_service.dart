import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationAddress {
  const CurrentLocationAddress({
    required this.label,
    required this.address,
    required this.city,
    required this.pincode,
  });

  final String label;
  final String address;
  final String city;
  final String pincode;
}

CurrentLocationAddress addressFromPlacemark(Placemark place) {
  final area = (place.subLocality ?? '').trim();
  final city = (place.locality ?? place.administrativeArea ?? '').trim();
  final rawPostalCode = (place.postalCode ?? '').trim();
  final pincode = RegExp(r'^\d{6}$').hasMatch(rawPostalCode) ? rawPostalCode : '';
  final label = [area, city].where((part) => part.isNotEmpty).toSet().join(', ');
  return CurrentLocationAddress(
    label: label,
    address: '', // GPS cannot confirm the house or flat number.
    city: city,
    pincode: pincode,
  );
}

/// Use fresh GPS only. The customer must enter and confirm house details.
Future<CurrentLocationAddress?> detectCurrentLocationAddress() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (position.accuracy > 100) return null;

    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isEmpty) return null;
    final result = addressFromPlacemark(placemarks.first);
    return result.city.isEmpty ? null : result;
  } catch (_) {
    return null;
  }
}

Future<String?> detectCurrentLocationLabel() async =>
    (await detectCurrentLocationAddress())?.label;
