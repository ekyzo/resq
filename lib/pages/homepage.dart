// ignore_for_file: prefer_interpolation_to_compose_strings, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:resq/components/drawer.dart';
import 'package:resq/pages/driverhistorypage.dart';
import 'package:resq/pages/drivermenu.dart';
import 'package:resq/pages/historypage.dart';
import 'package:resq/pages/patientmenu.dart';
import 'package:resq/pages/profilepage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser!;

  int index = 0;

  void goToHomePage() {
    //pop menu drawer
    Navigator.pop(context);
  }

  void goToHistoryPage() async {
    Navigator.pop(context);

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String userType = userData['userType'] ?? 'Unknown';

        if (userType == 'Driver') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverHistoryPage(),
            ),
          );
        } else if (userType == 'Patient') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HistoryPage(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unknown user type: $userType')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User document not found or empty')),
        );
      }
    } catch (e) {
      print('Error fetching user document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user document: $e')),
      );
    }
  }

  void goToProfilePage() {
    //pop menu drawer
    Navigator.pop(context);

    //go to history page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfilePage(),
      ),
    );
  }

  Future signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      print('User signed out successfully');
    } catch (error) {
      print('Error signing out: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: MyDrawer(
        onHomePage: goToHomePage,
        onHistory: goToHistoryPage,
        onProfile: goToProfilePage,
        onSignOut: signOut,
      ),
      body: Center(
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    String userType = userData['userType'];

                    // Check the user type and navigate to the appropriate page
                    if (userType == 'Driver') {
                      return DriverMenu();
                    } else if (userType == 'Patient') {
                      return PatientMenu();
                    } else {
                      return Text('Unknown user type: $userType');
                    }
                  }
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0.0,
                iconTheme: IconThemeData(color: Colors.black),
                toolbarHeight: 90,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, right: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                      ),
                      child: Image(
                        image: AssetImage('assets/resq_logo.png'),
                        width: 120,
                        height: 45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
