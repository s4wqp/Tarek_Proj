import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:tarek_proj/utils/egyptian_license_plate_crop.dart';
import 'package:tarek_proj/utils/egyptian_vehicle_plate.dart';
import 'package:tarek_proj/config/app_secrets.dart';

/// AI-powered text extraction using Google Gemini Vision API.
/// Free tier: 15 requests/minute, 1500 requests/day.
/// Get free API key: https://aistudio.google.com/apikey
class GeminiVisionService {
  // Replace with your free API key from https://aistudio.google.com/apikey
  static const String _apiKey = AppSecrets.geminiApiKey;

  /// Primary model for national ID extraction.
  static const String _model = 'gemini-2.0-flash';

  /// Vehicle license: try **1.5** first — many keys have `limit: 0` on 2.0-flash only; quotas are per-model.
  static const List<String> _vehicleLicenseModelFallbacks = [
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
    'gemini-2.0-flash',
  ];
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final Dio _dio = Dio();

  /// Whether to try another model (429, timeouts) vs stop (bad key / bad request).
  static bool _shouldTryNextGeminiModel(int? code) {
    if (code == null) return true;
    if (code == 401 || code == 403 || code == 400) return false;
    return code == 429 ||
        code == 404 ||
        code == 503 ||
        code == 408 ||
        code >= 500;
  }

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
      const url = '$_baseUrl/$_model:generateContent?key=$_apiKey';

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

  /// Reads an Egyptian vehicle registration card (رخصة / تصريح تسيير) and returns
  /// structured fields. Used when ML Kit + OCR.space miss Arabic layout.
  ///
  /// Keys: [plate], [expiry_date] (YYYY-MM-DD), [license_number], [color].
  /// Missing values are omitted or set to null.
  Future<Map<String, String?>?> extractEgyptianVehicleLicense(
      File imageFile) async {
    File? plateCropFile;
    try {
      if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
        print('Gemini: API key not set; skip vehicle license.');
        return null;
      }

      File fileToUpload = imageFile;
      final fileSize = await imageFile.length();
      if (fileSize > 900000) {
        final filePath = imageFile.absolute.path;
        final lastIndex = filePath.lastIndexOf(RegExp(r'\.'));
        final ext = lastIndex == -1 ? '.jpg' : filePath.substring(lastIndex);
        final name =
            lastIndex == -1 ? filePath : filePath.substring(0, lastIndex);
        final outPath =
            '${name}_gemini_vl_${DateTime.now().millisecondsSinceEpoch}$ext';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          outPath,
          quality: 82,
          minWidth: 1600,
          minHeight: 1600,
        );

        if (compressedFile != null) {
          fileToUpload = File(compressedFile.path);
        }
      }

      final bytes = await fileToUpload.readAsBytes();
      final base64Full = base64Encode(bytes);

      try {
        plateCropFile = await cropTasreehPlateBand(fileToUpload);
      } catch (_) {
        plateCropFile = null;
      }
      final String? base64Crop = plateCropFile != null
          ? base64Encode(await plateCropFile.readAsBytes())
          : null;

      final prompt = base64Crop != null
          ? 'You receive TWO images of the same Egyptian vehicle document (تصريح تسيير / رخصة / tasreeh).\n'
              'IMAGE 1 (first): a CROP of the UPPER area showing ONLY the plate row — one horizontal strip of separate square boxes (Arabic letters + Arabic-Indic or Western digits). '
              'THIS IMAGE IS THE ONLY SOURCE FOR THE "plate" FIELD. Ignore dates, names, governorate text, and barcodes here.\n'
              'IMAGE 2 (second): the FULL card. Use ONLY this image for expiry_date, license_number, and color.\n\n'
              'Rules for "plate" (from IMAGE 1 only):\n'
              '- Locate the row of small boxes. Typically 3–4 digit boxes and 2–3 Arabic letter boxes.\n'
              '- Output format: first the numeric part as Western digits 0-9 in left-to-right order as printed in the digit boxes, '
              'then one space, then each Arabic letter separated by a single space in left-to-right order as printed in the letter boxes (e.g. digits ٧٢٩١ and letters ف د ل → "7291 ف د ل").\n'
              '- Do NOT read digits from the permit date lines (نهاية التصريح / تاريخ التحرير). Do NOT use owner names.\n'
              '- If the plate boxes are unreadable, set "plate" to null.\n\n'
              'Rules for other fields (from IMAGE 2 only):\n'
              '- "expiry_date": date next to نهاية التصريح or نهاية الترخيص, as YYYY-MM-DD (Western digits). NOT تاريخ التحرير.\n'
              '- "license_number": long document number if visible, digits preferred.\n'
              '- "color": vehicle color in Arabic if explicitly written.\n\n'
              'Return JSON only with keys: plate, expiry_date, license_number, color (use null strings if unreadable). '
              'If the document is not a vehicle license, return all null.'
          : 'You are reading ONE photo of an Egyptian vehicle license / traffic registration card (Arabic). '
              'Extract only what you clearly see. Do not guess.\n'
              'Return JSON only with these keys (use null string if unreadable):\n'
              '- "plate": Find the horizontal row of small boxes (plate). Read digits in left-to-right box order as Western digits, '
              'then Arabic letters in left-to-right box order, each letter separated by a SINGLE space. Example: ٧٢٩١ + ف د ل → "7291 ف د ل". '
              'Ignore dates, names, and barcodes.\n'
              '- "expiry_date": next to نهاية التصريح or نهاية الترخيص, YYYY-MM-DD. NOT تاريخ التحرير.\n'
              '- "license_number": long document number if visible.\n'
              '- "color": vehicle color in Arabic if written.\n'
              'If the image is not a vehicle license, return all keys as null.';

