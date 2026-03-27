import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tarek_proj/presentation/screens/services/provide_services3.dart';
import 'package:tarek_proj/data/web_services/cloud_vision_service.dart';

class ProvideServices2 extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const ProvideServices2({super.key, required this.registrationData});

  @override
  _ProvideServices2State createState() => _ProvideServices2State();
}

class _ProvideServices2State extends State<ProvideServices2> {
  int _currentImageIndex = 0;
  late Timer _timer;
  Set<String> selectedTimes = {};
  String? selectedGender;
  String? selectedTransportation;
  final TextEditingController vehicleNameController = TextEditingController();
  final TextEditingController vehicleColorController = TextEditingController();
  final TextEditingController vehicleNumberController = TextEditingController();

  // New Controllers and Variables
  final TextEditingController carLicenseController = TextEditingController();
  final TextEditingController carLicenseEndDateController =
      TextEditingController();
  final TextEditingController userLicenseController = TextEditingController();
  String? selectedCarModelYear;
  File? carLicenseImage;
  File? userLicenseImage;
  File? carPhoto;
  final ImagePicker _picker = ImagePicker();

  // Generate years list (e.g., 1980 current year + 1)
  final List<String> carModelYears = List.generate(
          DateTime.now().year - 1980 + 2, (index) => (1980 + index).toString())
      .reversed
      .toList();

  final List<String> sponsorImages = [
    'images/img1.jpeg',
    'images/img2.jpeg',
    'images/img3.jpeg',
    'images/img4.png',
  ];

  final List<String> transportationOptions = [
    'None',
    'Car',
    'Motorbike',
    'Bike'
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % sponsorImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    vehicleNameController.dispose();
    vehicleColorController.dispose();
    vehicleNumberController.dispose();
    carLicenseController.dispose();
    carLicenseEndDateController.dispose();
    userLicenseController.dispose();
    super.dispose();
  }

