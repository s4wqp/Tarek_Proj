import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/services/search_services2.dart';
import 'package:tarek_proj/presentation/screens/auth/approval_waiting.dart';

class Searchservice extends StatefulWidget {
  const Searchservice({super.key});

  @override
  _SearchserviceState createState() => _SearchserviceState();
}

class _SearchserviceState extends State<Searchservice> {
  List<String> serviceOptions = [
    // Transportation & Delivery
    "Need Motorbike Ride",
    "Need Car Ride",
    "Need Delivery Service",
    "Need Package Courier",

    // Home & Property
    "Need Home Cleaning",
    "Need Farm Cleaning",
    "Need Gardening/Landscaping",
    "Need Handyman Services",
    "Need Pest Control",

    // Education & Tutoring
    "Need Private Teacher",
    "Need Language Tutor",
    "Need Music Instructor",

    // Care & Companionship
    "Need Companion/Caregiver",
    "Need Babysitter",
    "Need Nursing Care",
    "Need Physical Therapy",
    "Need Elderly Assistance",
    "Need Pet Care",

    // Professional Services
    "Need IT Support",
    "Need Graphic Design",
    "Need Event Planning",
    "Need Photography/Videography",

    // Miscellaneous
    "Other Service Needed"
  ];

  Set<String> selectedServices = {};
  TextEditingController otherServiceController = TextEditingController();
  bool isOtherSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Service"),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        width: double.infinity,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Step 2-1: Choose a Service',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select the type of service you need:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: serviceOptions.length,
                  itemBuilder: (context, index) {
                    String option = serviceOptions[index];
                    bool isSelected = selectedServices.contains(option);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (option == "Other") {
                            isOtherSelected = !isOtherSelected;
                            if (!isOtherSelected) {
                              otherServiceController.clear();
                              selectedServices.removeWhere((service) =>
                                  serviceOptions.contains(service));
                            }
                          } else {
                            if (isSelected) {
                              selectedServices.remove(option);
                            } else {
                              selectedServices.add(option);
                            }
                          }
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ||
                                  (option == "Other" && isOtherSelected)
                              ? Colors.indigo
                              : Colors.blueGrey,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Text(
                          option,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (isOtherSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: TextField(
                    controller: otherServiceController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Enter your custom service",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              /// **Submit Button**
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (isOtherSelected &&
                        otherServiceController.text.isNotEmpty) {
                      selectedServices.add(otherServiceController.text);
                    }

                    if (selectedServices.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select at least one service."),
                        ),
                      );
                      return;
                    }

                    print("Selected Services: $selectedServices");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Searchservice2(
                          selectedTime: '',
                          selectedTimes: [],
                          selectedGender: '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    "Next",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isEmailVerified = false;
  bool canResendEmail = true;
  Timer? checkEmailTimer;
  Timer? resendTimer;
  int countdown = 60; // Timer countdown in seconds

  @override
  void initState() {
    super.initState();
    checkEmailVerification();
    checkEmailTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => checkEmailVerification());
  }

  /// Check if the user'controller email is verified
  Future<void> checkEmailVerification() async {
    try {
      // Firebase verification removed.
      setState(() => isEmailVerified = true);
      checkEmailTimer?.cancel();

      // Bypass directly to ApprovalWaitingPage to fetch status from Web API
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ApprovalWaitingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print("Error checking email verification: $e");
    }
  }

  /// Resend the verification email with a timer
  Future<void> resendVerificationEmail() async {
    // Firebase verification removed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Email verification is managed by the backend.')),
    );
  }

  @override
  void dispose() {
    checkEmailTimer?.cancel();
    resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Email')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "A verification email has been sent to your email address.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: canResendEmail ? resendVerificationEmail : null,
              child:
                  Text(canResendEmail ? "Resend Email" : "Wait $countdown sec"),
            ),
            const SizedBox(height: 10),
            Text(
              canResendEmail
                  ? "Didn't receive it? Try again!"
                  : "Please wait before resending.",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(
              height: 60,
            ),
            MaterialButton(
                clipBehavior: Clip.hardEdge,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: const Color.fromARGB(255, 12, 27, 159),
                padding: const EdgeInsets.only(
                    left: 50, right: 50, top: 10, bottom: 10),
                onPressed: () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()));
                },
                child: const Text(
                  'return to Login Screen',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ))
          ],
        ),
      ),
    );
  }
}
