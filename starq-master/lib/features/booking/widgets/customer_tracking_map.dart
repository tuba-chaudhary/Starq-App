import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:starq_app/core/network/api_client.dart';

class CustomerTrackingMap extends StatefulWidget {
  final String bookingId;
  final double destLat;
  final double destLng;

  const CustomerTrackingMap({
    Key? key,
    required this.bookingId,
    required this.destLat,
    required this.destLng,
  }) : super(key: key);

  @override
  State<CustomerTrackingMap> createState() => _CustomerTrackingMapState();
}

class _CustomerTrackingMapState extends State<CustomerTrackingMap> {
  final ApiClient _apiClient = ApiClient();
  Timer? _timer;
  LatLng? _partnerLoc;
  String _statusMessage = 'Locating partner...';
  DateTime? _lastUpdated;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _fetchPartnerLocation();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchPartnerLocation());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPartnerLocation() async {
    try {
      final response = await _apiClient.get('/bookings/${widget.bookingId}/partner-location');
      final data = response.data;
      if (data['available'] == true) {
        setState(() {
          _partnerLoc = LatLng(data['latitude'], data['longitude']);
          _lastUpdated = DateTime.parse(data['recordedAt']);
          final diff = DateTime.now().difference(_lastUpdated!).inSeconds;
          _statusMessage = 'Partner location updated $diff sec ago';
        });
        if (_mapController != null && _partnerLoc != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(_partnerLoc!));
        }
      } else {
        setState(() {
          _statusMessage = data['message'] ?? 'Partner location temporarily unavailable';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching location';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destLat, widget.destLng),
        infoWindow: const InfoWindow(title: 'Service Location'),
      ),
    };

    if (_partnerLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('partner'),
          position: _partnerLoc!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Partner'),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade200,
          width: double.infinity,
          child: Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _partnerLoc ?? LatLng(widget.destLat, widget.destLng),
              zoom: 14,
            ),
            markers: markers,
            onMapCreated: (controller) => _mapController = controller,
          ),
        ),
      ],
    );
  }
}
