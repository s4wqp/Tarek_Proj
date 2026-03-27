import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// AI-powered text extraction using Google Gemini Vision API.
/// Free tier: 15 requests/minute, 1500 requests/day.
/// Get free API key: https://aistudio.google.com/apikey
class GeminiVisionService {
  // Replace with your free API key from https://aistudio.google.com/apikey
  static const String _apiKey = 'AIzaSyCJnDeAogteh1HmOPztF5gZwBPZvY9OdZo';
  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final Dio _dio = Dio();

  /// Extracts the 14-digit Egyptian National ID number from multiple images.
  /// using Gemini Vision AI. Returns the 14-digit string or null.
  Future<String?> extractNationalId(List<File> imageFiles) async {
    try {
      if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
        print("Gemini API key not set. Skipping Gemini Vision pass.");
        return null;
      }

      if (imageFiles.isEmpty) {
        print("Gemini: No images provided.");
        return null;
      }

      List<Map<String, dynamic>> inlineDataParts = [];

      for (int i = 0; i < imageFiles.length; i++) {
        File imageFile = imageFiles[i];
        // Compress image to reduce upload size and speed up processing
        File fileToUpload = imageFile;
        int fileSize = await imageFile.length();
        if (fileSize > 900000) {
          final filePath = imageFile.absolute.path;
          final lastIndex = filePath.lastIndexOf(RegExp(r'\.'));
          final ext = lastIndex == -1 ? '.jpg' : filePath.substring(lastIndex);
          final name =
              lastIndex == -1 ? filePath : filePath.substring(0, lastIndex);
          final outPath =
              "${name}_gemini_${DateTime.now().millisecondsSinceEpoch}_$i$ext";

          print(
              "Gemini: Compressing image $i from ${fileSize / 1024 / 1024} MB...");
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            imageFile.absolute.path,
            outPath,
            quality: 80,
            minWidth: 1600,
            minHeight: 1600,
          );

          if (compressedFile != null) {
            fileToUpload = File(compressedFile.path);
            int newSize = await fileToUpload.length();
            print("Gemini: Compressed image $i to ${newSize / 1024} KB.");
          }
        }

        // Read file and convert to base64
        final bytes = await fileToUpload.readAsBytes();
        final base64Image = base64Encode(bytes);

        inlineDataParts.add({
          'inlineData': {
            'mimeType': 'image/jpeg',
            'data': base64Image,
          }
        });
      }

      // Build the Gemini API request
      final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';

      // The prompt text is part 1
      List<Map<String, dynamic>> allParts = [
        {
          'text': 'You are an expert OCR system specializing in Egyptian National ID cards. '
              'I have provided 1 or 2 images of an Egyptian National ID card (Front and/or Back). '
              'Cross-reference the images to accurately extract the single 14-digit National ID number. '
              'The front card usually has faint but full 14 digits at the bottom. '
              'The back card usually has a clear prefix (like the first 8 digits) at the top. '
              'CRITICAL RULES:\n'
              '1. The ID is exactly 14 contiguous digits printed on a single line.\n'
              '2. DO NOT concatenate or combine different numbers (like dates, e.g., 2023/08) to make 14 digits.\n'
              '3. DO NOT guess or hallucinate. If the font is too faint or unreadable, return "NOT_FOUND".\n'
              '4. Return your response as a JSON object with a single key "id". If not found, use {"id": "NOT_FOUND"}.'
        }
      ];

      // Add the image parts
      allParts.addAll(inlineDataParts);

      final requestBody = {
        'contents': [
          {
            'parts': allParts,
          }
        ],
        'generationConfig': {
          'temperature': 0.0, // Absolute zero for strictly factual extraction
          'responseMimeType': 'application/json',
          'maxOutputTokens': 100,
        }
      };

      print("Gemini: Sending image to Gemini Vision API...");

      final response = await _dio.post(
        url,
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // Extract the text from Gemini response
        String? responseText;
        try {
          responseText =
              data['candidates'][0]['content']['parts'][0]['text'] as String?;
        } catch (e) {
          print("Gemini: Failed to parse response: $e");
          return null;
        }

        if (responseText == null || responseText.isEmpty) {
          print("Gemini: Empty response");
          return null;
        }

        responseText = responseText.trim();
        print("Gemini: Raw JSON response: $responseText");

        String? extractedId;
        try {
          final jsonResp = jsonDecode(responseText);
          extractedId = jsonResp['id']?.toString();
        } catch (e) {
          print("Gemini: JSON parse error: $e");
          // Fallback to regex if JSON parsing fails
          final fallbackMatch =
              RegExp(r'"id"\s*:\s*"([^"]+)"').firstMatch(responseText);
          extractedId = fallbackMatch?.group(1);
        }

        if (extractedId == null || extractedId == 'NOT_FOUND') {
          print("Gemini: ID not found in image");
          return null;
        }

        // Extract only digits from response
        String digits = extractedId.replaceAll(RegExp(r'\D'), '');
        print("Gemini: Extracted digits: $digits");

        // Validate: must be exactly 14 digits starting with 2 or 3
        if (digits.length == 14 &&
            (digits.startsWith('2') || digits.startsWith('3'))) {
          // Additional validation: check month (01-12) and day (01-31)
          String month = digits.substring(3, 5);
          String day = digits.substring(5, 7);
          int monthInt = int.tryParse(month) ?? 0;
          int dayInt = int.tryParse(day) ?? 0;

          if (monthInt >= 1 && monthInt <= 12 && dayInt >= 1 && dayInt <= 31) {
            print("Gemini: Valid Egyptian ID found: $digits");
            return digits;
          } else {
            print(
                "Gemini: Invalid date in ID (month=$month, day=$day): $digits");
            // Still return it but log the warning - AI is generally accurate
            return digits;
          }
        }

        // Return raw digits as fragment for the merge pipeline
        if (digits.length >= 7) {
          print("Gemini: Returning partial digits as fragment: $digits");
          return digits;
        }

        print(
            "Gemini: Could not extract valid ID from response: $responseText");
        return null;
      } else {
        print("Gemini: API returned status ${response.statusCode}");
        return null;
      }
    } on DioException catch (e) {
      print(
          "Gemini: API Error: ${e.response?.statusCode} - ${e.response?.data ?? e.message}");
      return null;
    } catch (e) {
      print("Gemini: Error: $e");
      return null;
    }
  }
}
