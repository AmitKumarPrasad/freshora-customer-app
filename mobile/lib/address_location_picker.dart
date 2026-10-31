import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class AddressLocationPicker extends StatefulWidget {
  const AddressLocationPicker({super.key, required this.initialLocation});
  final LatLng initialLocation;

  @override
  State<AddressLocationPicker> createState() => _AddressLocationPickerState();
}

class _AddressLocationPickerState extends State<AddressLocationPicker> {
  late LatLng location = widget.initialLocation;
  final mapController = MapController();
  final searchController = TextEditingController();
  bool searching = false;

  @override
  void dispose() {
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = searchController.text.trim();
    if (query.isEmpty || searching) return;
    setState(() => searching = true);
    try {
      final matches = await locationFromAddress(query);
      if (!mounted) return;
      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found. Try another search or choose on the map.')));
      } else {
        final point = LatLng(matches.first.latitude, matches.first.longitude);
        setState(() => location = point);
        mapController.move(point, 16);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search unavailable. Choose a location on the map.')));
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Select delivery location')),
    body: Column(children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Tap the map to select your delivery location.'),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(
        controller: searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => search(),
        decoration: InputDecoration(labelText: 'Search area or building',
          suffixIcon: IconButton(onPressed: searching ? null : search, icon: const Icon(Icons.search))),
      )),
      Expanded(child: FlutterMap(
        mapController: mapController,
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