  /// Converts Arabic/Eastern Arabic numeral characters to Western digits
  String _convertArabicNumerals(String text) {
    StringBuffer result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0660 && code <= 0x0669) {
        result.write(code - 0x0660);
      } else if (code >= 0x06F0 && code <= 0x06F9) {
        result.write(code - 0x06F0);
      } else {
        result.write(text[i]);
      }
    }
    return result.toString();
  }

  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        carLicenseEndDateController.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickImage(String type) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _processImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _processImage(ImageSource.gallery, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(ImageSource source, String type) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    File file = File(image.path);
    setState(() {
      if (type == 'car') {
        carLicenseImage = file;
      } else if (type == 'user') {
        userLicenseImage = file;
      } else if (type == 'carPhoto') {
        carPhoto = file;
      }
    });

    if (type == 'carPhoto') return; // Don't scan car photos for text

    // Process OCR
    try {
      String? ocrText;

      // Pass 1: Latin recognizer
      final inputImage = InputImage.fromFile(file);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      ocrText = recognizedText.text;
      textRecognizer.close();

      // Normalize Arabic numerals using Unicode codepoint ranges
      String fullText = _convertArabicNumerals(ocrText);
      print("Normalized Text for $type License (Pass 1): $fullText");

      _extractAndFillData(fullText, type);

      // Pass 2: If fields are still empty, try default recognizer
      bool needsRetry =
          (type == 'user' && userLicenseController.text.isEmpty) ||
              (type == 'car' && carLicenseController.text.isEmpty);

      if (needsRetry) {
        try {
          final inputImage2 = InputImage.fromFile(file);
          final textRecognizer2 = TextRecognizer();
          final RecognizedText recognizedText2 =
              await textRecognizer2.processImage(inputImage2);

          String fullText2 = _convertArabicNumerals(recognizedText2.text);
          print("Normalized Text for $type License (Pass 2): $fullText2");
          _extractAndFillData(fullText2, type);
          textRecognizer2.close();
        } catch (e) {
          print("OCR Pass 2 Error: $e");
        }
      }

      // Pass 3: Cloud Vision API (supports Arabic numerals)
      bool stillNeedsRetry =
          (type == 'user' && userLicenseController.text.isEmpty) ||
              (type == 'car' && carLicenseController.text.isEmpty);

      if (stillNeedsRetry) {
        try {
          print("OCR Pass 3: Trying Cloud Vision for $type license...");
          final cloudVision = CloudVisionService();
          String? cloudText = await cloudVision.detectText(file);
          if (cloudText != null) {
            String convertedText = _convertArabicNumerals(cloudText);
            print("Cloud Vision text for $type: $convertedText");
            _extractAndFillData(convertedText, type);
          }
        } catch (e) {
          print("OCR Pass 3 (Cloud Vision) Error: $e");
        }
      }
    } catch (e) {
      print("OCR Error: $e");
    }
  }

  void _extractAndFillData(String text, String type) {
    // Clean text: remove non-alphanumeric characters except spaces/newlines to simplify processing?
    // Actually, getting raw text is better.

    if (type == 'user') {
      // User License/ID Card logic
      // target: 14 digit National ID

      // Strategy: Find all sequences of digits, potentially separated by spaces
      // normalization removed spaces? No.

      // Remove all non-digit characters to check for a continuous stream of 14 digits?
      // No, that might merge different numbers (e.g. date + id).

      // Regex to find 10-20 digits allow dashes and spaces
      // e.g. 1234 5678 9012 34 OR 123456789-005
      final idRegex = RegExp(r'\d[\s\d-]{9,20}\d');
      final matches = idRegex.allMatches(text);

      String? bestCandidate;

      for (final match in matches) {
        String raw = match.group(0)!;
        String digitsOnly =
            raw.replaceAll(RegExp(r'\D'), ''); // Remove spaces/symbols

        if (digitsOnly.length >= 10 && digitsOnly.length <= 16) {
          // Prefer 14 digits (Egypt)
          // But accept 10+ (USA driver's license often 9-12)
          if (digitsOnly.length == 14) {
            bestCandidate = digitsOnly;
          } else if (bestCandidate == null ||
              (bestCandidate.length != 14 &&
                  digitsOnly.length > bestCandidate.length)) {
            // Keep longest candidate if we don't have a 14-digit one
            bestCandidate = digitsOnly;
          }
        }
      }

      if (bestCandidate != null) {
        setState(() {
          userLicenseController.text = bestCandidate!;
        });
      }
    } else if (type == 'car') {
      // Car License Logic
      // Target: 3-4 digit number (Standard Egyptian Plate)
      // Text might be: "س ب ر 1234" or "1 2 3 4"

      // Find all numbers in the text, allowing for spaces in between digits
      // e.g. "1 2 3 4" or "1234"
      // Regex: digit followed by optional space/hyphen then another digit
      final regex = RegExp(r'\d[\d\s-]*\d');
      final matches = regex.allMatches(text);

      String? bestCandidate;
      String? shortCandidate;
      String? longCandidate;

      for (final match in matches) {
        String num = match.group(0)!;
        String cleanNum = num.replaceAll(
            RegExp(r'[\s-]+'), ''); // remove all spaces and hyphens

        int len = cleanNum.length;

        // Check for Plate Number (3-4)
        if (len >= 3 && len <= 4) {
          int val = int.tryParse(cleanNum) ?? 0;
          // Filter out likely years
          if (len == 4 && (val >= 1900 && val <= 2100)) {
            continue;
          }
          if (shortCandidate == null) shortCandidate = cleanNum;
        }

        // Check for Long ID/License/Chassis (10-14+)
        if (len >= 10) {
          // Likely a license number (National ID is 14)
          if (longCandidate == null || len > longCandidate.length) {
            longCandidate = cleanNum;
          }
        }
      }

      // Priority: If user uploaded a driver's license (14 digits) to Car License field, use it if no short number found?
      // Or prioritize long number if present?
      // Since user complained about 14 digit number not showing, let's prefer it if found.
      bestCandidate = longCandidate ?? shortCandidate;

      if (bestCandidate != null) {
        setState(() {
          carLicenseController.text = bestCandidate!;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Could not detect license number. If using Arabic numerals, please enter manually."),
          duration: Duration(seconds: 4),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          flexibleSpace: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: Container(
              key: ValueKey<int>(_currentImageIndex),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(sponsorImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.4), BlendMode.darken),
                ),
              ),
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Step 2 of 4',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Work Preferences',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // SECTION: Working Time
                _buildSectionHeader(
                    'Availability', 'Select your preferred shifts'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTimeCard("Morning", Icons.wb_sunny_rounded),
                    _buildTimeCard("Afternoon", Icons.wb_twilight_rounded),
                    _buildTimeCard("Night", Icons.nights_stay_rounded),
                  ],
                ),
                const SizedBox(height: 32),

                // SECTION: Gender
                _buildSectionHeader(
                    'Client Preference', 'Who do you prefer to assist?'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildGenderCard("Male", Icons.male_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            _buildGenderCard("Female", Icons.female_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildGenderCard("Any", Icons.people_alt_rounded,
                            value: "NeverMind")),
                  ],
                ),
                const SizedBox(height: 32),

                // SECTION: Transportation
                _buildSectionHeader('Transportation', 'How will you commute?'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: transportationOptions.map((option) {
                    bool isSelected = selectedTransportation == option;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedTransportation = isSelected ? null : option;
                          if (!isSelected &&
                              option != 'Car' &&
                              option != 'Motorbike') {
                            vehicleNameController.clear();
                            vehicleColorController.clear();
                            vehicleNumberController.clear();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color:
                                isSelected ? Colors.blueAccent : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // SECTION: Vehicle Details
                if (selectedTransportation == 'Car' ||
                    selectedTransportation == 'Motorbike') ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            'Vehicle Details', 'Information for verification',
                            small: true),
                        const SizedBox(height: 20),
                        _buildGlassTextField(
                          controller: vehicleNameController,
                          label: '${selectedTransportation} Name/Brand',
                          icon: Icons.directions_car_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Model Year Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCarModelYear,
                              hint: Text('Select Model Year',
                                  style: TextStyle(color: Colors.white54)),
                              dropdownColor: const Color(0xFF1E1E1E),
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white70),
                              isExpanded: true,
                              items: carModelYears.map((String year) {
                                return DropdownMenuItem<String>(
                                  value: year,
                                  child: Text(year,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => selectedCarModelYear = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildGlassTextField(
                          controller: vehicleColorController,
                          label: 'Color',
                          icon: Icons.color_lens_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassTextField(
                          controller: vehicleNumberController,
                          label: 'Plate No.',
                          icon: Icons.pin_rounded,
                        ),
                        const SizedBox(height: 24),

                        _buildSectionHeader(
                            'License Uploads', 'Clear photos required',
                            small: true),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                                child: _buildImageUploadCard(
                                    'Vehicle License', 'car', carLicenseImage)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildImageUploadCard('Driver License',
                                    'user', userLicenseImage)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildImageUploadCard(
                            'Vehicle Photo', 'carPhoto', carPhoto,
                            fullWidth: true),

                        const SizedBox(height: 24),
                        _buildGlassTextField(
                          controller: carLicenseController,
                          label: 'Vehicle License No.',
                          icon: Icons.badge_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassTextField(
                          controller: carLicenseEndDateController,
                          label: 'License Expiry',
                          icon: Icons.event_rounded,
                          readOnly: true,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassTextField(
                          controller: userLicenseController,
                          label: 'Driver License No.',
                          icon: Icons.subtitles_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Submit Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (selectedTimes.isEmpty || selectedGender == null) {
      _showError("Please select availability and client preference.");
      return;
    }

    if ((selectedTransportation == 'Car' ||
            selectedTransportation == 'Motorbike') &&
        (vehicleNameController.text.isEmpty ||
            selectedCarModelYear == null ||
            vehicleColorController.text.isEmpty ||
            vehicleNumberController.text.isEmpty ||
            carLicenseController.text.isEmpty ||
            carLicenseEndDateController.text.isEmpty ||
            userLicenseController.text.isEmpty ||
            carLicenseImage == null ||
            userLicenseImage == null ||
            carPhoto == null)) {
      _showError("Please fill all vehicle and license details.");
      return;
    }

    widget.registrationData['working_time'] = selectedTimes.toList();
    widget.registrationData['deal_with_gender'] = selectedGender;
    widget.registrationData['transportation_type'] = selectedTransportation;

    if (selectedTransportation == 'Car' ||
        selectedTransportation == 'Motorbike') {
      widget.registrationData['vehicle_name'] = vehicleNameController.text;
      widget.registrationData['vehicle_model_year'] = selectedCarModelYear;
      widget.registrationData['vehicle_color'] = vehicleColorController.text;
      widget.registrationData['vehicle_number'] = vehicleNumberController.text;
      widget.registrationData['car_license_number'] = carLicenseController.text;
      widget.registrationData['car_licence_end_date'] =
          carLicenseEndDateController.text;
      widget.registrationData['user_license_number'] =
          userLicenseController.text;

      // Images
      widget.registrationData['carLicenseImage'] = carLicenseImage;
      widget.registrationData['userLicenseImage'] = userLicenseImage;
      widget.registrationData['carPhoto'] = carPhoto;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvideServices3(
          registrationData: widget.registrationData,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle,
      {bool small = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 18 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTimeCard(String shift, IconData icon) {
    bool isSelected = selectedTimes.contains(shift);
    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected ? selectedTimes.remove(shift) : selectedTimes.add(shift);
        });
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.26,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.blueAccent : Colors.white54,
                size: 32),
            const SizedBox(height: 12),
            Text(
              shift,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard(String label, IconData icon, {String? value}) {
    String actualValue = value ?? label;
    bool isSelected = selectedGender == actualValue;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = actualValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? Colors.transparent : Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.white54, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.blueAccent.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildImageUploadCard(String label, String type, File? imageFile,
      {bool fullWidth = false}) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            height: fullWidth ? 160 : 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color:
                      imageFile != null ? Colors.greenAccent : Colors.white24,
                  width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageFile != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(imageFile, fit: BoxFit.cover),
                      Container(color: Colors.black26),
                      const Center(
                          child: Icon(Icons.check_circle_rounded,
                              color: Colors.greenAccent, size: 32)),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          fullWidth
                              ? Icons.add_a_photo_rounded
                              : Icons.document_scanner_rounded,
                          color: Colors.white54,
                          size: 32),
                      const SizedBox(height: 8),
                      Text("Tap to upload",
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
