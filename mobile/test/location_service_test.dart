import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:talegaon_fresh/location_service.dart';

void main() {
  test('detected PIN is prefilled, but house address is not fabricated', () {
    final result = addressFromPlacemark(const Placemark(
      subLocality: 'Talegaon Dabhade',
      locality: 'Pune',
      street: 'Pune',
      postalCode: '410507',
    ));
    expect(result.pincode, '410507');
    expect(result.address, isEmpty);
    expect(result.label, contains('Talegaon'));
  });

  test('invalid reverse-geocoder postal code requires manual entry', () {
    final result = addressFromPlacemark(const Placemark(
      locality: 'Talegaon Dabhade',
      postalCode: '411044-1234',
    ));
    expect(result.pincode, isEmpty);
  });
}
