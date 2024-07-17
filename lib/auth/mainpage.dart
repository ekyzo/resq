// ignore_for_file: prefer_const_constructors

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:resq/auth/authpage.dart';
import 'package:resq/pages/homepage.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If the connection is waiting or none, show a loading indicator
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.none) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Loading..."),
                ],
              ),
            );
          }

          // If there is an authenticated user, show the HomePage
          if (snapshot.hasData) {
            return HomePage();
          }

          // If there is no authenticated user, show the AuthPage
          else {
            return AuthPage();
          }
        },
      ),
    );
  }
}
