import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resq/pages/ordersummary.dart';

class DriverRouteMap extends StatefulWidget {
  final LatLng initialDriverLocation;
  final String orderId;

  const DriverRouteMap({
    Key? key,
    required this.initialDriverLocation,
    required this.orderId,
  }) : super(key: key);

  @override
  _DriverRouteMapState createState() => _DriverRouteMapState();
}

class _DriverRouteMapState extends State<DriverRouteMap> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  final String _apiKey = 'AIzaSyCTG6j7tIvQrts8ZJ0eHQ8dJ4BzwHftxPg';
  LatLng _driverLocation = LatLng(0, 0);
  LatLng? _hospitalLocation;
  String? _hospitalName;
  String? _patientName;
  String? _driverName;
  String? _distance;
  String? _duration;

  @override
  void initState() {
    super.initState();
    _driverLocation = widget.initialDriverLocation;
    _fetchHospitalDetails();
    _subscribeToLocationUpdates();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _fetchHospitalDetails() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.orderId)
          .get();

      if (document.exists) {
        Map<String, dynamic> data = document.data() as Map<String, dynamic>;
        Map<String, dynamic> hospital = data['selectedHospital'];
        LatLng hospitalLocation = LatLng(
          hospital['location'].latitude,
          hospital['location'].longitude,
        );
        String hospitalName = hospital['name'];
        String patientName = data['userName'];
        String driverName = data['driverName'];

        setState(() {
          _hospitalLocation = hospitalLocation;
          _hospitalName = hospitalName;
          _patientName = patientName;
          _driverName = driverName;
          _drawRoute();
        });
      } else {
        print('No such document!');
      }
    } catch (e) {
      print('Error fetching hospital details: $e');
    }
  }

  void _subscribeToLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) {
      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
        _drawRoute();
        _updateCameraToDriverLocation();
      });
    });
  }

  void _drawRoute() async {
    if (_hospitalLocation == null) return;

    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_driverLocation.latitude},${_driverLocation.longitude}&destination=${_hospitalLocation!.latitude},${_hospitalLocation!.longitude}&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final points = data['routes'][0]['overview_polyline']['points'];
          final routePoints = _decodePolyline(points);
          final legs = data['routes'][0]['legs'][0];
          final distance = legs['distance']['text'];
          final duration = legs['duration']['text'];

          setState(() {
            _polylines = {
              Polyline(
                polylineId: PolylineId('route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
              ),
            };
            _distance = distance;
            _duration = duration;
          });
        } else {
          print('No routes found');
        }
      } else {
        print('Failed to fetch directions');
      }
    } catch (e) {
      print('Error drawing route: $e');
    }
  }

  List<LatLng> _decodePolyline(String encodedPolyline) {
    List<PointLatLng> decodedPolylinePoints =
        PolylinePoints().decodePolyline(encodedPolyline);
    List<LatLng> routePoints = [];
    if (decodedPolylinePoints.isNotEmpty) {
      decodedPolylinePoints.forEach((PointLatLng point) {
        routePoints.add(LatLng(point.latitude, point.longitude));
      });
    }
    return routePoints;
  }

  void _updateCameraToDriverLocation() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _driverLocation,
          zoom: 16.0, // Adjust zoom level
        ),
      ),
    );
  }

  void _completeOrder() async {
    try {
      // Update order status to 'completed' in Firestore
      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.orderId)
          .update({'status': 'completed'});

      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.orderId)
          .update({
        'completedOrder': Timestamp.now(),
      });

      // Fetch the order details
      DocumentSnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.orderId)
          .get();

      if (orderSnapshot.exists) {
        // Get the order data
        Map<String, dynamic> orderData =
            orderSnapshot.data() as Map<String, dynamic>;

        // Move the order to 'orderHistory' collection
        await FirebaseFirestore.instance
            .collection('orderHistory')
            .doc(widget.orderId)
            .set(orderData);

        // Delete the order from 'order' collection
        await FirebaseFirestore.instance
            .collection('order')
            .doc(widget.orderId)
            .delete();

        String userId = orderData['userId'];
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'orderInProgress': false});

        print('Order moved to history and deleted from current orders.');
      } else {
        print('Order document does not exist.');
      }
    } catch (e) {
      print('Error completing order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (widget.initialDriverLocation.latitude +
                          (_hospitalLocation?.latitude ?? 0)) /
                      2,
                  (widget.initialDriverLocation.longitude +
                          (_hospitalLocation?.longitude ?? 0)) /
                      2,
                ),
                zoom: 13.0,
              ),
              polylines: _polylines,
              markers: {
                Marker(
                  markerId: MarkerId('driver'),
                  position: _driverLocation,
                  infoWindow: InfoWindow(title: 'Driver Location'),
                ),
                if (_hospitalLocation != null)
                  Marker(
                    markerId: MarkerId('hospital'),
                    position: _hospitalLocation!,
                    infoWindow: InfoWindow(title: _hospitalName),
                  ),
              },
            ),
            Positioned(
              bottom: 12.0,
              left: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_distance != null)
                      Center(
                        child: Text(
                          'Distance: $_distance',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    SizedBox(height: 2),
                    if (_duration != null)
                      Center(
                        child: Text(
                          'Estimated Time: $_duration',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    SizedBox(height: 5),
                    Divider(
                      color: Colors.grey,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Trip Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    SizedBox(height: 5),
                    if (_hospitalName != null)
                      Text('Destination: $_hospitalName'),
                    if (_patientName != null)
                      Text('Patient Name: $_patientName'),
                    if (_driverName != null) Text('Driver Name: $_driverName'),
                    SizedBox(height: 10),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          _completeOrder();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  OrderSummary(orderId: widget.orderId),
                            ),
                          );
                        },
                        child: Text(
                          'COMPLETE ORDER',
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
              top: 40.0,
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
      ),
    );
  }
}
