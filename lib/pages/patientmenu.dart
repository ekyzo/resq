// ignore_for_file: prefer_const_constructors, sort_child_properties_last, prefer_const_literals_to_create_immutables, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:resq/pages/drivermenu.dart';
import 'package:resq/pages/orderform.dart';
import 'package:logging/logging.dart';
import 'package:resq/pages/patientordersummary.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientMenu extends StatefulWidget {
  const PatientMenu({super.key});

  @override
  State<PatientMenu> createState() => _PatientMenuState();
}

class _PatientMenuState extends State<PatientMenu> {
  final Logger _logger = Logger('PatientMenu');
  final user = FirebaseAuth.instance.currentUser!;
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  LatLng? _currentLocation;
  LatLng? _driverLocation;
  bool _orderInProgress = false;
  String? _currentOrderId;
  String? _driverName;
  String? _driverPhone;
  String? _orderStatus;
  bool _driverPickedUp = false;
  String? _imageUrl;

  String? _estimatedTime;
  Set<Polyline> _polylines = {};
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  StreamSubscription<DocumentSnapshot>? _orderDocSubscription;
  final String _apiKey = 'AIzaSyCTG6j7tIvQrts8ZJ0eHQ8dJ4BzwHftxPg';

  @override
  void initState() {
    super.initState();
    _addMarkers();
    _getCurrentLocation();
    _subscribeToUserDoc();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    _orderDocSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _requestLocationPermission() async {
    final LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _getCurrentLocation() async {
    final bool permissionGranted = await _requestLocationPermission();
    if (!permissionGranted) {
      _showSnackBar('Location permission not granted.', Colors.red);
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _markers.add(
            Marker(
              markerId: MarkerId('current_location'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: InfoWindow(
                title: 'You are here',
                snippet: '${position.latitude}, ${position.longitude}',
              ),
            ),
          );
          mapController?.moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              14.8,
            ),
          );
          _sendLocationToFirebase(position);
        });
      }
    } catch (e) {
      _showSnackBar('Failed to get current location.', Colors.red);
      _logger.severe('Failed to get current location: $e');
    }
  }

  void _sendLocationToFirebase(Position position) {
    FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'location': GeoPoint(position.latitude, position.longitude),
    }, SetOptions(merge: true)).then((value) {
      _logger.info("Location Added");
    }).catchError((error) {
      _logger.severe("Failed to add location: $error");
    });
  }

  void _subscribeToUserDoc() {
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _orderInProgress = data['orderInProgress'] ?? false;
          _currentOrderId = data['orderId'];
        });
        if (_currentOrderId != null) {
          _subscribeToOrderDoc(_currentOrderId!);
        }
      }
    });
  }

  void _subscribeToOrderDoc(String orderId) {
    _orderDocSubscription?.cancel();
    _orderDocSubscription = FirebaseFirestore.instance
        .collection('order')
        .doc(orderId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final driverLocation = data['driverLocation'] as GeoPoint?;
        final orderStatus = data['status'];
        final driverPickedUp = data['driverPickedUp'] ?? false; // New field
        final driverId = data['driverId'];
        final routePoints = data['routePoints'];
        final estimatedTime = data['estimatedTime']; // Retrieve the ETA
        final String? imageUrl = data['imageUrl'];

        setState(() {
          _orderStatus = orderStatus;
          _estimatedTime = estimatedTime; // Set the ETA
          _driverPickedUp = driverPickedUp; // Update local state
          _imageUrl = imageUrl;
        });

        if (driverLocation != null) {
          setState(() {
            _driverLocation =
                LatLng(driverLocation.latitude, driverLocation.longitude);
            // Clear previous driver marker and add updated marker
            _markers.removeWhere(
                (marker) => marker.markerId.value == 'driver_location');
            _markers.add(
              Marker(
                markerId: MarkerId('driver_location'),
                position: _driverLocation!,
                infoWindow: InfoWindow(
                  title: 'Driver Location',
                  snippet: 'Your driver is here',
                ),
              ),
            );
          });

          // Draw route if order is accepted and routePoints are available
          if (orderStatus == 'accepted') {
            if (routePoints != null) {
              // Decode and draw the saved polyline
              final decodedPoints = _decodePolyline(routePoints);
              setState(() {
                _polylines = {
                  Polyline(
                    polylineId: PolylineId('route'),
                    points: decodedPoints,
                    color: Colors.blue,
                    width: 5,
                  ),
                };
              });
            } else {
              _drawRoute();
            }
            _fetchDriverDetails(driverId);
          } else {
            // Clear polylines if the order is not accepted
            setState(() {
              _polylines = {};
              _driverName = null;
              _driverPhone = null;
            });
          }

          // Draw route with updated driver location
          if (orderStatus == 'accepted') {
            _drawRoute();
          }
        }
        if (orderStatus == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PatientOrderSummary(orderId: orderId),
              ),
            );
          });
        }
      }
    });
  }

  void _fetchDriverDetails(String driverId) async {
    if (_currentOrderId == null) return;

    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('order')
          .doc(_currentOrderId)
          .get();
      if (orderDoc.exists && orderDoc.data() != null) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        setState(() {
          _driverName = orderData['driverName'];
          _driverPhone = orderData['driverPhone'];
        });
        _logger.info('Driver name: $_driverName');
        _logger.info('Driver phone: $_driverPhone');
      }
    } catch (e) {
      _showSnackBar('Failed to fetch driver details.', Colors.red);
      _logger.severe('Error fetching driver details: $e');
    }
  }

  void _drawRoute() async {
    if (_driverLocation == null || _currentLocation == null) return;

    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_driverLocation!.latitude},${_driverLocation!.longitude}&destination=${_currentLocation!.latitude},${_currentLocation!.longitude}&key=$_apiKey';

    _logger.info('Fetching route from URL: $url');

    final http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _logger.info('Directions API response: $data');

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final points = data['routes'][0]['overview_polyline']['points'];
        final routePoints = _decodePolyline(points);

        // Extracting the duration
        final duration = data['routes'][0]['legs'][0]['duration']['text'];

        setState(() {
          _polylines = {
            Polyline(
              polylineId: PolylineId('route'),
              points: routePoints,
              color: Colors.blue,
              width: 5,
            ),
          };
          _estimatedTime = duration;
          _logger.info('Route drawn: $routePoints');
          _logger.info('Estimated time of arrival: $_estimatedTime');
        });

        // Save the polyline points and ETA to Firestore
        if (_currentOrderId != null) {
          FirebaseFirestore.instance
              .collection('order')
              .doc(_currentOrderId)
              .update({
            'routePoints': points,
            'estimatedTime': duration, // Save the ETA
          });
        }
      } else {
        _logger.info('No routes found');
      }
    } else {
      _logger.severe('Failed to load route: ${response.statusCode}');
      throw Exception('Failed to load route');
    }
  }

  List<LatLng> _decodePolyline(String poly) {
    List<LatLng> points = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng((lat / 1E5), (lng / 1E5)));
    }

    return points;
  }

  void _cancelOrder() async {
    try {
      _logger.info('Attempting to cancel order...');

      // Cancel the order document subscription if it exists
      if (_orderDocSubscription != null) {
        await _orderDocSubscription!.cancel();
        _logger.info('Order document subscription cancelled.');
      }

      // Check if an order is in progress
      if (_orderInProgress) {
        // Fetch the user's document from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          final String? orderId = data['orderId'];

          _logger.info('Order ID: $orderId');

          // Update order status to 'Canceled'
          if (orderId != null) {
            final orderDoc = await FirebaseFirestore.instance
                .collection('order')
                .doc(orderId)
                .get();
            if (orderDoc.exists && orderDoc.data() != null) {
              final orderData = orderDoc.data() as Map<String, dynamic>;

              // Get the image path or URL from the order data
              final String? imageUrl = orderData['imageUrl'];

              // Delete the image from Firebase Storage if it exists
              if (imageUrl != null) {
                try {
                  final ref = FirebaseStorage.instance.refFromURL(imageUrl);
                  await ref.delete();
                  _logger.info('Image deleted from Firebase Storage.');
                } catch (e) {
                  _logger.severe('Failed to delete image: $e');
                }
              }

              // Delete the order document from 'order' collection
              await FirebaseFirestore.instance
                  .collection('order')
                  .doc(orderId)
                  .delete();
              _logger.info('Order document moved to history and deleted.');

              // Update the user's document to reflect that the order is no longer in progress
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'orderInProgress': false,
                'orderId': null,
              });
              _logger.info('User document updated.');

              // Update the local state to reflect the cancellation
              if (mounted) {
                setState(() {
                  _orderInProgress = false;
                  _currentOrderId = null;
                  _driverLocation = null;
                  _driverName = null;
                  _driverPhone = null;
                  _estimatedTime = null;
                  _markers.removeWhere(
                      (marker) => marker.markerId.value == 'driver_location');
                  _polylines =
                      {}; // Clear polylines when the order is cancelled
                });
              }

              _logger.info('Order cancelled successfully.');
              _showSnackBar('Order cancelled.', Colors.green);
            } else {
              _logger.warning('Order document not found.');
              _showSnackBar(
                  'Failed to cancel order: Order not found.', Colors.red);
            }
          } else {
            _logger.warning('Order ID not found in user document.');
            _showSnackBar(
                'Failed to cancel order: Order ID not found.', Colors.red);
          }
        } else {
          _logger.warning('User document does not exist or has no data.');
          _showSnackBar(
              'Failed to cancel order: User document not found.', Colors.red);
        }
      }
    } catch (e) {
      _logger.severe('Failed to cancel order: $e');
      _showSnackBar('Failed to cancel order.', Colors.red);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _addMarkers() {
    _markers.add(
      Marker(
        markerId: MarkerId('default_marker'),
        position: LatLng(37.7749, -122.4194),
        infoWindow: InfoWindow(
          title: 'Default Location',
          snippet: 'San Francisco, CA',
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
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
        if (await launch(url.toString())) {
          // Call launched successfully
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
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? LatLng(0, 0),
              zoom: 12,
            ),
            markers: _markers,
            polylines: _polylines,
          ),
          if (_orderInProgress)
            Positioned(
              bottom: 10.0,
              left: 10.0,
              right: 10.0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3), //position of shadow
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Order Status:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    if (_orderStatus != null)
                      Center(
                        child: Text(
                          '$_orderStatus'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            color: Color.fromARGB(255, 138, 1, 1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 5,
                    ),
                    if (!_driverPickedUp && _estimatedTime != null)
                      Center(
                        child: Text(
                          'Estimated Time of Arrival: $_estimatedTime',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    if (_driverName != null && _driverPhone != null)
                      Divider(
                        color: Colors.grey,
                      ),
                    if (_driverName != null && _driverPhone != null)
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 5),
                              Text(
                                'Driver Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Name: $_driverName',
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Phone: $_driverPhone',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          Spacer(), // Add a spacer to push the call button to the end
                          if (_orderStatus == 'accepted')
                            IconButton(
                              icon: Icon(Icons.call),
                              color: Colors.green,
                              onPressed: () {
                                if (_driverPhone != null) {
                                  print('Launching call to $_driverPhone');
                                  _launchCaller(_driverPhone!);
                                } else {
                                  print('Driver phone number is null.');
                                  _showSnackBar(
                                      'Driver phone number not available.',
                                      Colors.red);
                                }
                              },
                            ),
                          if (_imageUrl != null)
                            IconButton(
                              icon: Icon(Icons.image),
                              color: Colors.blue[700],
                              onPressed: () {
                                _showImageDialog(
                                    _imageUrl!); // Show image in a dialog
                              },
                            ),
                        ],
                      ),
                    if (!_driverPickedUp) SizedBox(height: 15),
                    if (!_driverPickedUp) // Conditionally render the button
                      Center(
                        child: ElevatedButton(
                          onPressed: _cancelOrder,
                          child: Text(
                            'CANCEL ORDER',
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
          if (!_orderInProgress)
            Positioned(
              bottom: 24.0,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentLocation != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MyOrderForm(location: _currentLocation!),
                        ),
                      ).then((_) => _subscribeToUserDoc());
                    } else {
                      _showSnackBar(
                          'Current location not available.', Colors.red);
                    }
                  },
                  child: Text(
                    'MAKE ORDER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 138, 1, 1),
                    padding: EdgeInsets.symmetric(
                      horizontal: 75,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
