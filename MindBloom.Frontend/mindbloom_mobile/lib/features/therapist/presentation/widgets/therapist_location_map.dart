import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_map_data.dart';
import 'therapist_map_fallback.dart';

class TherapistLocationMap extends StatefulWidget {
  final TherapistMapData mapData;
  final double height;
  final bool interactive;

  const TherapistLocationMap({
    super.key,
    required this.mapData,
    this.height = 240,
    this.interactive = true,
  });

  @override
  State<TherapistLocationMap> createState() => _TherapistLocationMapState();
}

class _TherapistLocationMapState extends State<TherapistLocationMap> {
  GoogleMapController? _controller;
  bool _isMapReady = false;

  LatLng get _therapistPosition {
    return LatLng(widget.mapData.latitude, widget.mapData.longitude);
  }

  Set<Marker> get _markers {
    return {
      Marker(
        markerId: const MarkerId('therapist-location'),
        position: _therapistPosition,
        infoWindow: InfoWindow(
          title: widget.mapData.therapistName,
          snippet: widget.mapData.address,
        ),
      ),
    };
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mapData.hasValidCoordinates) {
      return TherapistMapFallback(
        address: widget.mapData.address,
        height: widget.height,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _therapistPosition,
                zoom: 15,
              ),
              markers: _markers,
              mapType: MapType.normal,
              zoomControlsEnabled: widget.interactive,
              scrollGesturesEnabled: widget.interactive,
              zoomGesturesEnabled: widget.interactive,
              rotateGesturesEnabled: widget.interactive,
              tiltGesturesEnabled: widget.interactive,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              compassEnabled: widget.interactive,
              mapToolbarEnabled: widget.interactive,
              onMapCreated: (controller) {
                _controller = controller;

                if (!mounted) {
                  return;
                }

                setState(() {
                  _isMapReady = true;
                });
              },
            ),
            if (!_isMapReady)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
