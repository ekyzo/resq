// ignore_for_file: prefer_const_constructors, unused_import, prefer_final_fields, sort_child_properties_last

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:resq/pages/driverhosp.dart';
import 'package:url_launcher/url_launcher.dart';

final Logger _logger = Logger('DriverMap');

class DriverMap extends StatefulWidget {
  final GeoPoint patientLocation;
  final String orderId;

  const DriverMap(
      {super.key, required this.patientLocation, required this.orderId});

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  GoogleMapController? _mapController;
  LatLng? _driverLocation;
  Set<Polyline> _polylines = {};
  final String _apiKey = 'AIzaSyCTG6j7tIvQrts8ZJ0eHQ8dJ4BzwHftxPg';
  late StreamSubscription<DocumentSnapshot> _locationSubscription;
  late StreamSubscription<DocumentSnapshot> _statusSubscription;
  String _patientName = 'Unknown'; // Default value
  String _patientPhone = 'N/A'; // Default value
  String _emergencyType = 'N/A'; // Default value
  double? _distanceToPatient; // Distance in kilometers
  String? _estimatedTime; // Estimated time of arrival
  String? _imageUrl; // Image URL

  @override
  void initState() {
    super.initState();
    _initDriverLocation();
    _subscribeToDriverLocation();
    _fetchPatientDetails();
    _subscribeToOrderStatus(); // Add this line
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    _statusSubscription.cancel(); // Add this line
    super.dispose();
  }

