import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AddressLocationPicker extends StatefulWidget {
  const AddressLocationPicker({super.key, required this.initialLocation});
  final LatLng initialLocation;

  @override
  State<AddressLocationPicker> createState() => _AddressLocationPickerState();
}

class _AddressLocationPickerState extends State<AddressLocationPicker> {
  late LatLng location = widget.initialLocation;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Select delivery location')),
    body: Column(children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Tap the map to select your delivery location.'),
      ),
      Expanded(child: FlutterMap(
        options: MapOptions(
          initialCenter: widget.initialLocation,
          initialZoom: 16,
          onTap: (_, point) => setState(() => location = point),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.amitprasad.freshora.customer'),
          MarkerLayer(markers: [
            Marker(point: location, width: 48, height: 48,
              child: const Icon(Icons.location_pin, size: 46, color: Color(0xFF168447))),
          ]),
          RichAttributionWidget(attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ]),
        ],
      )),
      SafeArea(child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, child: FilledButton(
          onPressed: () => Navigator.pop(context, location),
          child: const Text('Confirm location'),
        )),
      )),
    ]),
  );
}
