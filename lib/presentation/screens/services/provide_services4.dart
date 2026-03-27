import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:tarek_proj/data/web_services/gemini_vision_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/data/web_services/cloud_vision_service.dart';
import 'package:tarek_proj/presentation/screens/auth/approval_waiting.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProvideServices4 extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const ProvideServices4({super.key, required this.registrationData});

  @override
  _ProvideServices4State createState() => _ProvideServices4State();
}

class _ProvideServices4State extends State<ProvideServices4> {
  final TextEditingController additionalDetailsController =
      TextEditingController();
  final TextEditingController certificationNameController =
      TextEditingController();
  final TextEditingController idNumberController = TextEditingController();

  File? faceImage;
  File? graduationCertificate;
  File? personalIdCardFront;
  File? personalIdCardBack;
  String? extractedIDNumber;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // Persistent OCR digit storage across both front and back scans
  List<String> _frontDigitFragments = [];
  List<String> _backDigitFragments = [];

  @override
  void dispose() {
    additionalDetailsController.dispose();
    certificationNameController.dispose();
    idNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String imageType, {bool cameraOnly = false}) async {
    if (cameraOnly) {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      _setImage(imageType, pickedFile);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(15),
        height: 160,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Take Photo"),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile =
                    await _picker.pickImage(source: ImageSource.camera);
                _setImage(imageType, pickedFile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text("Choose from Gallery"),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile =
                    await _picker.pickImage(source: ImageSource.gallery);
                _setImage(imageType, pickedFile);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setImage(String imageType, XFile? pickedFile) async {
    if (pickedFile != null) {
      File image = File(pickedFile.path);
      setState(() {
        if (imageType == 'Face') {
          faceImage = image;
        } else if (imageType == 'Graduation') {
          graduationCertificate = image;
        } else if (imageType == 'ID_Front') {
          personalIdCardFront = image;
        } else if (imageType == 'ID_Back') {
          personalIdCardBack = image;
        }
      });
      // OCR ONLY runs when BACK card is uploaded — never on front upload alone
      if (imageType == 'ID_Back') {
        // Clear previous fragments for a fresh combined scan
        _frontDigitFragments.clear();
        _backDigitFragments.clear();

        // Scan front image first SILENTLY (no dialog)
        if (personalIdCardFront != null) {
          await _scanText(personalIdCardFront!,
              isFront: true, showResultDialog: false);
        }
        // Then scan back image WITH dialog (this will also trigger the fallback chain)
        await _scanText(image, isFront: false, showResultDialog: true);

        // === PASS 4 (MULTI-IMAGE): Gemini Vision AI ===
        // We run this ONLY at the very end when BOTH images are available
        if (personalIdCardFront != null) {
          // Check if local OCR failed to find complete 14 digits
          // If the field isn't 14 digits long, local failed. Let's fire AI.
          if (idNumberController.text.length != 14) {
            try {
              print("=== OCR Pass 4 (Gemini Vision AI: MULTI-IMAGE) ===");

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Cloud AI analyzing both card sides..."),
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.blue,
                ));
              }

              final geminiVision = GeminiVisionService();
              String? geminiResult = await geminiVision
                  .extractNationalId([personalIdCardFront!, image]);
              print("Gemini Multi-Image Result: $geminiResult");

              if (geminiResult != null && geminiResult.length == 14) {
                if (mounted) {
                  setState(() {
                    extractedIDNumber = geminiResult;
                    idNumberController.text = geminiResult;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("ID Number verified by AI: $geminiResult"),
                    duration: const Duration(seconds: 4),
                    backgroundColor: Colors.green,
                  ));
                }
              }
            } catch (e) {
              print("Gemini Multi-Image Error: $e");
            }
          }
        }
      }
    }
  }

