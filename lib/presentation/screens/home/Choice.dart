import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/services/BothServices.dart';
import 'package:tarek_proj/presentation/screens/services/provide_services.dart';
import 'package:tarek_proj/presentation/screens/services/provide_services3.dart';
import 'package:url_launcher/url_launcher.dart';

class Choice extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const Choice({super.key, required this.registrationData});

  @override
  State<Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<Choice> {
  Set<String> selectedOptions = {}; // Stores selected options

  int currentIndex = 0;
  late Timer _timer;

  final List<Map<String, String>> sponsors = [
    {
      "image": "images/amazon.png",
      "android_url":
          "https://play.google.com/store/apps/details?id=com.amazon.mShop.android.shopping",
      "ios_url": "https://apps.apple.com/app/amazon-shopping/id297606951"
    },
    {
      "image": "images/talabat.png",
      "android_url":
          "https://play.google.com/store/apps/details?id=com.talabat",
      "ios_url": "https://apps.apple.com/app/talabat/id451001072"
    },
    {
      "image": "images/uber.png",
      "android_url":
          "https://play.google.com/store/apps/details?id=com.ubercab",
      "ios_url": "https://apps.apple.com/app/uber/id368677368"
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          currentIndex = (currentIndex + 1) % sponsors.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _launchAppStore(String androidUrl, String iosUrl) async {
    final String url = Platform.isAndroid ? androidUrl : iosUrl;
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print("Could not launch $url");
    }
  }

  void toggleSelection(String option) {
    setState(() {
      if (selectedOptions.contains(option)) {
        selectedOptions.remove(option);
      } else {
        selectedOptions.add(option);
      }
    });
  }

  void navigateToSelectedPages() {
    if (selectedOptions.length == 2) {
      widget.registrationData['serviceType'] = 'Both';
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BothServicesPage()),
      );
    } else if (selectedOptions.contains("Provide a service")) {
      widget.registrationData['serviceType'] = 'Provider';
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ProvideServices(
                  registrationData: widget.registrationData,
                )),
      );
    } else if (selectedOptions.contains("Looking for a service")) {
      widget.registrationData['serviceType'] = 'Seeker';
      // Navigate to Category Selection (Step 1 for Seeker)
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ProvideServices(
                  registrationData: widget.registrationData,
                )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120), // Similar to LoginPage
        child: GestureDetector(
          onTap: () {
            _launchAppStore(
              sponsors[currentIndex]["android_url"]!,
              sponsors[currentIndex]["ios_url"]!,
            );
          },
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(sponsors[currentIndex]["image"]!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage('images/bg.jpg'),
          ),
        ),
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Awesome!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "We're so close",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Step 2 : Select what you need.",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "You want to:\n Note: You can select both",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: buildCircleButton(
                          "Provide a service", Icons.add_card)),
                  const SizedBox(width: 20),
                  Expanded(
                      child: buildCircleButton(
                          "Looking for a service", Icons.search)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed:
                  selectedOptions.isNotEmpty ? navigateToSelectedPages : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedOptions.isNotEmpty
                    ? Colors.blueGrey[700]
                    : Colors.grey[800],
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                "Next",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCircleButton(String title, IconData icon) {
    bool isSelected = selectedOptions.contains(title);
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => toggleSelection(title),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(25),
            backgroundColor:
                isSelected ? Colors.blueAccent : Colors.blueGrey[700],
            elevation: isSelected ? 10 : 5,
          ),
          child: Icon(icon, size: 35, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.blueAccent : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
