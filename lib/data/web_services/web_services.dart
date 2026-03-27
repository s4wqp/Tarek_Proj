import 'package:dio/dio.dart';
import 'dart:io';
import 'dio_factory.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class WebServices {
  late Dio dio;

  WebServices() {
    dio = DioFactory.getDio();
  }

  Future<List<dynamic>> getAllPosts() async {
    try {
      Response response = await dio.get('posts');
      return response.data;
    } catch (e) {
      print(e.toString());
      return [];
    }
  }

  // Example of sending data
  Future<Response> createPost(Map<String, dynamic> postData) async {
    try {
      Response response = await dio.post('posts', data: postData);
      return response;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  Future<File> _compressFile(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      String splitted = filePath;
      if (lastIndex != -1) {
        splitted = filePath.substring(0, lastIndex);
      }
      final outPath =
          "${splitted}_out${DateTime.now().millisecondsSinceEpoch}.jpg";

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 20, // Aggressive compression to prevent PHP memory exhaustion
        minWidth: 400, // Drastically reduced dimensions
        minHeight: 400, // Drastically reduced dimensions
        format: CompressFormat.jpeg,
      );

      print('Original size: ${file.lengthSync()}');
      if (result != null) {
        File compressedFile = File(result.path);
        print('Compressed size: ${compressedFile.lengthSync()}');
        return compressedFile;
      } else {
        print('Compression returned null, using original file!');
      }
      return file;
    } catch (e) {
      print("Compression error: $e");
      return file;
    }
  }

  Future<Response> registerUser(
      Map<String, dynamic> data, Map<String, File> files) async {
    try {
      // 1. Sanitize Data: Remove nulls and convert generic types to String where appropriate
      // This prevents "null" string being sent or backend crashing on unexpected types
      Map<String, dynamic> sanitizedData = {};
      data.forEach((key, value) {
        if (value != null && value != "") {
          sanitizedData[key] = value;
        }
      });

      FormData formData = FormData.fromMap(sanitizedData);

      for (var entry in files.entries) {
        String key = entry.key;
        File file = entry.value;

        // Compress image
        File compressedFile = await _compressFile(file);

        // Use minimal filename length (e.g., "1.jpg", "2.jpg") to avoid DB limit
        // The previous attempt (key.ext) resulted in ~17 chars which was too long for 'user_id_photo' column.
        int index = files.keys.toList().indexOf(key);
        String ext = compressedFile.path.split('.').last; // Should be jpg now
        if (ext.length > 4) ext = 'jpg';
        String fileName = "${index + 1}.$ext";

        print(
            "DEBUG: Adding file field: '$key' with filename: '$fileName'"); // DEBUG LOG

        formData.files.add(MapEntry(
          key,
          await MultipartFile.fromFile(compressedFile.path, filename: fileName),
        ));
      }

      // Explicitly remove content-type so Dio generates the correct boundary for Multipart
      dio.options.headers.remove('Content-Type');

      Response response = await dio.post('users', data: formData);

      // Restore JSON content type for other requests
      dio.options.headers['Content-Type'] = 'application/json';

      return response;
    } catch (e) {
      print("Register User Error: $e");
      // Ensure header is restored even on error
      dio.options.headers['Content-Type'] = 'application/json';
      rethrow;
    }
  }

  Future<List<dynamic>> getAllSponsors() async {
    try {
      Response response = await dio.get('sponsors');
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'];
        } else if (response.data is List) {
          return response.data;
        }
      }
      return [];
    } catch (e) {
      print("Get Sponsors Error: $e");
      return [];
    }
  }

  Future<Response> addSponsor(
      Map<String, dynamic> data, List<File> images) async {
    // List of files to cleanup
    List<File> processedFiles = [];

    try {
      FormData formData = FormData.fromMap(data);

      for (int i = 0; i < images.length; i++) {
        if (i >= 3) break;
        final file = images[i];

        // Compress image
        File compressedFile = await _compressFile(file);
        processedFiles.add(compressedFile); // Keep track to maybe delete later?

        final fileName = compressedFile.path.split('/').last;
        final String key = "imag${i + 1}_photo";

        formData.files.add(MapEntry(
          key,
          await MultipartFile.fromFile(compressedFile.path, filename: fileName),
        ));
      }

      // Try plural 'sponsors'
      try {
        Response response = await dio.post('sponsors', data: formData);
        return response;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          print("404 on 'sponsors', trying 'sponsor'...");
          // You cannot reuse FormData! It gets closed/read. We must recreate it.

          FormData retryFormData = FormData.fromMap(data);
          for (int i = 0; i < processedFiles.length; i++) {
            // Reuse compressed files
            File file = processedFiles[i];
            final fileName = file.path.split('/').last;
            final String key = "imag${i + 1}_photo";
            retryFormData.files.add(MapEntry(
              key,
              await MultipartFile.fromFile(file.path, filename: fileName),
            ));
          }

          Response retryResponse =
              await dio.post('sponsor', data: retryFormData);
          return retryResponse;
        }
        rethrow;
      }
    } catch (e) {
      print("Add Sponsor Error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      // 1. Authenticate as admin using exact backend instructions
      String token = "";
      try {
        Response loginResp = await Dio().post(
            'http://161.35.51.188:5001/api/auth/login',
            data: {"uname": "ts2025", "password": "123456"});

        if (loginResp.statusCode == 200 && loginResp.data != null) {
          token =
              loginResp.data['token'] ?? loginResp.data['accessToken'] ?? "";
        }
      } catch (e) {
        print("Admin Login Error: $e");
        return null; // Stop if we can't get a token
      }

      if (token.isEmpty) {
        print("Error: No admin token received.");
        return null;
      }

      // 2. Fetch users using the Bearer token from the exact URL
      Response response = await Dio().get(
        'http://161.35.51.188:5001/api/users',
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );
      List<dynamic> users = [];

      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          users = response.data['data'];
        } else if (response.data is List) {
          users = response.data;
        }

        // Filter valid user maps
        final validUsers = users.where((element) => element is Map).toList();

        // Find user by email
        // Case-insensitive email comparison is usually safer
        final user = validUsers.firstWhere(
            (u) =>
                (u['email'] as String? ?? u['user_email'] as String?)
                    ?.toLowerCase() ==
                email.toLowerCase(),
            orElse: () => null);

        if (user != null) {
          // ensure 'statu' contains the status (the dev's json showed "status": 2 instead of "statu")
          if (user.containsKey('status')) {
            user['statu'] = user['status'];
          }
          return user as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get User By Email Error: $e");
      return null;
    }
  }
}
