import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:resq/pages/drivermap.dart';

class DriverMenu extends StatefulWidget {
  const DriverMenu({Key? key}) : super(key: key);

  @override
  State<DriverMenu> createState() => _DriverMenuState();
}

class _DriverMenuState extends State<DriverMenu> {
  final user = FirebaseAuth.instance.currentUser!;
  String userName = "Driver";
  Map<String, bool> _showImageMap = {};

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final driverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final driverData = driverDoc.data();
    if (driverData != null) {
      setState(() {
        String firstName = driverData['firstName'] ?? 'Driver';
        String lastName = driverData['lastName'] ?? '';
        userName = '$firstName $lastName';
      });
    }
  }

  Future<bool> _requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  Future<Map<String, String>> _getDriverDetails() async {
    final driverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final driverData = driverDoc.data();
    if (driverData != null) {
      return {
        'firstName': driverData['firstName'] ?? 'Unknown',
        'lastName': driverData['lastName'] ?? 'Unknown',
        'phoneNumber': driverData['phoneNumber'] ?? 'N/A',
      };
    }
    return {
      'firstName': 'Unknown',
      'lastName': 'Unknown',
      'phoneNumber': 'N/A',
    };
  }

  void _acceptOrder(Map<String, dynamic> orderData, String orderId) async {
    bool permissionGranted = await _requestLocationPermission();
    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission not granted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final driverDetails = await _getDriverDetails();

      if (mounted) {
        await FirebaseFirestore.instance
            .collection('order')
            .doc(orderId)
            .update({
          'status': 'accepted',
          'driverId': user.uid,
          'driverLocation': GeoPoint(position.latitude, position.longitude),
          'driverName':
              '${driverDetails['firstName']} ${driverDetails['lastName']}',
          'driverPhone': driverDetails['phoneNumber'],
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverMap(
              patientLocation: orderData['location'],
              orderId: orderId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 150, 1, 1),
              Color.fromARGB(255, 150, 58, 58),
              Color.fromARGB(255, 235, 96, 96),
              Color.fromARGB(255, 214, 138, 138),
            ],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 60,
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 25),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome Back,',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      userName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 2.0),
                            blurRadius: 2.0,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                padding: EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 25,
                        //left: 20,
                        //bottom: 12,
                      ),
                      child: Center(
                        child: Text(
                          'Order List'.toUpperCase(),
                          style: TextStyle(
                            color: Color.fromARGB(255, 138, 1, 1),
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: Color.fromARGB(255, 119, 11, 11),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('order')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No orders available.'));
                          }

                          return ListView(
                            children: snapshot.data!.docs.map((doc) {
                              Map<String, dynamic> data =
                                  doc.data() as Map<String, dynamic>;
                              String userName =
                                  data['userName'] ?? 'Unknown User';
                              String userPhone = data['userPhone'] ?? 'N/A';
                              String orderId = doc.id;
                              String? imageUrl = data['imageUrl'];

                              String formattedTimestamp = data['timestamp'] !=
                                      null
                                  ? DateFormat('kk:mm (dd/MM/yyyy)').format(
                                      (data['timestamp'] as Timestamp).toDate())
                                  : 'N/A';

                              return Card(
                                margin: EdgeInsets.all(10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                elevation: 3,
                                child: ExpansionTile(
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${data['emergencyType'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        userPhone,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        formattedTimestamp,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Severity: ${data['severity'] ?? 'N/A'}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Description: ${data['description'] ?? 'N/A'}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Location: ${data['location'] != null ? '${(data['location'] as GeoPoint).latitude}, ${(data['location'] as GeoPoint).longitude}' : 'N/A'}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          SizedBox(height: 2),
                                          imageUrl != null
                                              ? StatefulBuilder(
                                                  builder: (context, setState) {
                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        TextButton(
                                                          onPressed: () {
                                                            setState(() {
                                                              _showImageMap[
                                                                  orderId] = !_showImageMap
                                                                      .containsKey(
                                                                          orderId)
                                                                  ? true
                                                                  : !_showImageMap[
                                                                      orderId]!;
                                                            });
                                                          },
                                                          child: Text(
                                                            _showImageMap[
                                                                        orderId] ??
                                                                    false
                                                                ? 'Hide Image'
                                                                : 'View Image',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.blue,
                                                              decoration:
                                                                  TextDecoration
                                                                      .underline,
                                                            ),
                                                          ),
                                                        ),
                                                        _showImageMap[
                                                                    orderId] ??
                                                                false
                                                            ? Image.network(
                                                                imageUrl)
                                                            : Container(),
                                                      ],
                                                    );
                                                  },
                                                )
                                              : Container(),
                                          _showImageMap[orderId] ?? false
                                              ? Image.network(imageUrl!)
                                              : Container(),
                                          SizedBox(height: 5),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _acceptOrder(data, orderId),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color.fromARGB(
                                                  255, 138, 1, 1),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30.0),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 10, horizontal: 30),
                                            ),
                                            child: Text('ACCEPT',
                                                style: TextStyle(fontSize: 16)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
