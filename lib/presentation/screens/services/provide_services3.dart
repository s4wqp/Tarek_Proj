import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tarek_proj/presentation/screens/services/provide_services4.dart';

class ProvideServices3 extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const ProvideServices3({super.key, required this.registrationData});

  @override
  _ProvideServices3State createState() => _ProvideServices3State();
}

class _ProvideServices3State extends State<ProvideServices3> {
  Position? _currentPosition;
  final TextEditingController cityController = TextEditingController();
  final TextEditingController zipCodeController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController streetNameController = TextEditingController();
  final TextEditingController builderNumberController = TextEditingController();
  final TextEditingController floorNumberController = TextEditingController();
  final TextEditingController apartmentNumberController =
      TextEditingController();
  final TextEditingController leadMarkController = TextEditingController();
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    cityController.dispose();
    zipCodeController.dispose();
    districtController.dispose();
    streetNameController.dispose();
    builderNumberController.dispose();
    floorNumberController.dispose();
    apartmentNumberController.dispose();
    leadMarkController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text("Location is disabled. Please enable it in settings."),
          action: SnackBarAction(
            label: "Open Settings",
            onPressed: () {
              Geolocator.openLocationSettings();
            },
          ),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required.")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Location permission is permanently denied."),
          action: SnackBarAction(
            label: "Open Settings",
            onPressed: () {
              openAppSettings();
            },
          ),
        ),
      );
      return;
    }
  }

  Future<void> _getCurrentLocation() async {
    await _checkLocationPermission();

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          cityController.text = place.locality ?? '';
          zipCodeController.text = place.postalCode ?? '';
          districtController.text = place.subAdministrativeArea ?? '';
          streetNameController.text = place.street ?? '';
          _currentPosition = position;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Location Retrieved",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error retrieving location: $e")),
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _fillRandomData() {
    final faker = Faker();
    setState(() {
      cityController.text = faker.address.city();
      zipCodeController.text = faker.randomGenerator.integer(99999).toString();
      districtController.text = faker.address.state();
      streetNameController.text = faker.address.streetName();
      builderNumberController.text =
          faker.randomGenerator.integer(1000, min: 1).toString();
      floorNumberController.text =
          faker.randomGenerator.integer(20, min: 1).toString();
      apartmentNumberController.text =
          faker.randomGenerator.integer(100, min: 1).toString();
      leadMarkController.text = faker.lorem.sentence();
    });
  }

  void _proceedToNextPage() {
    if (cityController.text.isEmpty ||
        zipCodeController.text.isEmpty ||
        districtController.text.isEmpty ||
        streetNameController.text.isEmpty ||
        builderNumberController.text.isEmpty ||
        floorNumberController.text.isEmpty ||
        apartmentNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill out all address fields")),
      );
      return;
    }

    // Update Registration Data
    widget.registrationData['city'] = cityController.text;
    widget.registrationData['zip_code'] = zipCodeController.text;
    widget.registrationData['district'] = districtController.text;
    widget.registrationData['street_name'] = streetNameController.text;
    widget.registrationData['builder_number'] = builderNumberController.text;
    widget.registrationData['floor_number'] = floorNumberController.text;
    widget.registrationData['apartment_number'] =
        apartmentNumberController.text;
    widget.registrationData['special_marque'] = leadMarkController.text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvideServices4(
          registrationData: widget.registrationData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Address Details'), centerTitle: true),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Step 3: Address',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    icon: _isLoadingLocation
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.location_on),
                    label: Text(_isLoadingLocation
                        ? "Getting Location..."
                        : "Current Location"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _fillRandomData,
                    icon: const Icon(Icons.shuffle),
                    label: const Text("Fill Random"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_currentPosition != null)
                Text(
                  "Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}",
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              const SizedBox(height: 20),

              // Address fields
              ..._buildAddressFields(),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _proceedToNextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: const Text("Next",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAddressFields() {
    final fields = [
      {
        "label": "City",
        "controller": cityController,
        "icon": Icons.location_city,
        "type": TextInputType.text
      },
      {
        "label": "Zip Code",
        "controller": zipCodeController,
        "icon": Icons.map,
        "type": TextInputType.number
      },
      {
        "label": "District",
        "controller": districtController,
        "icon": Icons.apartment,
        "type": TextInputType.text
      },
      {
        "label": "Street Name",
        "controller": streetNameController,
        "icon": Icons.streetview,
        "type": TextInputType.text
      },
      {
        "label": "Builder Number",
        "controller": builderNumberController,
        "icon": Icons.home,
        "type": TextInputType.number
      },
      {
        "label": "Floor Number",
        "controller": floorNumberController,
        "icon": Icons.arrow_upward,
        "type": TextInputType.number
      },
      {
        "label": "Apartment Number",
        "controller": apartmentNumberController,
        "icon": Icons.apartment,
        "type": TextInputType.number
      },
      {
        "label": "Special Mark",
        "controller": leadMarkController,
        "icon": Icons.label,
        "type": TextInputType.text
      },
    ];

    return fields
        .map(
          (field) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              controller: field["controller"] as TextEditingController,
              keyboardType: field["type"] as TextInputType,
              decoration: InputDecoration(
                labelText: field["label"] as String,
                labelStyle: const TextStyle(color: Colors.white),
                prefixIcon: Icon(field["icon"] as IconData),
                prefixIconColor: Colors.blueAccent,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
        )
        .toList();
  }
}