  void _subscribeToOrderStatus() {
    final documentReference =
        FirebaseFirestore.instance.collection('order').doc(widget.orderId);

    _statusSubscription = documentReference.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        // Check if the order status indicates cancellation
        String orderStatus = snapshot['status'];
        if (orderStatus == 'cancelled') {
          // Order is cancelled, show alert dialog and then navigate back
          _showCancellationDialog();
        }
      } else {
        // Document does not exist, show alert dialog and then navigate back
        _showCancellationDialog();
      }
    });
  }

  void _showCancellationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Order Cancelled',
            style: TextStyle(
              fontSize: 22,
            ),
          ),
          content: Text(
            'The order has been cancelled.',
            style: TextStyle(
              fontSize: 14,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.pop(context); // Navigate back to DriverMenu
              },
            ),
          ],
        );
      },
    );
  }

  void _updateDriverLocation(double latitude, double longitude) {
    if (mounted) {
      setState(() {
        _driverLocation = LatLng(latitude, longitude);
        _distanceToPatient = _calculateDistance(
          _driverLocation!,
          LatLng(widget.patientLocation.latitude,
              widget.patientLocation.longitude),
        );
      });
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ) /
        1000; // Convert to kilometers
  }

  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      // Convert to meters if distance is less than 1 km
      final distanceInMeters = (distanceInKm * 1000).toStringAsFixed(0);
      return '$distanceInMeters meters';
    } else {
      // Show distance in kilometers with 2 decimal places
      return '${distanceInKm.toStringAsFixed(2)} km';
    }
  }

  void _initDriverLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateDriverLocation(position.latitude, position.longitude);
      _drawRoute();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get current location.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _subscribeToDriverLocation() {
    final documentReference =
        FirebaseFirestore.instance.collection('order').doc(widget.orderId);

    _locationSubscription = documentReference.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        GeoPoint geoPoint = snapshot['driverLocation'];
        _updateDriverLocation(geoPoint.latitude, geoPoint.longitude);
        _drawRoute();
      }
    });
  }

  void _drawRoute() async {
    if (_driverLocation == null) return;

    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_driverLocation!.latitude},${_driverLocation!.longitude}&destination=${widget.patientLocation.latitude},${widget.patientLocation.longitude}&key=$_apiKey';
    final http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final points = data['routes'][0]['overview_polyline']['points'];
        final routePoints = _decodePolyline(points);
        if (mounted) {
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
            _distanceToPatient = data['routes'][0]['legs'][0]['distance']
                    ['value'] /
                1000; // Convert to kilometers
            _estimatedTime = data['routes'][0]['legs'][0]['duration']['text'];
            _updateCameraBounds();
          });
        }
      }
    } else {
      throw Exception('Failed to load route');
    }
  }

  void _updateCameraBounds() {
    if (_driverLocation == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        _driverLocation!.latitude < widget.patientLocation.latitude
            ? _driverLocation!.latitude
            : widget.patientLocation.latitude,
        _driverLocation!.longitude < widget.patientLocation.longitude
            ? _driverLocation!.longitude
            : widget.patientLocation.longitude,
      ),
      northeast: LatLng(
        _driverLocation!.latitude > widget.patientLocation.latitude
            ? _driverLocation!.latitude
            : widget.patientLocation.latitude,
        _driverLocation!.longitude > widget.patientLocation.longitude
            ? _driverLocation!.longitude
            : widget.patientLocation.longitude,
      ),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  List<LatLng> _decodePolyline(String poly) {
    List<LatLng> points = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _fetchPatientDetails() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.orderId)
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _patientName = data['userName'] ?? 'Unknown';
            _patientPhone = data['userPhone'] ?? 'N/A';
            _emergencyType = data['emergencyType'] ?? 'N/A';
            _imageUrl = snapshot['imageUrl']; // Retrieve the image URL
          });
        }
      }
    } catch (e) {
      _logger.severe('Failed to fetch patient details: $e');
    }
  }

  Future<void> _pickupPatient(String orderId) async {
    await FirebaseFirestore.instance.collection('order').doc(orderId).update({
      'driverPickedUp': true,
      'status': 'patient pickup', // Update the status as well
    });
  }

  void _launchCaller(String phoneNumber) async {
    final PermissionStatus permission = await Permission.phone.status;
    if (!permission.isGranted) {
      final PermissionStatus newStatus = await Permission.phone.request();
      if (!newStatus.isGranted) {
        _showSnackBar('Phone permission not granted.', Colors.red);
        return;
      }
    }

    final validPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri url = Uri(scheme: 'tel', path: validPhoneNumber);

    print('Launching call to URL: $url'); // Debugging line

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        // Fallback to launch using a different method
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          _showSnackBar('Could not launch $url', Colors.red);
          _logger.severe('Could not launch URL: $url');
        }
      }
    } catch (e) {
      _showSnackBar('Error launching call: $e', Colors.red);
      _logger.severe('Error launching call: $e');
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(imageUrl),
              SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 138, 1, 1),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_driverLocation != null) {
                _updateCameraBounds();
              }
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.patientLocation.latitude,
                  widget.patientLocation.longitude),
              zoom: 12,
            ),
            markers: {
              if (_driverLocation != null)
                Marker(
                  markerId: MarkerId('driver'),
                  position: _driverLocation!,
                  infoWindow: InfoWindow(title: 'Driver Location'),
                ),
              Marker(
                markerId: MarkerId('patient'),
                position: LatLng(widget.patientLocation.latitude,
                    widget.patientLocation.longitude),
                infoWindow: InfoWindow(title: 'Patient Location'),
              ),
            },
            polylines: _polylines,
            trafficEnabled: true, // Add this line to enable traffic layer
          ),
          Positioned(
            bottom: 12.0,
            left: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_distanceToPatient != null)
                    Center(
                      child: Text(
                        'DISTANCE: ${formatDistance(_distanceToPatient!)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  if (_estimatedTime != null)
                    Center(
                      child: Text(
                        'ETA: $_estimatedTime',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  Divider(
                    color: Colors.grey,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Name: $_patientName',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Phone: $_patientPhone',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Emergency Type: $_emergencyType',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Spacer(), // Add a spacer to push the call button to the end
                      IconButton(
                        icon: Icon(Icons.call),
                        color: Colors.green,
                        onPressed: () {
                          print('Launching call to $_patientPhone');
                          _launchCaller(_patientPhone);
                        },
                      ),
                      if (_imageUrl != null)
                        IconButton(
                          icon: Icon(Icons.image),
                          color: Colors.blue[700],
                          onPressed: () {
                            _showImageDialog(_imageUrl!);
                          },
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Update the order status and driverPickedUp field in Firestore
                        await _pickupPatient(widget.orderId);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DriverHospMap(orderId: widget.orderId),
                          ),
                        );
                      },
                      child: Text(
                        'PICKUP PATIENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 138, 1, 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 30.0,
            right: 20.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              child: Image.asset(
                'assets/resq_logo.png',
                width: 120,
                height: 45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
