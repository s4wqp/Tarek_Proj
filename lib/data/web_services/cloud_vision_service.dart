import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Free OCR service using OCR.space API.
/// - 25,000 free requests/month
/// - Supports Arabic language
/// - No billing/credit card needed
/// Get free API key at: https://ocr.space/ocrapi/freekey
class CloudVisionService {
  // Test key for development. Get your own free key (no credit card):
  // https://ocr.space/ocrapi/freekey (just enter email)
  static const String _apiKey = 'K88039721588957';
  static const String _endpoint = 'https://api.ocr.space/parse/image';

  final Dio _dio = Dio();

  /// Detects text from an image file using OCR.space API.
  /// Tries Engine 1 with Arabic, then Engine 2 as fallback.
  Future<String?> detectText(File imageFile,
      {int engine = 1, String language = 'ara'}) async {
    try {
      File fileToUpload = imageFile;

      // The free tier of OCR.space strictly limits uploads to 1024 KB.
      // Phone cameras take photos that are 3-10MB, so we MUST compress them first.
      int fileSize = await imageFile.length();
      if (fileSize > 900000) {
        // If > 900KB
        final filePath = imageFile.absolute.path;
        final lastIndex = filePath.lastIndexOf(RegExp(r'\.'));
        final ext = lastIndex == -1 ? '.jpg' : filePath.substring(lastIndex);
        final name =
            lastIndex == -1 ? filePath : filePath.substring(0, lastIndex);
        final outPath =
            "${name}_compressed_${DateTime.now().millisecondsSinceEpoch}$ext";

        print(
            "Compressing image from ${fileSize / 1024 / 1024} MB to meet OCR API limits...");
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          outPath,
          quality: 85,
          minWidth: 1920,
          minHeight: 1920,
        );

        if (compressedFile != null) {
          fileToUpload = File(compressedFile.path);
          int newSize = await fileToUpload.length();
          print("Compressed down to ${newSize / 1024} KB.");
        }
      }

      final Map<String, dynamic> formFields = {
        'apikey': _apiKey,
        'file': await MultipartFile.fromFile(fileToUpload.path),
        'isOverlayRequired': 'false',
        'detectOrientation': 'true',
        'scale': 'true',
        'OCREngine': '$engine',
      };

      // Engine 1 supports language param; Engine 2 auto-detects
      if (engine == 1) {
        formFields['language'] = language;
      }

      final formData = FormData.fromMap(formFields);

      final response = await _dio.post(
        _endpoint,
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is Map && data['ParsedResults'] != null) {
          final results = data['ParsedResults'] as List;
          if (results.isNotEmpty) {
            String fullText = results[0]['ParsedText'] ?? '';
            print("OCR.space Engine$engine raw text: $fullText");
            return fullText;
          }
        }

        // Check for errors
        if (data is Map && data['ErrorMessage'] != null) {
          final errors = data['ErrorMessage'] as List?;
          if (errors != null && errors.isNotEmpty) {
            String errMsg = "ERROR: ${errors.join(', ')}";
            print("OCR.space Engine$engine Error: $errMsg");
            return errMsg;
          }
        }
      }

      return "ERROR: Status ${response.statusCode}";
    } on DioException catch (e) {
      String err =
          "ERROR: DioException ${e.response?.statusCode} - ${e.response?.data ?? e.message}";
      print("OCR.space Engine$engine API Error: $err");
      return err;
    } catch (e) {
      String err = "ERROR: Exception $e";
      print("OCR.space Engine$engine Error: $err");
      return err;
    }
  }

  /// Detects text and extracts a 14-digit Egyptian National ID number.
  /// Tries Engine 1 (Arabic), then Engine 2, then Engine 1 (English).
  Future<String?> extractNationalId(File imageFile) async {
    // Try Engine 1 with Arabic
    String? rawText = await detectText(imageFile, engine: 1, language: 'ara');
    if (rawText != null && rawText.startsWith("ERROR:")) return rawText;

    String? bestId = _tryExtractFromRaw(rawText, "Engine1-Arabic");

    if (bestId != null && bestId.length == 14) return bestId;

    // Try Engine 2 (auto-detect, better for printed text)
    String? rawText2 = await detectText(imageFile, engine: 2);
    if (rawText2 != null && rawText2.startsWith("ERROR:")) return rawText2;
    String? id2 = _tryExtractFromRaw(rawText2, "Engine2");
    if (id2 != null) {
      if (bestId == null || id2.length > bestId.length) bestId = id2;
      if (bestId.length == 14) return bestId;
    }

    // Try Engine 1 with English (sometimes numbers are in Latin)
    String? rawText3 = await detectText(imageFile, engine: 1, language: 'eng');
    String? id3 = _tryExtractFromRaw(rawText3, "Engine1-English");
    if (id3 != null && id3.length == 14) {
      if (bestId == null || id3.length > bestId.length) bestId = id3;
    }

    if (bestId != null && bestId.length != 14) {
      bestId =
          null; // Only ever return exactly 14 digits to prevent garbage fills.
    }

    return bestId;
  }

  /// Attempts to extract national ID from raw OCR text
  String? _tryExtractFromRaw(String? rawText, String label) {
    if (rawText == null || rawText.isEmpty) {
      print("OCR.space $label: No text returned");
      return null;
    }

    String converted = _convertArabicNumerals(rawText);
    print("OCR.space $label converted text: $converted");

    return _findNationalId(converted);
  }

  /// Converts Eastern Arabic (U+0660-0669) and Extended Arabic-Indic
  /// (U+06F0-06F9) numerals to Western digits (0-9).
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

  /// Finds the best national ID candidate from normalized text.
  String? _findNationalId(String text) {
    // 1. First, try to find a cleanly separated 14-digit Egyptian ID with optional spacing.
    final RegExp egyptianIdRegex =
        RegExp(r'(?<!\d)[23](?:[\s\.-]*\d){13}(?!\d)');
    for (final match in egyptianIdRegex.allMatches(text)) {
      String cleanDigits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (cleanDigits.length == 14) return cleanDigits;
    }

    // 2. The OCR often fragments the ID or adds excessive spacing/newlines.
    // By extracting ALL digits from the text into a single string, we bypass formatting issues.
    String allDigits = text.replaceAll(RegExp(r'\D'), '');

    // Valid Egyptian ID format:
    // [2 or 3] (Century)
    // \d{2} (Year)
    // (0[1-9]|1[0-2]) (Month 01-12)
    // (0[1-9]|[12]\d|3[01]) (Day 01-31)
    // \d{7} (Governorate code + sequence + check digit)
    final RegExp validIdPattern =
        RegExp(r'[23]\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{7}');

    for (final match in validIdPattern.allMatches(allDigits)) {
      String candidate = match.group(0)!;
      if (candidate.length == 14) {
        print(
            "OCR.space found Egyptian ID via all-digits concatenation: $candidate");
        return candidate;
      }
    }

    // 3. If no perfect match was found, return null to prevent garbage ID population.
    return null;
  }
}
