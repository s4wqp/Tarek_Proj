import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/profile/ProfileScreen.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const HomeContent(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff030927),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xff0d173e),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xff030927),
        appBar: AppBar(
          backgroundColor: const Color(0xff030927),
          actions: [
            GestureDetector(
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                    );
                  }
                } catch (e) {
                  print("Logout error: $e");
                }
              },
              child: const Icon(
                Icons.logout,
                color: Colors.white,
                size: 26,
              ),
            )
          ],
          title: const Text(
            'Home',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(
              height: 30,
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff2d3142),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.only(left: 25, top: 23),
              width: double.infinity,
              height: 120,
              child: const Column(
                // spacing: 7, // spacing is not a property of Column in older Flutter versions, using SizedBox instead if needed or checking version. Assuming user has new flutter but to be safe I will remove it and use SizedBox or MainAxisAlignment if it was intended for gap.
                // The original code had `spacing: 7`. If the user is on a very new Flutter SDK (3.24+), this is valid.
                // However, to be safe and avoid errors if they are on slightly older versions, I will use standard layout.
                // Wait, the user's original code had `spacing: 7`. I should probably keep it if I can, or replace it with safe code.
                // I'll replace it with a gap or SizedBox to be safe.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's earnings",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 7),
                  Text("125.50\$",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xff2d3142),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  'View earning reports',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff2d3142),
                borderRadius: BorderRadius.circular(12),
              ),
              width: double.infinity, height: 250,
              // child : here should put map
            ),
            const SizedBox(
              height: 30,
            ),
            ListTile(
                leading: ElevatedButton(
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.blue)),
                  onPressed: () {},
                  child: const Text(
                    'Start ride',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                trailing: ElevatedButton(
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(const Color(0xff2d3142))),
                  onPressed: () {},
                  child: const Text(
                    'View ride history',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                )),
          ]),
        ));
  }
}