  /// Converts ALL Arabic/Eastern Arabic numeral characters to Western digits
  /// using Unicode codepoint ranges for reliability.
  /// Eastern Arabic: U+0660 (٠) to U+0669 (٩)
  /// Extended Arabic-Indic: U+06F0 (۰) to U+06F9 (۹)
  String _convertArabicNumerals(String text) {
    StringBuffer result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0660 && code <= 0x0669) {
        // Eastern Arabic numerals ٠١٢٣٤٥٦٧٨٩
        result.write(code - 0x0660);
      } else if (code >= 0x06F0 && code <= 0x06F9) {
        // Extended Arabic-Indic numerals ۰۱۲۳۴۵۶۷۸۹
        result.write(code - 0x06F0);
      } else {
        result.write(text[i]);
      }
    }
    return result.toString();
  }

  /// Extracts the best 14-digit ID candidate from text
  String? _extractIdFromText(String text) {
    // Convert Arabic numerals to Western digits
    String normalized = _convertArabicNumerals(text);

    // Strategy: Find all sequences of digits, potentially separated by spaces or dashes
    final idRegex = RegExp(r'\d[\d\s-]{9,20}\d');
    final matches = idRegex.allMatches(normalized);

    String? bestCandidate;

    for (final match in matches) {
      String raw = match.group(0)!;
      String digitsOnly = raw.replaceAll(RegExp(r'\D'), '');

      if (digitsOnly.length >= 10 && digitsOnly.length <= 16) {
        if (digitsOnly.length == 14) {
          return digitsOnly; // Perfect match for Egyptian ID
        } else if (bestCandidate == null ||
            (bestCandidate.length != 14 &&
                digitsOnly.length > bestCandidate.length)) {
          bestCandidate = digitsOnly;
        }
      }
    }

    // Fallback: if total digit count is exactly 14, it's likely the ID
    if (bestCandidate == null || bestCandidate.length != 14) {
      String allDigits = normalized.replaceAll(RegExp(r'\D'), '');
      if (allDigits.length == 14) {
        bestCandidate = allDigits;
      }
    }

    return bestCandidate;
  }

  /// Searches all blocks and lines in recognized text for an ID number
  String? _searchRecognizedText(RecognizedText recognizedText) {
    // Try full text first
    String? foundID = _extractIdFromText(recognizedText.text);
    if (foundID != null && foundID.length == 14) return foundID;

    // Try each text block and line individually
    for (TextBlock block in recognizedText.blocks) {
      String? blockResult = _extractIdFromText(block.text);
      if (blockResult != null && blockResult.length == 14) return blockResult;

      for (TextLine line in block.lines) {
        String? lineResult = _extractIdFromText(line.text);
        if (lineResult != null && lineResult.length == 14) return lineResult;
      }
    }

    return foundID; // Return best non-14-digit candidate if any
  }

  Future<void> _scanText(File imageFile,
      {bool isFront = true, bool showResultDialog = true}) async {
    String? foundID;
    List<String> allCollectedDigits = [];

    print("=== OCR SCAN STARTED for National ID ===");
    print("Is Front Card: $isFront");
    print("Image path: ${imageFile.path}");
    print("Image exists: ${imageFile.existsSync()}");
    print("Image size: ${imageFile.lengthSync()} bytes");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Scanning ID card... Please wait."),
        duration: Duration(seconds: 5),
      ));
    }

    // === PASS 1: Barcode Scanner (PDF417 on Card Back) ===
    if (!isFront) {
      try {
        print("=== OCR Pass 1 (Barcode PDF417) ===");
        final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.pdf417]);
        final InputImage inputImage = InputImage.fromFile(imageFile);
        final List<Barcode> barcodes =
            await barcodeScanner.processImage(inputImage);

        allCollectedDigits.add("Barcodes detected: ${barcodes.length}");

        for (Barcode barcode in barcodes) {
          final String rawValue = barcode.rawValue ?? "";
          allCollectedDigits.add("RAW BARCODE: $rawValue");
          print("Barcode Found: $rawValue");

          // Extract digits and find the 14-digit Egyptian ID pattern
          String digitsOnly = rawValue.replaceAll(RegExp(r'\D'), '');
          final match = RegExp(r'[23]\d{13}').firstMatch(digitsOnly);
          if (match != null) {
            foundID = match.group(0);
            allCollectedDigits.add("Barcode: $foundID!");
            print("Barcode Extracted ID: $foundID");
            break;
          }
        }
        barcodeScanner.close();
      } catch (e) {
        print("Barcode Error: $e");
      }
    }

    // === PASS 2: Latin script recognizer ===
    if (foundID == null || foundID.length != 14) {
      try {
        final textRecognizer =
            TextRecognizer(script: TextRecognitionScript.latin);
        final InputImage inputImage = InputImage.fromFile(imageFile);
        final RecognizedText recognizedText =
            await textRecognizer.processImage(inputImage);

        String rawText = recognizedText.text;
        print("=== OCR Pass 1 (Latin) ===");
        print("Raw text: $rawText");

        // Extract ALL digits from text
        String converted = _convertArabicNumerals(rawText);
        String allDigits = converted.replaceAll(RegExp(r'\D'), '');
        if (allDigits.isNotEmpty) allCollectedDigits.add(allDigits);

        foundID = _searchRecognizedText(recognizedText);
        print("Pass 1 extracted ID: $foundID");
        textRecognizer.close();
      } catch (e) {
        print("OCR Pass 1 Error: $e");
      }

      // === PASS 2: Default recognizer ===
      if (foundID == null || foundID.length != 14) {
        try {
          final textRecognizer2 =
              TextRecognizer(script: TextRecognitionScript.latin);
          final InputImage inputImage2 = InputImage.fromFile(imageFile);
          final RecognizedText recognizedText2 =
              await textRecognizer2.processImage(inputImage2);

          String rawText2 = recognizedText2.text;
          print("=== OCR Pass 2 (Default) ===");
          print("Raw text: $rawText2");

          String converted2 = _convertArabicNumerals(rawText2);
          String allDigits2 = converted2.replaceAll(RegExp(r'\D'), '');
          if (allDigits2.isNotEmpty) allCollectedDigits.add(allDigits2);

          String? pass2Result = _searchRecognizedText(recognizedText2);
          print("Pass 2 extracted ID: $pass2Result");

          if (pass2Result != null) {
            if (foundID == null ||
                (pass2Result.length == 14 && foundID.length != 14) ||
                pass2Result.length > foundID.length) {
              foundID = pass2Result;
            }
          }
          textRecognizer2.close();
        } catch (e) {
          print("OCR Pass 2 Error: $e");
        }
      }
    }

    // === PASS 3: OCR.space API (Arabic text support) ===
    if (foundID == null || foundID.length != 14) {
      try {
        print("=== OCR Pass 3 (OCR.space Cloud API) ===");

        final cloudVision = CloudVisionService();
        String? cloudResult = await cloudVision.extractNationalId(imageFile);
        String? rawApiText =
            await cloudVision.detectText(imageFile, engine: 1, language: 'ara');
        print("Pass 3 raw API text: $rawApiText");
        print("Pass 3 extracted ID: $cloudResult");

        // Add cloud OCR raw text digits LINE BY LINE to fragment list
        // (splitting by lines prevents mixing dates with ID numbers)
        if (rawApiText != null) {
          for (String line in rawApiText.split('\n')) {
            String lineDigits =
                _convertArabicNumerals(line).replaceAll(RegExp(r'\D'), '');
            if (lineDigits.length >= 3) {
              allCollectedDigits.add(lineDigits);
              print(
                  "Cloud OCR line digits: $lineDigits (from: ${line.trim()})");
            }
          }
        }

        if (cloudResult != null) {
          if (cloudResult.startsWith("ERROR:")) {
            print("Ignoring API error for ID field population.");
          } else {
            // Also add the extracted result directly
            allCollectedDigits.add(cloudResult);
            if (foundID == null || cloudResult.length > foundID.length) {
              foundID = cloudResult;
            }
          }
        }
      } catch (e) {
        print("OCR Pass 3 (Cloud Vision) Error: $e");
      }
    }

    // === STORE FRAGMENTS & CROSS-IMAGE MERGE ===
    // Save this scan's digit fragments to the persistent list
    if (isFront) {
      _frontDigitFragments.addAll(allCollectedDigits);
    } else {
      _backDigitFragments.addAll(allCollectedDigits);
    }

    // Merge ALL fragments from BOTH front and back scans
    List<String> allMergedDigits = [
      ..._frontDigitFragments,
      ..._backDigitFragments
    ];
    print("=== CROSS-IMAGE MERGE ===");
    print("Front fragments: $_frontDigitFragments");
    print("Back fragments: $_backDigitFragments");
    print("Total merged fragments: ${allMergedDigits.length}");

    // Try to find a valid 14-digit Egyptian ID from the merged pool
    if (foundID == null || foundID.length != 14) {
      final RegExp validIdPattern =
          RegExp(r'[23]\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{7}');

      for (String digits in allMergedDigits) {
        // Clean to digits only (remove debug labels like "Barcode:")
        String cleanDigits =
            _convertArabicNumerals(digits).replaceAll(RegExp(r'\D'), '');
        if (cleanDigits.isEmpty) continue;

        final match = validIdPattern.firstMatch(cleanDigits);
        if (match != null && match.group(0)!.length == 14) {
          foundID = match.group(0);
          print("Cross-image merge found Egyptian ID: $foundID");
          break;
        }
      }
    }

    print("=== OCR FINAL RESULT: $foundID ===");

    if (!mounted) return;

    // If this is a silent sub-scan (front during combined pipeline), just return
    if (!showResultDialog) return;

    setState(() {
      extractedIDNumber =
          foundID ?? "No ID Number Found (Try improved lighting)";
      if (foundID != null && foundID.length == 14) {
        idNumberController.text = foundID;
        print(">>> ID NUMBER SET IN FIELD: ${idNumberController.text}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("ID Number detected: $foundID"),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ));
      } else {
        // === PARTIAL PRE-FILL: 3-tier fallback chain ===
        String? bestPartial;
        List<String> allMergedDigits = [
          ..._frontDigitFragments,
          ..._backDigitFragments
        ];

        print("=== PARTIAL PRE-FILL SEARCH ===");
        print("All merged fragments: $allMergedDigits");

        // Collect all cleaned digit strings from fragments
        List<String> cleanedFragments = [];
        for (String fragment in allMergedDigits) {
          String clean =
              _convertArabicNumerals(fragment).replaceAll(RegExp(r'\D'), '');
          if (clean.length >= 5) {
            cleanedFragments.add(clean);
          }
        }
        print("Cleaned fragments (5+ digits): $cleanedFragments");

        // TIER 1: Egyptian ID date pattern [2|3]YYMMDD (strict)
        final RegExp partialIdPattern =
            RegExp(r'[23]\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])');
        for (String clean in cleanedFragments) {
          final match = partialIdPattern.firstMatch(clean);
          if (match != null) {
            String candidate = clean.substring(match.start);
            if (candidate.length > 14) candidate = candidate.substring(0, 14);
            if (bestPartial == null || candidate.length > bestPartial.length) {
              bestPartial = candidate;
              print("TIER 1 match: $bestPartial");
            }
          }
        }

        // TIER 2: Longest fragment starting with 2 or 3 (less strict)
        if (bestPartial == null) {
          for (String clean in cleanedFragments) {
            for (int i = 0; i < clean.length; i++) {
              if (clean[i] == '2' || clean[i] == '3') {
                String candidate = clean.substring(i);
                if (candidate.length > 14)
                  candidate = candidate.substring(0, 14);
                if (candidate.length >= 5 &&
                    (bestPartial == null ||
                        candidate.length > bestPartial.length)) {
                  bestPartial = candidate;
                  print("TIER 2 match: $bestPartial");
                }
                break;
              }
            }
          }
        }

        // TIER 3: Any longest fragment (last resort)
        if (bestPartial == null) {
          for (String clean in cleanedFragments) {
            if (bestPartial == null || clean.length > bestPartial.length) {
              bestPartial = clean.length > 14 ? clean.substring(0, 14) : clean;
              print("TIER 3 match: $bestPartial");
            }
          }
        }

        if (bestPartial != null && bestPartial.length >= 5) {
          idNumberController.text = bestPartial;
          int missing = 14 - bestPartial.length;
          print(
              ">>> PARTIAL ID PRE-FILLED: $bestPartial ($missing digits missing)");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Found ${bestPartial.length} of 14 digits. Please complete the remaining $missing digits."),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Could not detect ID number. Please enter your 14-digit National ID manually."),
            duration: Duration(seconds: 4),
          ));
        }
      }
    });
  }

  void _removeImage(String imageType) {
    setState(() {
      if (imageType == 'Face') {
        faceImage = null;
      } else if (imageType == 'Graduation') {
        graduationCertificate = null;
      } else if (imageType == 'ID_Front') {
        personalIdCardFront = null;
        extractedIDNumber = null;
      } else if (imageType == 'ID_Back') {
        personalIdCardBack = null;
      }
    });
  }

  Future<void> _submitAllDetails() async {
    // Basic Validation
    if (faceImage == null ||
        graduationCertificate == null ||
        personalIdCardFront == null ||
        personalIdCardBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required images')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare Data for API
      final regData = widget.registrationData;

      // Helper to map Gender/DealWith to Int
      int mapGenderToInt(String? value) {
        if (value == null) return 1;
        String v = value.toLowerCase();
        if (v == 'male') return 1;
        if (v == 'female') return 2;
        return 1;
      }

      // Helper for Transportation
      int mapTransportationToInt(String? value) {
        if (value == null) return 0;
        String v = value.toLowerCase();
        if (v == 'car') return 1;
        if (v == 'motorbike') return 2;
        if (v == 'bike') return 3;
        if (v == 'none') return 0;
        return 0;
      }

      // Helper for Date Formatting (d/M/yyyy -> yyyy-MM-dd)
      String formatDateForApi(String? date) {
        if (date == null || date.isEmpty) return "";
        try {
          List<String> parts = date.split('/');
          if (parts.length == 3) {
            String day = parts[0].padLeft(2, '0');
            String month = parts[1].padLeft(2, '0');
            String year = parts[2];
            return "$year-$month-$day";
          }
          return date;
        } catch (e) {
          return date;
        }
      }

      int mapCategoryToInt(String? category, bool isProvider) {
        if (category == null) return isProvider ? 201 : 101;
        String firstCat = category.split(',')[0].trim();

        // Seeker (1xx)
        if (!isProvider) {
          if (firstCat == "Ask Ride") return 101;
          if (firstCat == "Ask Driver for My car") return 102;
          if (firstCat == "Ask companion for senior") return 103;
          if (firstCat == "Ask baby sitter") return 104;
          if (firstCat == "Ask for nursing") return 105;
          if (firstCat == "Ask physical therapy") return 106;
          if (firstCat == "Ask clean home") return 107;
          if (firstCat == "Ask Teacher") return 108;
          if (firstCat == "Ask rent room or Appartment") return 109;
          return 101; // Default
        }
        // Provider (2xx)
        else {
          if (firstCat == "Provide Ride in my car") return 201;
          if (firstCat == "Provide Drive for other") return 202;
          if (firstCat == "Provide companion senior") return 203;
          if (firstCat == "Provide baby sitter") return 204;
          if (firstCat == "Provide nursing") return 205;
          if (firstCat == "Provide physical therapy") return 206;
          if (firstCat == "Provide clean home") return 207;
          if (firstCat == "Provide private Teaceher") return 208;
          if (firstCat == "Provide room or Appartment") return 209;
          return 201; // Default
        }
      }

      // Helper for Working Time Mapping
      // 1 morning 2 afternoon 3 evening 4 night 5 all
      int mapWorkingTimeToInt(dynamic times) {
        if (times == null) return 5; // Default All?
        List<String> timeList = [];
        if (times is List) {
          timeList = times.map((e) => e.toString()).toList();
        } else if (times is String) {
          timeList = [times];
        }

        if (timeList.isEmpty) return 5;
        // If multiple selected, maybe return 5 (All)? Or just map the first one?
        // Let's check for 'All' or specific combinations?
        // Simple 1-to-1 mapping for now based on first selection
        String first = timeList.first.toLowerCase();
        if (first == 'morning') return 1;
        if (first == 'afternoon') return 2;
        if (first == 'evening') return 3;
        if (first == 'night') return 4;
        if (first == 'all') return 5;

        // Dynamic fallback logic
        if (timeList.length > 2) return 5; // Assume All if many

        return 5;
      }

      // Helper for Firm ID
      int mapFirmId(String? serviceType) {
        // firm_id make it ststic number 1
        return 1;
      }

      // Helper for User Type ID
      // 1-Ask assistant ,2-Provide Assistant ,3-both
      int mapUserTypeId(String? serviceType) {
        if (serviceType == 'Seeker') return 1;
        if (serviceType == 'Provider') return 2;
        return 3; // Both
      }

      // Map App fields to API fields
      Map<String, dynamic> apiData = {
        // IDs
        'firm_id': mapFirmId(regData['serviceType']),
        'u_type_id': mapUserTypeId(regData['serviceType']),
        'cat_id': mapCategoryToInt(
            regData['provide_catagory'] ?? regData['looking_for_category'],
            regData['serviceType'] == 'Provider'),
        'wt_id': mapWorkingTimeToInt(regData['working_time']),

        // User Info
        'user_f_name': regData['firstName'],
        'user_l_name': regData['lastName'],
        'user_ar_name': regData['arabicName'],
        'user_email': regData['email'],
        'user_password': regData['password'],
        'user_tel_no': regData['phone'],
        'user_whatsapp_no': regData['whatsapp_number'] ?? regData['phone'],
        'birth_date': formatDateForApi(regData['birthDate']),
        'Gender': mapGenderToInt(regData['gender']),
        'job': regData['jobTitle'],
        'statu': 1, // 1 bending - 2 approval - 3 reject

        // Address Info
        'country': 'Egypt',
        'state': regData['city'],
        // 'city': regData['city'], // Removed as per new JSON which only has 'state', 'district' etc. Wait, JSON has 'state' and 'district', but no 'city' key in JSON example. It has 'state'.
        // Actually JSON has: country, state, district, zip_code, street_name, Building_number, Floor_number, Apartment_number, Lead_mark
        // Existing code had 'city': regData['city'], which might be extra. I will keep 'state' as city.

        'district': regData['district'],
        'zip_code': regData['zip_code'],
        'street_name': regData['street_name'],
        'Building_number': regData['builder_number'],
        'Floor_number': regData['floor_number'],
        'Apartment_number': regData['apartment_number'],

        // Truncate Lead_mark to match DB VARCHAR(40)
        'Lead_mark': (regData['special_marque'] != null &&
                regData['special_marque'].toString().length > 40)
            ? regData['special_marque'].toString().substring(0, 40)
            : regData['special_marque'],

        // user_name defaults to email per DB spec
        'user_name': regData['email'],

        // Missing fields from JSON
        'user_helth_note': null,
        'user_dr_name': null,
        'user_dr_tel_no': null,
        'user_cer': certificationNameController.text.isNotEmpty
            ? certificationNameController.text
            : null,
        'user_Reg_no': null,
        // 'creation_date': DateTime.now().toIso8601String(), // Server uses NOW()
        // 'modification_Date': DateTime.now().toIso8601String(), // Server uses NOW()

        // Provider specific
        'deal_with': mapGenderToInt(regData['deal_with_gender']),
        'transportation_type':
            mapTransportationToInt(regData['transportation_type']),
        'user_comment': additionalDetailsController.text,

        // TEMPORARILY DISABLED: The backend API throws a SQL syntax error near '?,NOW())' when these fields are sent.
        // Needs fixing on the backend (missing comma in PHP query builder) before they can be sent.
        // 'user_DL': regData['user_license_number'],
        // 'user_car_no': regData['vehicle_number'],
        // 'user_CL': regData['car_license_number'],
        // 'car_licence_end_date': regData['car_licence_end_date'],
        // 'user_car_color': regData['vehicle_color'],
        // 'car_model': regData['vehicle_name'],
        // 'car_model_year': regData['vehicle_model_year'],

        // National ID Number — key must be user_nid to match DB column
        'user_nid': (idNumberController.text.isNotEmpty &&
                RegExp(r'^\d+$').hasMatch(idNumberController.text))
            ? idNumberController.text
            : null,
      };

      // Prepare Files
      Map<String, File> apiFiles = {
        'user_photo': faceImage!,
        'user_cer_photo': graduationCertificate!,
        // 'user_id_photo': personalIdCardFront!, // Removing again: backend crashes/times out processing this file
      };

      // user_DL_photo should be the driver license photo if available
      if (regData['userLicenseImage'] != null) {
        apiFiles['user_DL_photo'] = regData['userLicenseImage'];
      }

      if (regData['carPhoto'] != null) {
        apiFiles['user_car_photo'] = regData['carPhoto'];
      }
      if (regData['carLicenseImage'] != null) {
        apiFiles['user_CL_photo'] = regData['carLicenseImage'];
      }
      if (regData['userLicenseImage'] != null) {
        // Maybe user_DL_Photo should be this?
        // But existing code mapped 'personalIdCardBack' to 'user_DL_Photo'.
        // Let's keep existing and add new if needed, OR fix.
        // Request says: 8- user_CL_Photo VARCHAR(40), /car licence photo/
        // Request says: 6- user_car_photo VARCHAR(40), /car photo/
        // Request says: 7- user_CL VARCHAR(20), /car licence No/ (Added above)
        // Request says: 9- user_car_no VARCHAR(20)/ car Number (Added above)

        // Assuming 'user_DL_Photo' in existing code was actually "Driver License" (User License)?
        // But it was assigned `personalIdCardBack` (ID Back).
        // The prompt didn't ask to change `user_DL_Photo` logic, but asked to ADD fields.
        // NOTE: `user_CL` -> Car License. `user_CL_Photo` -> Car License Photo.
        // I'll stick to the requested fields.
      }

      // Call API
      // Call API
      print(
          "DEBUG: Preparing to send files with keys: ${apiFiles.keys.toList()}");
      print("DEBUG: apiData payload: $apiData");

      Response response = await WebServices().registerUser(apiData, apiFiles);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Custom API Success - Now Create Firebase Account
        try {
          // 1. Create User in Firebase Auth
          UserCredential userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: regData['email'],
            password: regData['password'],
          );

          // 2. Determine Service Type & Status
          String serviceType = regData['serviceType'] ?? 'Seeker';
          bool isProvider = serviceType == 'Provider';
          bool isSeeker = serviceType == 'Seeker';

          // 3. Save to Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'firstName': regData['firstName'],
            'lastName': regData['lastName'],
            'email': regData['email'],
            'phone': regData['phone'],
            'arabicName': regData['arabicName'],
            'serviceType': serviceType,
            'isProvider': isProvider,
            'isSeeker': isSeeker,
            'approvalStatus': 'pending',
            'city': regData['city'],
            'u_type_id': (serviceType == 'Provider') ? 1 : 2,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 4. Navigate
          if (mounted) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) => const ApprovalWaitingPage()),
              (route) => false,
            );
          }
        } on FirebaseAuthException catch (e) {
          throw Exception("Firebase Auth Error: ${e.message}");
        } catch (e) {
          throw Exception("Firestore Error: $e");
        }
      } else {
        throw Exception(
            "API Error: ${response.statusCode} - ${response.statusMessage}");
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String errorMessage = "Connection failed";
        if (e.response != null) {
          String dataString = e.response?.data.toString() ?? "";
          if (dataString.contains("Data too long") &&
              dataString.contains("user_password")) {
            errorMessage =
                "Registration Failed: 'Data too long'. Backend has VARCHAR(16). If it uses hashing, even short passwords might overshoot this. Contact backend dev.";
          } else {
            errorMessage =
                "Server Error ${e.response?.statusCode}: $dataString";
          }
        } else {
          errorMessage = e.message ?? "Unknown error";
        }
        print("Registration Error Details: ${e.response?.data}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isProvider = widget.registrationData['serviceType'] == 'Provider';

    return Scaffold(
      appBar: AppBar(title: const Text('Document Upload'), centerTitle: true),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage('images/bg.jpg'), fit: BoxFit.cover),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      isProvider
                          ? 'Step 4 of 4: Verification'
                          : 'Step 4 of 4: Verification',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Upload Required Documents',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Certificate Image Upload
                    _buildDocumentUploadSection(
                      title: "1. Certificate Image",
                      description:
                          "Upload a clear photo of your graduation certificate",
                      image: graduationCertificate,
                      imageType: 'Graduation',
                    ),

                    // Certification Name Input
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: TextField(
                        controller: certificationNameController,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText:
                              "Certification Name (e.g. Bachelor of Science)",
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          prefixIcon:
                              const Icon(Icons.school, color: Colors.white),
                        ),
                      ),
                    ),

                    // Face Image Upload
                    _buildDocumentUploadSection(
                      title: "2. Face Image",
                      description:
                          "Take a photo of your face (no uploads from gallery)",
                      image: faceImage,
                      imageType: 'Face',
                      cameraOnly: true,
                    ),

                    // ID Card Front Upload
                    _buildDocumentUploadSection(
                      title: "3. ID Card Front",
                      description: "Upload the front side of your ID card",
                      image: personalIdCardFront,
                      imageType: 'ID_Front',
                    ),

                    // ID Card Back Upload
                    _buildDocumentUploadSection(
                      title: "4. ID Card Back",
                      description: "Upload the back side of your ID card",
                      image: personalIdCardBack,
                      imageType: 'ID_Back',
                    ),

                    // Manual ID Input Field (Always detected or manual)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: TextField(
                        controller: idNumberController,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "National ID Number (14 Digits)",
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          prefixIcon:
                              const Icon(Icons.badge, color: Colors.white),
                        ),
                      ),
                    ),

                    if (isProvider) ...[
                      const SizedBox(height: 20),
                      const Text(
                        "Additional Details (Optional)",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: additionalDetailsController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          hintText: "Any other details...",
                          hintStyle: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _submitAllDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Submit & Create Account',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDocumentUploadSection({
    required String title,
    required String description,
    required File? image,
    required String imageType,
    bool cameraOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: () => _pickImage(imageType, cameraOnly: cameraOnly),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  image: image != null
                      ? DecorationImage(
                          image: FileImage(image), fit: BoxFit.cover)
                      : null,
                ),
                child: image == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                          Text("Upload", style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : null,
              ),
            ),
            if (image != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeImage(imageType),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
