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
  final street = (place.street ?? '').trim();
  final rawPostalCode = (place.postalCode ?? '').trim();
  final pincode = RegExp(r'^\d{6}).hasMatch(rawPostalCode) ? rawPostalCode : '';
  final label = [area, city].where((part) => part.isNotEmpty).toSet().join(', ');
  return CurrentLocationAddress(
    label: label.isNotEmpty ? label : street,
    address: street.isNotEmpty ? street : (area.isNotEmpty ? area : city),
    city: city,
    pincode: pincode,
  );
}

/// Resolve GPS coordinates to an address. A missing postal code remains editable.
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

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) return null;

    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isEmpty) return null;
    return addressFromPlacemark(placemarks.first);
  } catch (_) {
    return null;
  }
}

Future<String?> detectCurrentLocationLabel() async =>
    (await detectCurrentLocationAddress())?.label;
).hasMatch(rawPostalCode) ? rawPostalCode : '';
  final label = [area, city].where((part) => part.isNotEmpty).toSet().join(', ');
  return CurrentLocationAddress(
    label: label.isNotEmpty ? label : street,
    address: street.isNotEmpty ? street : (area.isNotEmpty ? area : city),
    city: city,
    pincode: pincode,
  );
}

/// Resolve GPS coordinates to an address. A missing postal code remains editable.
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

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) return null;

    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isEmpty) return null;
    return addressFromPlacemark(placemarks.first);
  } catch (_) {
    return null;
  }
}

Future<String?> detectCurrentLocationLabel() async =>
    (await detectCurrentLocationAddress())?.label;
