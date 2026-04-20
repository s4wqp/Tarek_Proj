import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'dart:math';
import 'package:tarek_proj/data/web_services/web_services.dart';

class AddSponsorScreen extends StatefulWidget {
  const AddSponsorScreen({super.key});

  @override
  State<AddSponsorScreen> createState() => _AddSponsorScreenState();
}

class _AddSponsorScreenState extends State<AddSponsorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _managerPhoneController = TextEditingController();
  final TextEditingController _placePhoneController = TextEditingController();
  final TextEditingController _placeWhatsappPhoneController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  // Detailed Address Controllers
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _aptController = TextEditingController();
  final TextEditingController _markController = TextEditingController();

  // Coordinates
  double? _latitude;
  double? _longitude;

  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;

  final List<String> _categories = [
    'Gym',
    'Restaurant',
    'Therapy',
    'Cafe',
    'Retail',
    'Education',
    'Health',
    'Other'
  ];
  String? _selectedCategory;

  void _fillRandomData() {
    final random = Random();

    String getRandomString(int length) {
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
      return String.fromCharCodes(Iterable.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    }

    String getRandomNumber(int length) {
      const chars = '0123456789';
      return String.fromCharCodes(Iterable.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    }

    setState(() {
      _nameController.text = 'Biz ${getRandomString(4)}';
      _managerNameController.text = 'Mgr ${getRandomString(4)}';
      _managerPhoneController.text = '010${getRandomNumber(8)}';
      _placePhoneController.text = '011${getRandomNumber(8)}';
      _placeWhatsappPhoneController.text = '012${getRandomNumber(8)}';
      _emailController.text = 'test${getRandomNumber(3)}@test.com';
      _websiteController.text = 'https://example${getRandomNumber(2)}.com';

      _selectedCategory = _categories[random.nextInt(_categories.length)];

      _countryController.text = 'Egypt';
      _cityController.text = 'Cairo';
      _zipCodeController.text = getRandomNumber(5);
      _districtController.text = 'Maadi';
      _streetController.text = 'Street ${getRandomNumber(2)}';
      _buildingController.text = getRandomNumber(2);
      _floorController.text = getRandomNumber(1);
      _aptController.text = getRandomNumber(2);
      _markController.text = 'Near ${getRandomString(3)}';

      _latitude = 30.0 + random.nextDouble();
      _longitude = 31.0 + random.nextDouble();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _placePhoneController.dispose();
    _placeWhatsappPhoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();

    _countryController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _districtController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _aptController.dispose();
    _markController.dispose();
    super.dispose();
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permissions are permanently denied, we cannot request permissions.')),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // 1. Try to get last known position first (fastest)
      Position? position = await Geolocator.getLastKnownPosition();

      // 2. If not available, get current position with timeout and optimized accuracy
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _countryController.text = place.country ?? '';
          _cityController.text = place.locality ?? '';
          _zipCodeController.text = place.postalCode ?? '';
          _districtController.text = place.subAdministrativeArea ?? '';
          _streetController.text = place.street ?? '';

          _latitude = position!.latitude;
          _longitude = position.longitude;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location updated successfully")),
          );
        }
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Location request timed out. Please check your GPS signal.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only upload up to 3 images.')),
      );
      return;
    }

    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submitSponsor() async {
    // Basic validation
    if (_nameController.text.isEmpty ||
        _managerNameController.text.isEmpty ||
        _managerPhoneController.text.isEmpty ||
        _placePhoneController.text.isEmpty ||
        _placeWhatsappPhoneController.text.isEmpty ||
        _selectedCategory == null ||
        _countryController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _districtController.text.isEmpty ||
        _streetController.text.isEmpty) {
      // Removed _images.isEmpty check
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill all details and select a category.')), // Updated text
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      List<String> imageUrls = [];

      // 2. Submit to External API
      try {
        final Map<String, dynamic> apiData = {
          "firm_id": 1,
          "sponsor_cat": _selectedCategory ?? 'Other',
          "sponsor_name": _nameController.text,
          "Mangaer_name": _managerNameController.text,
          "country": _countryController.text,
          "state": _cityController.text,
          "district": _districtController.text,
          "zip_code": _zipCodeController.text,
          "street_name": _streetController.text,
          "building_number": _buildingController.text,
          "floor_number": _floorController.text,
          "Unit_number": _aptController.text,
          "Lead_mark": _markController.text,
          "Unit_latitude": _latitude ?? 0.0,
          "Unit_lONGITUDE": _longitude ?? 0.0,
          "sponsor_email": _emailController.text,
          "sponsor_web_site":
              _websiteController.text.isNotEmpty ? _websiteController.text : '',
          "sponsor_tel_no": _placePhoneController.text,
          "sponsor_whatsapp_no": _placeWhatsappPhoneController.text,
          "statu": 1,
          "sponsor_Reg_no":
              0 // Requirement from API, hardcoded since not in form
        };

        final response = await WebServices().addSponsor(apiData, _images);

        if (response.statusCode == 200 || response.statusCode == 201) {
          print("API Response: ${response.statusCode} - ${response.data}");
        } else {
          throw DioException(
              requestOptions: response.requestOptions,
              response: response,
              error: "Status ${response.statusCode}",
              type: DioExceptionType.badResponse);
        }
      } catch (e) {
        String errorMessage = "API Error: $e";
        if (e is DioException && e.response != null) {
          errorMessage =
              "Backend Rejected Request (Status ${e.response?.statusCode}).\n\nServer Response:\n${e.response?.data}";
        }
        print(errorMessage);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("API Submission Failed"),
              content: SingleChildScrollView(child: Text(errorMessage)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("OK"),
                )
              ],
            ),
          );
        }
        // Stop execution here so we don't show success
        return;
      }

      // 3. Save Data to Firestore (Backup/Legacy)
      try {
        await FirebaseFirestore.instance.collection('sponsors').add({
          'business_name': _nameController.text,
          'manager_name': _managerNameController.text,
          'manager_phone': _managerPhoneController.text,
          'place_phone': _placePhoneController.text,
          'place_whatsapp_phone': _placePhoneController.text,
          'email': _emailController.text,
          'website': _websiteController.text,

          'business_category': _selectedCategory,
          // Detailed Address
          'country': _countryController.text,
          'city': _cityController.text,
          'zip_code': _zipCodeController.text,
          'district': _districtController.text,
          'street_name': _streetController.text,
          'building_number': _buildingController.text,
          'floor_number': _floorController.text,
          'apartment_number': _aptController.text,
          'special_mark': _markController.text,

          'latitude': _latitude,
          'longitude': _longitude,

          'images': imageUrls,
          'created_at': FieldValue.serverTimestamp(),
        });
      } catch (firestoreError) {
        print("Firestore Error: $firestoreError");
        // We don't show a snackbar here to avoid confusing the user if the main API succeeded
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sponsor submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error adding sponsor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('General Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Sponsor"),
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Promote your Business",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _fillRandomData,
                  icon: const Icon(Icons.shuffle),
                  label: const Text("Random"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _nameController,
                label: "Business Name",
                icon: Icons.business,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _managerNameController,
                label: "Manager Name",
                icon: Icons.person,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _emailController,
                label: "Email",
                icon: Icons.email,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _websiteController,
                label: "Website (Optional)",
                icon: Icons.language,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _managerPhoneController,
                label: "Manager Phone",
                icon: Icons.phone,
                isNumber: true,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _placePhoneController,
                label: "Place Phone",
                icon: Icons.phone_in_talk,
                isNumber: true,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _placeWhatsappPhoneController,
                label: "Place WhatsApp Phone",
                icon: Icons.phone_in_talk,
                isNumber: true,
              ),
              const SizedBox(height: 15),

              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: "Business Category",
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.category, color: Colors.white),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
                dropdownColor: Colors.grey[900],
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
              ),

              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Address Details",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _isLoadingLocation ? "Locating..." : "Get Location",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildTextField(
                  controller: _countryController,
                  label: "Country",
                  icon: Icons.public),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        controller: _cityController,
                        label: "City",
                        icon: Icons.location_city),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                        controller: _zipCodeController,
                        label: "Zip Code",
                        isNumber: true,
                        icon: Icons.pin_drop),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                  controller: _districtController,
                  label: "District",
                  icon: Icons.map),
              const SizedBox(height: 10),
              _buildTextField(
                  controller: _streetController,
                  label: "Street Name",
                  icon: Icons.streetview),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          controller: _buildingController,
                          label: "Building No",
                          icon: Icons.home,
                          isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildTextField(
                          controller: _floorController,
                          label: "Floor No",
                          icon: Icons.layers,
                          isNumber: true)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          controller: _aptController,
                          label: "Apt No",
                          icon: Icons.door_front_door,
                          isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildTextField(
                          controller: _markController,
                          label: "Special Mark",
                          icon: Icons.flag)),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                "Upload Images (Max 3)",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  ..._images.asMap().entries.map((entry) {
                    int index = entry.key;
                    File img = entry.value;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            img,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_images.length < 3)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Colors.white),
                            SizedBox(
                              height: 5,
                            ),
                            Text(
                              "Add Image",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSponsor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Submit Sponsor",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }
}
