import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarek_proj/presentation/screens/services/SearchService.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchServices3 extends StatefulWidget {
  final Map<String, String> addressDetails;
  const SearchServices3({super.key, required this.addressDetails});

  @override
  _SearchServices3State createState() => _SearchServices3State();
}

class _SearchServices3State extends State<SearchServices3> {
  String? selectedTransportation;
  final TextEditingController numberOfVehiclesController =
      TextEditingController();
  final TextEditingController vehicleNameController = TextEditingController();
  final TextEditingController vehicleColorController = TextEditingController();
  final TextEditingController additionalDetailsController =
      TextEditingController();

  File? faceImage,
      graduationCertificate,
      personalIdCardFront,
      personalIdCardBack;
  String? extractedIDNumber;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    numberOfVehiclesController.dispose();
    vehicleNameController.dispose();
    vehicleColorController.dispose();
    additionalDetailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String imageType) async {
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
      setState(() {
        File image = File(pickedFile.path);
        if (imageType == 'Face') {
          faceImage = image;
        } else if (imageType == 'Graduation') {
          graduationCertificate = image;
        } else if (imageType == 'ID_Front') {
          personalIdCardFront = image;
          _scanText(image); // Scan ID card text
        } else if (imageType == 'ID_Back') {
          personalIdCardBack = image;
        }
      });
    }
  }

  Future<void> _scanText(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final InputImage inputImage = InputImage.fromFile(imageFile);

    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    // Extract ID number (assuming it's 10-14 digits long)
    final RegExp idNumberRegex = RegExp(r'\b\d{10,14}\b');
    final List<String> possibleIDNumbers = idNumberRegex
        .allMatches(recognizedText.text)
        .map((match) => match.group(0)!)
        .toList();

    setState(() => extractedIDNumber = possibleIDNumbers.isNotEmpty
        ? possibleIDNumbers.first
        : "No ID Number Found");

    textRecognizer.close();
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

  Future<String?> _uploadImage(File image, String folderName) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$folderName/$fileName';

      // Upload to Supabase Storage bucket 'provider-documents'
      await Supabase.instance.client.storage
          .from('provider-documents')
          .upload(path, image);

      // Get the public URL
      final imageUrl = Supabase.instance.client.storage
          .from('provider-documents')
          .getPublicUrl(path);

      return imageUrl;
    } catch (e) {
      print("Error uploading image to Supabase: $e");
      return null;
    }
  }

  Future<void> _submitDetails() async {
    if (faceImage == null ||
        graduationCertificate == null ||
        personalIdCardFront == null ||
        personalIdCardBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required images')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Upload Images
      print("Starting face image upload...");
      String? faceUrl = await _uploadImage(faceImage!, 'face_images');

      print("Starting certificate upload...");
      String? certUrl =
          await _uploadImage(graduationCertificate!, 'certificates');

      print("Starting ID front upload...");
      String? idFrontUrl =
          await _uploadImage(personalIdCardFront!, 'id_cards_front');

      print("Starting ID back upload...");
      String? idBackUrl =
          await _uploadImage(personalIdCardBack!, 'id_cards_back');

      if (faceUrl == null ||
          certUrl == null ||
          idFrontUrl == null ||
          idBackUrl == null) {
        throw Exception("Failed to upload one or more images");
      }

      print("All images uploaded. Updating Firestore...");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isSeeker': true,
        'isProvider': false,
        'seekerDetails': {
          'faceImageUrl': faceUrl,
          'certificateImageUrl': certUrl,
          'idCardFrontUrl': idFrontUrl,
          'idCardBackUrl': idBackUrl,
          'extractedIDNumber': extractedIDNumber,
          'addressDetails': widget.addressDetails,
          'submittedAt': FieldValue.serverTimestamp(),
        }
      });

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const VerifyEmailPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Text(
                '3 out of 3',
                style: TextStyle(
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
                description: "Upload a clear photo of your certificate",
                image: graduationCertificate,
                imageType: 'Graduation',
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

              if (extractedIDNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    "Extracted ID Number: $extractedIDNumber",
                    style: const TextStyle(
                        fontSize: 18,
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _submitDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
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
              onTap: () => cameraOnly
                  ? _pickImageFromCameraOnly(imageType)
                  : _pickImage(imageType),
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

  Future<void> _pickImageFromCameraOnly(String imageType) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    _setImage(imageType, pickedFile);
  }
}
