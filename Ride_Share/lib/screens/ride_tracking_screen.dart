import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:ride_share_app/models/ride_model.dart';

class RideTrackingScreen extends StatefulWidget {
  final Ride ride;

  const RideTrackingScreen({super.key, required this.ride});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  // TODO: Implement real-time location tracking using WebSockets.
  // The backend needs to be updated to broadcast the driver's location.
  // Once the backend is ready, this screen can be updated to subscribe to the WebSocket channel
  // and update the driver's marker on the map in real-time.

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  PolylinePoints _polylinePoints = PolylinePoints();

  // Replace with your Google Maps API key
  final String _googleApiKey = "AIzaSyAtgmLxUYXS106jq0oeJNVAmtvDLDc6H_I";

  @override
  void initState() {
    super.initState();
    _getPolyline();
  }

  void _getPolyline() async {
    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      _googleApiKey,
      PointLatLng(widget.ride.origin.latitude, widget.ride.origin.longitude),
      PointLatLng(widget.ride.destination.latitude, widget.ride.destination.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    _addPolyLine();
  }

  _addPolyLine() {
    Polyline polyline = Polyline(
      polylineId: const PolylineId("route"),
      color: Colors.blue,
      points: _polylineCoordinates,
      width: 5,
    );
    setState(() {
      _polylines.add(polyline);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _addMarkers();
    _animateToFitRoute();
  }

  void _addMarkers() {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(widget.ride.origin.latitude, widget.ride.origin.longitude),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.ride.destination.latitude, widget.ride.destination.longitude),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  void _animateToFitRoute() {
    if (_mapController == null || _polylineCoordinates.isEmpty) return;

    LatLngBounds bounds;
    if (widget.ride.origin.latitude > widget.ride.destination.latitude) {
      bounds = LatLngBounds(
        southwest: LatLng(widget.ride.destination.latitude, widget.ride.origin.longitude),
        northeast: LatLng(widget.ride.origin.latitude, widget.ride.destination.longitude),
      );
    } else {
      bounds = LatLngBounds(
        southwest: LatLng(widget.ride.origin.latitude, widget.ride.destination.longitude),
        northeast: LatLng(widget.ride.destination.latitude, widget.ride.origin.longitude),
      );
    }

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Ride'),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.ride.origin.latitude, widget.ride.origin.longitude),
          zoom: 12,
        ),
        markers: _markers,
        polylines: _polylines,
      ),
    );
  }
}
