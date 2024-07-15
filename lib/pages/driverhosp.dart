import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'driverRouteMap.dart';

class DriverHospMap extends StatefulWidget {
  final String orderId; // Add this line to receive the orderId

  const DriverHospMap({Key? key, required this.orderId}) : super(key: key);

  @override
  _DriverHospMapState createState() => _DriverHospMapState();
}

class _DriverHospMapState extends State<DriverHospMap> {
  GoogleMapController? _mapController;
  LatLng _driverLocation = LatLng(0, 0);
  bool _isLoading = true; // Track loading state
  Set<Marker> _markers = {}; // Store markers for hospitals
  List<dynamic> _hospitals = []; // Store hospital data
  LatLng? _selectedHospitalLocation; // Store selected hospital location
  String? _selectedHospitalName; // Store selected hospital name

  @override
  void initState() {
    super.initState();
    _initDriverLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _initDriverLocation() async {
    try {
      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          print('Location permissions are denied');
          return;
        }
      }

      // Get the current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
        _isLoading =
            false; // Set loading state to false once location is fetched
      });

      print('Driver location: $_driverLocation');

      _animateCameraToDriverLocation();
      _fetchNearbyHospitals(); // Fetch nearby hospitals
    } catch (e) {
      print('Error getting driver location: $e');
      setState(() {
        _isLoading = false; // Ensure loading state is set to false on error
      });
    }
  }

  void _animateCameraToDriverLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _driverLocation,
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  void _fetchNearbyHospitals() async {
    final String apiKey = 'AIzaSyCTG6j7tIvQrts8ZJ0eHQ8dJ4BzwHftxPg';
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${_driverLocation.latitude},${_driverLocation.longitude}'
        '&radius=10000' // Radius of 10 km
        '&type=hospital'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Fetched nearby hospitals: $data');

        if (data['results'] != null && data['results'].isNotEmpty) {
          Set<Marker> newMarkers = {};
          List<dynamic> hospitals = data['results'];

          for (var result in hospitals) {
            final LatLng hospitalLocation = LatLng(
              result['geometry']['location']['lat'],
              result['geometry']['location']['lng'],
            );

            final double distance = Geolocator.distanceBetween(
              _driverLocation.latitude,
              _driverLocation.longitude,
              hospitalLocation.latitude,
              hospitalLocation.longitude,
            );

            result['distance'] = distance; // Add distance to the hospital data

            print(
                'Hospital: ${result['name']}, Location: $hospitalLocation, Distance: $distance');

            newMarkers.add(
              Marker(
                markerId: MarkerId(result['place_id']),
                position: hospitalLocation,
                infoWindow: InfoWindow(title: result['name']),
              ),
            );
          }

          hospitals.sort((a, b) => a['distance']
              .compareTo(b['distance'])); // Sort hospitals by distance

          setState(() {
            _markers = newMarkers;
            _hospitals = hospitals;
          });
        } else {
          print('No results found');
        }
      } else {
        print('Failed to fetch nearby hospitals: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching nearby hospitals: $e');
    }
  }

  void _animateToHospital(LatLng hospitalLocation, String hospitalName) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: hospitalLocation,
            zoom: 17.0,
          ),
        ),
      );
    }
    setState(() {
      _selectedHospitalLocation = hospitalLocation;
      _selectedHospitalName = hospitalName;
    });
  }

  Future<void> _updateOrderWithHospital() async {
    if (_selectedHospitalName == null || _selectedHospitalLocation == null) {
      print('No hospital selected');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('order')
          .doc(widget.orderId)
          .update({
        'selectedHospital': {
          'name': _selectedHospitalName,
          'location': GeoPoint(_selectedHospitalLocation!.latitude,
              _selectedHospitalLocation!.longitude),
        },
        'status': 'on the way', // Add this line
      });

      print('Order updated with selected hospital');
    } catch (e) {
      print('Failed to update order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              flex: 5,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator()) // Loading indicator
                  : GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _animateCameraToDriverLocation(); // Animate camera once the map is created
                      },
                      initialCameraPosition: CameraPosition(
                        target: _driverLocation,
                        zoom: 14.0,
                      ),
                      markers: _markers
                        ..add(
                          Marker(
                            markerId: MarkerId('driver'),
                            position: _driverLocation,
                            infoWindow: InfoWindow(title: 'Driver Location'),
                          ),
                        ),
                    ),
            ),
            Expanded(
              flex: 2,
              child: _hospitals.isNotEmpty
                  ? ListView.builder(
                      itemCount: _hospitals.length,
                      itemBuilder: (context, index) {
                        final hospital = _hospitals[index];
                        final double distanceInKm =
                            (hospital['distance'] / 1000).roundToDouble();
                        return Container(
                          margin:
                              EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: Colors.black,
                              width: 0.5,
                            ),
                          ),
                          child: ListTile(
                            leading: Text(
                              '${distanceInKm} km',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 138, 1, 1),
                              ),
                            ),
                            title: Text(hospital['name']),
                            subtitle: Text('${hospital['vicinity']}'),
                            onTap: () {
                              final LatLng hospitalLocation = LatLng(
                                hospital['geometry']['location']['lat'],
                                hospital['geometry']['location']['lng'],
                              );
                              _animateToHospital(
                                  hospitalLocation, hospital['name']);
                            },
                          ),
                        );
                      },
                    )
                  : Center(child: Text('No hospitals found')),
            ),
            if (_selectedHospitalLocation != null)
              Padding(
                  padding: EdgeInsets.all(10.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await _updateOrderWithHospital(); // Update the Firestore document
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriverRouteMap(
                            initialDriverLocation: _driverLocation,
                            orderId: widget.orderId, // Pass the orderId
                          ),
                        ),
                      );
                    },
                    child: Text('Select Hospital'),
                  )),
          ],
        ),
      ),
    );
  }
}