      final List<Map<String, dynamic>> parts = [
        {'text': prompt},
        if (base64Crop != null)
          {
            'inlineData': {'mimeType': 'image/jpeg', 'data': base64Crop}
          },
        {
          'inlineData': {'mimeType': 'image/jpeg', 'data': base64Full}
        },
      ];

      final requestBody = {
        'contents': [
          {
            'parts': parts,
          }
        ],
        'generationConfig': {
          'temperature': 0.0,
          'responseMimeType': 'application/json',
          'maxOutputTokens': 384,
        }
      };

      print(
          'Gemini: vehicle license extraction (${_vehicleLicenseModelFallbacks.length} models)…');

      for (var i = 0; i < _vehicleLicenseModelFallbacks.length; i++) {
        final model = _vehicleLicenseModelFallbacks[i];
        print('Gemini VL: request → $model');
        final url = '$_baseUrl/$model:generateContent?key=$_apiKey';
        try {
          final response = await _dio.post(
            url,
            data: requestBody,
            options: Options(
              headers: {'Content-Type': 'application/json'},
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 45),
            ),
          );

          if (response.statusCode != 200) {
            print('Gemini VL: HTTP ${response.statusCode} ($model)');
            continue;
          }

          final data = response.data;
          String? responseText;
          try {
            responseText =
                data['candidates'][0]['content']['parts'][0]['text'] as String?;
          } catch (e) {
            print('Gemini VL: parse response: $e ($model)');
            continue;
          }

          if (responseText == null || responseText.trim().isEmpty) continue;
          responseText = responseText.trim();
          print('Gemini VL raw ($model): $responseText');

          Map<String, dynamic>? jsonResp;
          try {
            jsonResp = jsonDecode(responseText) as Map<String, dynamic>?;
          } catch (_) {
            final m = RegExp(r'\{[^{}]+\}').firstMatch(responseText);
            if (m != null) {
              try {
                jsonResp = jsonDecode(m.group(0)!) as Map<String, dynamic>?;
              } catch (_) {}
            }
          }

          if (jsonResp == null) continue;
          final map = jsonResp;

          String? pick(String k) {
            final v = map[k];
            if (v == null) return null;
            final s = v.toString().trim();
            if (s.isEmpty ||
                s == 'null' ||
                s == 'NOT_FOUND' ||
                s.toUpperCase() == 'NULL') {
              return null;
            }
            return s;
          }

          final rawPlate = pick('plate');
          final plateOk = EgyptianVehiclePlate.acceptOrNull(rawPlate);
          if (rawPlate != null && plateOk == null) {
            print('Gemini VL: plate rejected by validator: $rawPlate');
          }

          return {
            'plate': plateOk,
            'expiry_date': pick('expiry_date'),
            'license_number': pick('license_number'),
            'color': pick('color'),
          };
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          print('Gemini VL: $code ${e.response?.data ?? e.message} ($model)');
          final hasNext = i < _vehicleLicenseModelFallbacks.length - 1;
          if (hasNext && _shouldTryNextGeminiModel(code)) {
            print('Gemini VL: trying next model…');
            continue;
          }
          return null;
        }
      }
      return null;
    } on DioException catch (e) {
      print(
          'Gemini VL: ${e.response?.statusCode} ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      print('Gemini VL error: $e');
      return null;
    } finally {
      if (plateCropFile != null && plateCropFile.existsSync()) {
        try {
          plateCropFile.deleteSync();
        } catch (_) {}
      }
    }
  }
}
