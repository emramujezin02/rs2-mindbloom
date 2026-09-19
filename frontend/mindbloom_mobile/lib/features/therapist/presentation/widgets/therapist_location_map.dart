import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const _mapReadyTimeout = Duration(seconds: 8);

  GoogleMapController? _controller;
  bool _isMapReady = false;
  bool _showFallback = false;
  Timer? _mapReadyTimer;

  @override
  void initState() {
    super.initState();
    _startMapReadyTimer();
  }

  @override
  void didUpdateWidget(covariant TherapistLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMapData = oldWidget.mapData;
    final currentMapData = widget.mapData;

    if (oldMapData.latitude != currentMapData.latitude ||
        oldMapData.longitude != currentMapData.longitude ||
        oldMapData.address != currentMapData.address) {
      _isMapReady = false;
      _showFallback = false;
      _startMapReadyTimer();
    }
  }

  LatLng get _therapistPosition {
    return LatLng(widget.mapData.latitude, widget.mapData.longitude);
  }

  void _startMapReadyTimer() {
    _mapReadyTimer?.cancel();

    if (!widget.mapData.hasValidCoordinates) {
      return;
    }

    _mapReadyTimer = Timer(_mapReadyTimeout, () {
      if (!mounted || _isMapReady) {
        return;
      }

      setState(() {
        _showFallback = true;
      });
    });
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

  Future<void> _openExternalNavigation() async {
    if (!widget.mapData.hasValidCoordinates) {
      return;
    }

    final latitude = widget.mapData.latitude;
    final longitude = widget.mapData.longitude;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude',
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigation could not be opened.')),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation could not be opened.')),
      );
    }
  }

  @override
  void dispose() {
    _mapReadyTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mapData.hasValidCoordinates || _showFallback) {
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
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _controller = controller;
                _mapReadyTimer?.cancel();

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
            if (_isMapReady)
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.icon(
                  onPressed: _openExternalNavigation,
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Directions'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
