import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/Choice.dart';

class PersonalInfo4 extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  final String firstName;
  final String lastName;
  final String arabicName;
  final String jobTitle;
  final String phone;
  final String whatsapp;
  final String birthDate;

  const PersonalInfo4({
    super.key,
    required this.email,
    required this.username,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.arabicName,
    required this.jobTitle,
    required this.phone,
    required this.whatsapp,
    required this.birthDate,
  });

  @override
  _PersonalInfo4State createState() => _PersonalInfo4State();
}

class _PersonalInfo4State extends State<PersonalInfo4> {
  String selectedGender = "Male";
  String selectedCountry = "Egypt";
  String selectedCity = "Cairo";

  final Map<String, List<String>> countryCities = {
    "Egypt": [
      "Cairo",
      "Alexandria",
      "Giza",
      "Luxor",
      "Aswan",
      "Sharm El-Sheikh",
      "Hurghada",
      "Fayoum",
      "Port Said",
      "Suez"
    ],
    "Saudi Arabia": [
      "Riyadh",
      "Jeddah",
      "Mecca",
      "Medina",
      "Dammam",
      "Khobar",
      "Taif"
    ],
    "United Arab Emirates": [
      "Dubai",
      "Abu Dhabi",
      "Sharjah",
      "Ajman",
      "Al Ain"
    ],
    "Kuwait": ["Kuwait City", "Hawalli", "Salmiya", "Farwaniya", "Ahmadi"],
    "Qatar": ["Doha", "Al Wakrah", "Al Khor", "Al Rayyan"],
    "Bahrain": ["Manama", "Muharraq", "Riffa", "Isa Town", "Hamad Town"],
    "Oman": ["Muscat", "Salalah", "Sohar", "Nizwa", "Sur"],
    "Jordan": ["Amman", "Zarqa", "Irbid", "Aqaba", "Salt"],
    "Lebanon": ["Beirut", "Tripoli", "Sidon", "Tyre", "Byblos"],
    "United States": [
      "New York",
      "Los Angeles",
      "Chicago",
      "Houston",
      "Miami",
      "San Francisco"
    ],
    "United Kingdom": [
      "London",
      "Manchester",
      "Birmingham",
      "Edinburgh",
      "Glasgow"
    ]
  };

  List<String> get countries => countryCities.keys.toList();
  List<String> get currentCities => countryCities[selectedCountry] ?? [];

  void handlePrevious() {
    Navigator.pop(context);
  }

  void handleNext() {
    // Collect all data accumulated so far
    Map<String, dynamic> registrationData = {
      'email': widget.email,
      'username': widget.username,
      'password': widget.password,
      'firstName': widget.firstName,
      'lastName': widget.lastName,
      'arabicName': widget.arabicName,
      'jobTitle': widget.jobTitle,
      'phone': widget.phone,
      'whatsapp_number': widget.whatsapp,
      'birthDate': widget.birthDate,
      'gender': selectedGender,
      'country': selectedCountry,
      'city': selectedCity,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Choice(
          registrationData: registrationData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demographics'), centerTitle: true),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/bg.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Step 4 of 4',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  "Select Gender",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                ToggleButtons(
                  fillColor: Colors.white24,
                  selectedColor: Colors.white,
                  color: Colors.white,
                  isSelected: [
                    selectedGender == "Male",
                    selectedGender == "Female"
                  ],
                  onPressed: (index) {
                    setState(() {
                      selectedGender = index == 0 ? "Male" : "Female";
                    });
                  },
                  borderRadius: BorderRadius.circular(15),
                  children: const [
                    Padding(padding: EdgeInsets.all(10), child: Text("Male")),
                    Padding(padding: EdgeInsets.all(10), child: Text("Female")),
                  ],
                ),
                const SizedBox(height: 30),

                // Country Selection
                const Text(
                  "Select Country",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.indigo, width: 1),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCountry,
                    isExpanded: true,
                    icon: const Icon(Icons.public, color: Colors.indigo),
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                    dropdownColor: Colors.white,
                    items: countries.map((country) {
                      return DropdownMenuItem<String>(
                        value: country,
                        child: Text(country),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedCountry = newValue!;
                        selectedCity = currentCities.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // City Selection
                const Text(
                  "Select City",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.indigo, width: 1),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCity,
                    isExpanded: true,
                    icon: const Icon(Icons.location_city, color: Colors.indigo),
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                    dropdownColor: Colors.white,
                    items: currentCities.map((city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedCity = newValue!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 30),

                const SizedBox(height: 40),

                // Navigation Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: handlePrevious,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.grey[800],
                      ),
                      child: const Text('Previous',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: handleNext,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.indigo,
                      ),
                      child: const Text('Next',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
