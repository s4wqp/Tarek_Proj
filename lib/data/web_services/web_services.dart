import 'package:dio/dio.dart';
import 'dart:io';
import 'dio_factory.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    Map<String, dynamic> data,
    Map<String, File> files,
  ) async {
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
          "DEBUG: Adding file field: '$key' with filename: '$fileName'",
        ); // DEBUG LOG

        formData.files.add(
          MapEntry(
            key,
            await MultipartFile.fromFile(
              compressedFile.path,
              filename: fileName,
            ),
          ),
        );
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

  // =============================================
  //  SPONSOR APIs (15 Endpoints)
  // =============================================

  // ------------------------------------
  //  Public APIs
  // ------------------------------------

  /// 1. GET /api/sponsors/categories — Get sponsor categories (Public, no auth)
  Future<List<dynamic>> getSponsorCategories() async {
    try {
      Response response = await dio.get('sponsors/categories');
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'];
        } else if (response.data is List) {
          return response.data;
        }
      }
      return [];
    } catch (e) {
      print("Get Sponsor Categories Error: $e");
      return [];
    }
  }

  /// POST /api/sponsors/register — Register as a sponsor
  /// The /register endpoint uses JSON body parsing (not multipart FormData).
  /// POST /api/sponsors does NOT exist (404). Only /register works.
  /// Images are uploaded in a separate multipart call after registration.
  Future<Response> registerSponsor(
    Map<String, dynamic> data,
    List<File> images,
    String token,
  ) async {
    try {
      // Debug: log what we're sending
      print("DEBUG registerSponsor JSON data: $data");

      // Step 1: Register sponsor with JSON body (no images)
      Response response = await Dio().post(
        'http://161.35.51.188:5001/api/sponsors/register',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      print("DEBUG registerSponsor response status: ${response.statusCode}");
      print("DEBUG registerSponsor response body: ${response.data}");

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Status ${response.statusCode}',
        );
      }

      // Step 2: Upload images separately after successful registration
      for (int i = 0; i < images.length && i < 3; i++) {
        try {
          File compressedFile = await _compressFile(images[i]);
          final fileName = compressedFile.path.split(RegExp(r'[/\\]')).last;
          final String key = "imag${i + 1}_photo";

          FormData imgForm = FormData.fromMap({
            key: await MultipartFile.fromFile(
              compressedFile.path,
              filename: fileName,
            ),
          });

          print("DEBUG uploading sponsor image $key...");
          Response imgResp = await Dio().post(
            'http://161.35.51.188:5001/api/sponsors/my-sponsor/image',
            data: imgForm,
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
              validateStatus: (status) => true,
            ),
          );
          print("DEBUG image upload status: ${imgResp.statusCode}, body: ${imgResp.data}");
        } catch (imgErr) {
          print("Image upload error (non-fatal): $imgErr");
        }
      }

      return response;
    } catch (e) {
      print("Register Sponsor Error: $e");
      rethrow;
    }
  }

  // ------------------------------------
  //  Sponsor APIs (Approved Sponsors — cat_id: 801-809, statu: 2)
  // ------------------------------------

  /// 2. GET /api/sponsors/my-sponsor — Get my sponsor data
  /// Lightweight: tries /my-sponsor only, returns null on failure
  Future<Map<String, dynamic>?> getMySponsorDirect() async {
    try {
      final opts = await _authOptions();
      Response response = await dio.get('sponsors/my-sponsor', options: opts);
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("getMySponsorDirect failed: $e");
      return null;
    }
  }

  /// Full version with fallback chain (heavier, used by callers who don't have user data)
  Future<Map<String, dynamic>?> getMySponsor() async {
    final direct = await getMySponsorDirect();
    if (direct != null) return direct;

    // Fallback: fetch via admin endpoint using user's email -> user ID -> sponsor
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      if (email != null && email.isNotEmpty) {
        final userData = await getUserByEmail(email);
        if (userData != null && userData['id'] != null) {
          final userId = userData['id'];
          return await getSponsorByUserId(userId is int ? userId : int.tryParse(userId.toString()) ?? 0);
        }
      }
    } catch (fallbackError) {
      print("Fallback sponsor fetch also failed: $fallbackError");
    }
    return null;
  }

  /// 3. PUT /api/sponsors/my-sponsor — Update my business info
  Future<Response> updateMySponsor(Map<String, dynamic> data) async {
    try {
      final opts = await _authOptions();
      return await dio.put('sponsors/my-sponsor', data: data, options: opts);
    } catch (e) {
      print("Update My Sponsor Error: $e");
      rethrow;
    }
  }

  /// 4. POST /api/sponsors/my-sponsor/add-image — Upload sponsor image
  Future<Response> addMySponsorImage(File imageFile) async {
    try {
      File compressedFile = await _compressFile(imageFile);

      final fileName = compressedFile.path.split(RegExp(r'[/\\]')).last;
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          compressedFile.path,
          filename: fileName,
        ),
      });

      final opts = await _authOptions();
      opts.headers?.remove('Content-Type');

      Response response = await dio.post(
        'sponsors/my-sponsor/add-image',
        data: formData,
        options: opts,
      );

      return response;
    } catch (e) {
      print("Add My Sponsor Image Error: $e");
      rethrow;
    }
  }

  /// 5-7. DELETE /api/sponsors/my-sponsor/image/{imageField} — Delete a specific image
  /// [imageField] must be one of: 'imag1_photo', 'imag2_photo', 'imag3_photo'
  Future<bool> deleteMySponsorImage(String imageField) async {
    try {
      final opts = await _authOptions();
      Response response = await dio.delete(
        'sponsors/my-sponsor/image/$imageField',
        options: opts,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("Delete My Sponsor Image Error: $e");
      return false;
    }
  }

  // ------------------------------------
  //  Admin APIs (cat_id: 901, 902, 903)
  // ------------------------------------

  /// 8. POST /api/sponsors/user/{user_id} — Create sponsor for a user (Admin)
  Future<Response> createSponsorForUser(
    int userId,
    Map<String, dynamic> data,
    List<File> images,
  ) async {
    try {
      FormData formData = FormData.fromMap(data);

      for (int i = 0; i < images.length; i++) {
        if (i >= 3) break;
        final file = images[i];

        File compressedFile = await _compressFile(file);

        final fileName = compressedFile.path.split(RegExp(r'[/\\]')).last;
        final String key = "imag${i + 1}_photo";

        formData.files.add(
          MapEntry(
            key,
            await MultipartFile.fromFile(
              compressedFile.path,
              filename: fileName,
            ),
          ),
        );
      }

      final opts = await _authOptions();
      opts.headers?.remove('Content-Type');

      Response response = await Dio().post(
        'http://161.35.51.188:5001/api/sponsors/user/$userId',
        data: formData,
        options: opts,
      );

      return response;
    } catch (e) {
      print("Create Sponsor For User Error: $e");
      rethrow;
    }
  }

  /// 9. GET /api/sponsors — Get all sponsors (paginated, Admin)
  Future<List<dynamic>> getAllSponsors({int? page, int? limit}) async {
    try {
      final opts = await _authOptions();
      final Map<String, dynamic> params = {};
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;

      Response response = await dio.get(
        'sponsors',
        queryParameters: params.isNotEmpty ? params : null,
        options: opts,
      );
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

  /// 10. GET /api/sponsors/stats — Get sponsor statistics (Admin)
  Future<Map<String, dynamic>?> getSponsorStats() async {
    try {
      final opts = await _authOptions();
      Response response = await dio.get('sponsors/stats', options: opts);
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Sponsor Stats Error: $e");
      return null;
    }
  }

  /// 11. GET /api/sponsors/search?q={keyword}&field={field} — Search sponsors (Admin)
  Future<List<dynamic>> searchSponsors(String keyword, String field) async {
    try {
      final opts = await _authOptions();
      Response response = await dio.get(
        'sponsors/search',
        queryParameters: {'q': keyword, 'field': field},
        options: opts,
      );
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'];
        } else if (response.data is List) {
          return response.data;
        }
      }
      return [];
    } catch (e) {
      print("Search Sponsors Error: $e");
      return [];
    }
  }

  /// 12. GET /api/sponsors/{id} — Get sponsor by ID (Admin)
  Future<Map<String, dynamic>?> getSponsorById(int id) async {
    try {
      final opts = await _authOptions();
      Response response = await dio.get('sponsors/$id', options: opts);
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Sponsor By ID Error: $e");
      return null;
    }
  }

  /// 13. GET /api/sponsors/user/{userId} — Get sponsor by user ID (Admin)
  Future<Map<String, dynamic>?> getSponsorByUserId(int userId) async {
    try {
      // This endpoint requires admin auth
      String adminToken = "";
      try {
        Response loginResp = await Dio().post(
          'http://161.35.51.188:5001/api/auth/login',
          data: {"user_name": "ts2025", "user_password": "123456"},
          options: Options(contentType: 'application/json'),
        );
        if (loginResp.statusCode == 200 && loginResp.data != null) {
          adminToken = loginResp.data['token'] ?? "";
        }
      } catch (_) {}

      if (adminToken.isEmpty) return null;

      Response response = await Dio().get(
        'http://161.35.51.188:5001/api/sponsors/user/$userId',
        options: Options(headers: {
          "Authorization": "Bearer $adminToken",
          "Content-Type": "application/json",
        }),
      );
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Sponsor By User ID Error: $e");
      return null;
    }
  }

  /// 14. PUT /api/sponsors/{id} — Update sponsor by ID (Admin)
  Future<Response> updateSponsor(
    int id,
    Map<String, dynamic> data,
    List<File> images,
  ) async {
    try {
      FormData formData = FormData.fromMap(data);

      for (int i = 0; i < images.length; i++) {
        if (i >= 3) break;
        final file = images[i];

        File compressedFile = await _compressFile(file);

        final fileName = compressedFile.path.split(RegExp(r'[/\\]')).last;
        final String key = "imag${i + 1}_photo";

        formData.files.add(
          MapEntry(
            key,
            await MultipartFile.fromFile(
              compressedFile.path,
              filename: fileName,
            ),
          ),
        );
      }

      dio.options.headers.remove('Content-Type');

      final opts = await _authOptions();
      opts.headers?.remove('Content-Type');

      Response response = await dio.put(
        'sponsors/$id',
        data: formData,
        options: opts,
      );

      dio.options.headers['Content-Type'] = 'application/json';

      return response;
    } catch (e) {
      dio.options.headers['Content-Type'] = 'application/json';
      print("Update Sponsor Error: $e");
      rethrow;
    }
  }

  /// 15. DELETE /api/sponsors/{id} — Delete sponsor by ID (Admin)
  Future<bool> deleteSponsor(int id) async {
    try {
      final opts = await _authOptions();
      Response response = await dio.delete('sponsors/$id', options: opts);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("Delete Sponsor Error: $e");
      return false;
    }
  }

  /// Legacy helper — admin create sponsor (used by AddSponsorScreen)
  Future<Response> addSponsor(
    Map<String, dynamic> data,
    List<File> images,
  ) async {
    try {
      FormData formData = FormData.fromMap(data);

      for (int i = 0; i < images.length; i++) {
        if (i >= 3) break;
        final file = images[i];

        // Compress image
        File compressedFile = await _compressFile(file);

        final fileName = compressedFile.path.split(RegExp(r'[/\\]')).last;
        final String key = "imag${i + 1}_photo";

        formData.files.add(
          MapEntry(
            key,
            await MultipartFile.fromFile(
              compressedFile.path,
              filename: fileName,
            ),
          ),
        );
      }

      // Use the direct backend URL instead of the nginx proxy
      // (api.aidme.online does not forward POST /sponsors)
      final opts = await _authOptions();
      // Override content-type in options to let Dio handle multipart
      opts.headers?.remove('Content-Type');

      Response response = await Dio().post(
        'http://161.35.51.188:5001/api/sponsors',
        data: formData,
        options: opts,
      );

      return response;
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
          data: {"user_name": "ts2025", "user_password": "123456"},
          options: Options(contentType: 'application/json'),
        );

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
      // Use a large limit to fetch ALL users (default pagination may skip users)
      Response response = await Dio().get(
        'http://161.35.51.188:5001/api/users?limit=10000',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      List<dynamic> users = [];

      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          users = response.data['data'];
        } else if (response.data is List) {
          users = response.data;
        }

        // Filter valid user maps
        final validUsers = users.whereType<Map>().toList();

        // Find user by email
        // Case-insensitive email comparison is usually safer
        final user = validUsers.firstWhere(
          (u) =>
              (u['email'] as String? ?? u['user_email'] as String?)
                  ?.toLowerCase() ==
              email.toLowerCase(),
          orElse: () => {},
        );

        if (user.isNotEmpty) {
          // Fetch Detailed User Info using their ID
          int? userId = user['id'];
          if (userId != null) {
            try {
              Response detailResp = await Dio().get(
                'http://161.35.51.188:5001/api/users/$userId',
                options: Options(headers: {"Authorization": "Bearer $token"}),
              );
              if (detailResp.statusCode == 200 && detailResp.data != null) {
                final detailData = detailResp.data is Map &&
                        detailResp.data.containsKey('data')
                    ? detailResp.data['data']
                    : detailResp.data;
                if (detailData is Map) {
                  if (detailData.containsKey('status')) {
                    detailData['statu'] = detailData['status'];
                  }
                  return detailData as Map<String, dynamic>;
                }
              }
            } catch (e) {
              print("Get User Detail By Email Error: $e");
            }
          }
          // Fallback if detail fetch fails
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

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      // 1. Authenticate as admin
      String token = "";
      try {
        Response loginResp = await Dio().post(
          'http://161.35.51.188:5001/api/auth/login',
          data: {"user_name": "ts2025", "user_password": "123456"},
          options: Options(contentType: 'application/json'),
        );

        if (loginResp.statusCode == 200 && loginResp.data != null) {
          token =
              loginResp.data['token'] ?? loginResp.data['accessToken'] ?? "";
        }
      } catch (e) {
        print("Admin Login Error: $e");
        return null; // Stop if we can't get a token
      }

      if (token.isEmpty) {
        return null;
      }

      // 2. Fetch all users (use large limit to bypass default pagination)
      Response response = await Dio().get(
        'http://161.35.51.188:5001/api/users?limit=10000',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      List<dynamic> users = [];

      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          users = response.data['data'];
        } else if (response.data is List) {
          users = response.data;
        }

        // Filter valid user maps
        final validUsers = users.whereType<Map>().toList();

        // Find user by exact user_name match OR first/last name combination
        for (var u in validUsers) {
          final uName = u['user_name']?.toString();
          final fName = u['user_f_name']?.toString() ?? '';
          final lName = u['user_l_name']?.toString() ?? '';
          final fullName = '$fName $lName'.trim();

          bool isMatch = false;
          if (uName != null && uName.toLowerCase() == username.toLowerCase()) {
            isMatch = true;
          } else if (fullName.isNotEmpty &&
              fullName.toLowerCase() == username.toLowerCase()) {
            isMatch = true;
          }

          if (isMatch) {
            int? userId = u['id'];
            if (userId != null) {
              try {
                Response detailResp = await Dio().get(
                  'http://161.35.51.188:5001/api/users/$userId',
                  options: Options(headers: {"Authorization": "Bearer $token"}),
                );
                if (detailResp.statusCode == 200 && detailResp.data != null) {
                  final detailData = detailResp.data is Map &&
                          detailResp.data.containsKey('data')
                      ? detailResp.data['data']
                      : detailResp.data;
                  if (detailData is Map) {
                    if (detailData.containsKey('status')) {
                      detailData['statu'] = detailData['status'];
                    }
                    return detailData as Map<String, dynamic>;
                  }
                }
              } catch (e) {
                print("Get User Detail By Username Error: $e");
              }
            }
            if (u.containsKey('status')) {
              u['statu'] = u['status'];
            }
            return u as Map<String, dynamic>;
          }
        }
      }
      return null;
    } catch (e) {
      print("Get User By Username Error: $e");
      return null;
    }
  }

  /// Logs in to the backend and returns the JWT token (if successful).
  Future<String?> loginUserForToken(
    String usernameOrEmail,
    String password,
  ) async {
    try {
      Response response = await Dio().post(
        'http://161.35.51.188:5001/api/auth/login',
        data: {"user_name": usernameOrEmail, "user_password": password},
        options: Options(contentType: 'application/json'),
      );

      final token = response.data?['token'] ?? response.data?['accessToken'];
      if (response.statusCode == 200 &&
          token != null &&
          token.toString().isNotEmpty) {
        return token.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> loginUser(String usernameOrEmail, String password) async {
    try {
      final token = await loginUserForToken(usernameOrEmail, password);
      return token != null;
    } catch (e) {
      print("API Login Fallback Error: $e");
      return false;
    }
  }

  // =============================================
  //  STOPS APIs (8 Endpoints)
  // =============================================

  /// 1. GET /api/stops — List all stops with optional filters
  Future<List<dynamic>> getAllStops({
    int? page,
    int? limit,
    String? search,
    String? country,
    String? state,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (country != null && country.isNotEmpty) params['country'] = country;
      if (state != null && state.isNotEmpty) params['state'] = state;

      final opts = await _authOptions();
      final Response response = await dio.get(
        'stops',
        queryParameters: params,
        options: opts,
      );
      final data = response.data;

      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      print("Get Stops Error: $e");
      return [];
    }
  }

  /// 2. GET /api/stops/:id — Get a single stop
  Future<Map<String, dynamic>?> getStopById(int id) async {
    try {
      final Response response = await dio.get('stops/$id');
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Stop By ID Error: $e");
      return null;
    }
  }

  /// 3. POST /api/stops — Create a new stop
  Future<Response> createStop(Map<String, dynamic> data) async {
    try {
      final opts = await _authOptions();
      return await dio.post('stops', data: data, options: opts);
    } catch (e) {
      print("Create Stop Error: $e");
      rethrow;
    }
  }

  /// 4. PUT /api/stops/:id — Update a stop
  Future<Response> updateStop(int id, Map<String, dynamic> data) async {
    try {
      return await dio.put('stops/$id', data: data);
    } catch (e) {
      print("Update Stop Error: $e");
      rethrow;
    }
  }

  /// 5. DELETE /api/stops/:id — Delete a stop
  Future<bool> deleteStop(int id) async {
    try {
      final Response response = await dio.delete('stops/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("Delete Stop Error: $e");
      return false;
    }
  }

  /// 6. GET /api/stops/search/:query — Search stops
  Future<List<dynamic>> searchStops(String query) async {
    try {
      final Response response = await dio.get(
        'stops/search/${Uri.encodeComponent(query)}',
      );
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      print("Search Stops Error: $e");
      return [];
    }
  }

  /// 7. GET /api/stops/locations/distinct — Get distinct locations
  Future<List<dynamic>> getDistinctLocations() async {
    try {
      final Response response = await dio.get('stops/locations/distinct');
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      print("Get Distinct Locations Error: $e");
      return [];
    }
  }

  /// 8. GET /api/stops/coordinates/:id — Get stop coordinates
  Future<Map<String, dynamic>?> getStopCoordinates(int id) async {
    try {
      final Response response = await dio.get('stops/coordinates/$id');
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Stop Coordinates Error: $e");
      return null;
    }
  }

  // =============================================
  //  TRIP SCHEDULE APIs (13 Endpoints)
  // =============================================

  /// Helper to get auth options from stored token
  Future<Options> _authOptions({String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedToken = token ?? prefs.getString('user_token') ?? '';
    return Options(
      headers: {
        "Authorization": "Bearer $resolvedToken",
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    );
  }

  /// 9. POST /api/trips — Create a trip
  Future<Response> createTrip(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedToken = token ?? prefs.getString('user_token') ?? '';
    if (resolvedToken.isEmpty) {
      throw Exception('Missing user_token. Login again.');
    }

    return dio.post(
      'trips',
      data: payload,
      options: Options(
        headers: {
          "Authorization": "Bearer $resolvedToken",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ),
    );
  }

  /// 10. GET /api/trips/my — Get current user's trips
  Future<List<dynamic>> getMyTrips({
    String? status,
    bool? recurring,
    int? page,
    int? limit,
    String? token,
  }) async {
    try {
      final opts = await _authOptions(token: token);
      final Map<String, dynamic> params = {};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (recurring != null) params['recurring'] = recurring.toString();
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;

      final Response response = await dio.get(
        'trips/my',
        queryParameters: params,
        options: opts,
      );

      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      print("Get My Trips Error: $e");
      return [];
    }
  }

  /// 11. GET /api/trips/upcoming — Get upcoming trips
  Future<List<dynamic>> getUpcomingTrips({int? days, String? token}) async {
    try {
      final opts = await _authOptions(token: token);
      final Map<String, dynamic> params = {};
      if (days != null) params['days'] = days;

      final Response response = await dio.get(
        'trips/upcoming',
        queryParameters: params,
        options: opts,
      );

      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      print("Get Upcoming Trips Error: $e");
      return [];
    }
  }

  /// 12. GET /api/trips/stats/summary — Get trip statistics
  Future<Map<String, dynamic>?> getTripStats({String? token}) async {
    try {
      final opts = await _authOptions(token: token);
      final Response response = await dio.get(
        'trips/stats/summary',
        options: opts,
      );

      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Trip Stats Error: $e");
      return null;
    }
  }

  /// 13. GET /api/trips/:id — Get a single trip
  Future<Map<String, dynamic>?> getTripById(int id, {String? token}) async {
    try {
      final opts = await _authOptions(token: token);
      final Response response = await dio.get('trips/$id', options: opts);

      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Trip By ID Error: $e");
      return null;
    }
  }

  /// 14. PUT /api/trips/:id — Update a trip
  Future<Response> updateTrip(
    int id,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    try {
      final opts = await _authOptions(token: token);
      return await dio.put('trips/$id', data: data, options: opts);
    } catch (e) {
      print("Update Trip Error: $e");
      rethrow;
    }
  }

  /// 15. DELETE /api/trips/:id — Delete a trip
  Future<bool> deleteTrip(int id, {String? token}) async {
    try {
      final opts = await _authOptions(token: token);
      final Response response = await dio.delete('trips/$id', options: opts);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("Delete Trip Error: $e");
      return false;
    }
  }

  /// 16. POST /api/trips/:id/duplicate — Duplicate a trip
  Future<Response> duplicateTrip(
    int id, {
    String? newStartDate,
    bool adjustDates = true,
    String? token,
  }) async {
    try {
      final opts = await _authOptions(token: token);
      final Map<String, dynamic> body = {'adjust_dates': adjustDates};
      if (newStartDate != null) body['new_start_date'] = newStartDate;

      return await dio.post('trips/$id/duplicate', data: body, options: opts);
    } catch (e) {
      print("Duplicate Trip Error: $e");
      rethrow;
    }
  }

  /// 17. GET /api/trips/:id/schedule — Get trip schedule
  Future<Map<String, dynamic>?> getTripSchedule(int id, {String? token}) async {
    try {
      final opts = await _authOptions(token: token);
      final Response response = await dio.get(
        'trips/$id/schedule',
        options: opts,
      );

      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Trip Schedule Error: $e");
      return null;
    }
  }

  /// 18. PUT /api/trips/:id/schedule — Update trip schedule
  Future<Response> updateTripSchedule(
    int id,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    try {
      final opts = await _authOptions(token: token);
      return await dio.put('trips/$id/schedule', data: data, options: opts);
    } catch (e) {
      print("Update Trip Schedule Error: $e");
      rethrow;
    }
  }

  /// 19. GET /api/trips/:id/route — Get trip route
  Future<Map<String, dynamic>?> getTripRoute(int id, {String? token}) async {
    try {
      final opts = await _authOptions(token: token);
      final Response response = await dio.get('trips/$id/route', options: opts);

      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data is Map) {
          return response.data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Get Trip Route Error: $e");
      return null;
    }
  }

  /// 20. POST /api/trips/:id/stops — Add a stop to a trip
  Future<Response> addStopToTrip(
    int tripId,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    try {
      final opts = await _authOptions(token: token);
      return await dio.post('trips/$tripId/stops', data: data, options: opts);
    } catch (e) {
      print("Add Stop To Trip Error: $e");
      rethrow;
    }
  }

  /// 21. DELETE /api/trips/bulk/delete — Bulk delete trips
  Future<bool> bulkDeleteTrips(List<int> tripIds, {String? token}) async {
    try {
      final opts = await _authOptions(token: token);
      final Response response = await dio.delete(
        'trips/bulk/delete',
        data: {'trip_ids': tripIds},
        options: opts,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("Bulk Delete Trips Error: $e");
      return false;
    }
  }

  Future<void> backfillUserLocationIfMissing({
    required String email,
    required String country,
    required String city,
    required String district,
  }) async {
    final c = country.trim();
    final s = city.trim();
    final d = district.trim();
    if (email.trim().isEmpty || (c.isEmpty && s.isEmpty && d.isEmpty)) return;

    try {
      final user = await getUserByEmail(email);
      if (user == null) return;

      final existingCountry = _firstNonEmpty([
        user['country'],
        user['Country'],
        user['user_country'],
      ]);
      final existingState = _firstNonEmpty([
        user['state'],
        user['city'],
        user['State'],
        user['City'],
      ]);
      final existingDistrict = _firstNonEmpty([
        user['district'],
        user['District'],
      ]);

      final shouldUpdateCountry = existingCountry.isEmpty && c.isNotEmpty;
      final shouldUpdateState = existingState.isEmpty && s.isNotEmpty;
      final shouldUpdateDistrict = existingDistrict.isEmpty && d.isNotEmpty;
      if (!shouldUpdateCountry && !shouldUpdateState && !shouldUpdateDistrict) {
        return;
      }

      final payload = <String, dynamic>{
        if (shouldUpdateCountry) 'country': c,
        if (shouldUpdateCountry) 'Country': c,
        if (shouldUpdateCountry) 'user_country': c,
        if (shouldUpdateState) 'state': s,
        if (shouldUpdateState) 'city': s,
        if (shouldUpdateState) 'State': s,
        if (shouldUpdateState) 'City': s,
        if (shouldUpdateDistrict) 'district': d,
        if (shouldUpdateDistrict) 'District': d,
      };

      final userId = _extractUserId(user);
      // Use admin auth since PUT /users/:id requires admin role (901/903)
      String adminToken = "";
      try {
        Response loginResp = await Dio().post(
          'http://161.35.51.188:5001/api/auth/login',
          data: {"user_name": "ts2025", "user_password": "123456"},
          options: Options(contentType: 'application/json'),
        );
        if (loginResp.statusCode == 200 && loginResp.data != null) {
          adminToken = loginResp.data['token'] ?? loginResp.data['accessToken'] ?? "";
        }
      } catch (_) {}
      if (adminToken.isEmpty) return;
      final opts = Options(headers: {"Authorization": "Bearer $adminToken", "Content-Type": "application/json"});
      if (userId != null && userId.isNotEmpty) {
        final endpoints = [
          'http://161.35.51.188:5001/api/users/$userId',
          'users/$userId',
          'user/$userId',
        ];
        for (final endpoint in endpoints) {
          try {
            if (endpoint.startsWith('http')) {
              await Dio().put(endpoint, data: payload, options: opts);
            } else {
              await dio.put(endpoint, data: payload, options: opts);
            }
            return;
          } catch (_) {}
        }
      }

      // Fallback for backends that accept update-by-email.
      final fallbackPayload = <String, dynamic>{'email': email, ...payload};
      final fallbackEndpoints = [
        'http://161.35.51.188:5001/api/users/update-by-email',
        'users/update-by-email',
      ];
      for (final endpoint in fallbackEndpoints) {
        try {
          if (endpoint.startsWith('http')) {
            await Dio().put(endpoint, data: fallbackPayload, options: opts);
          } else {
            await dio.put(endpoint, data: fallbackPayload, options: opts);
          }
          return;
        } catch (_) {}
      }
    } catch (_) {}
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String? _extractUserId(Map<String, dynamic> user) {
    const keys = ['id', 'user_id', 'uid', 'u_id', 'ID', 'UserID'];
    for (final key in keys) {
      final value = user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  /// Get all users (Admin) — returns the full list for admin management
  Future<List<Map<String, dynamic>>> getAllUsersAdmin() async {
    try {
      String adminToken = "";
      try {
        Response loginResp = await Dio().post(
          'http://161.35.51.188:5001/api/auth/login',
          data: {"user_name": "ts2025", "user_password": "123456"},
          options: Options(contentType: 'application/json'),
        );
        if (loginResp.statusCode == 200 && loginResp.data != null) {
          adminToken = loginResp.data['token'] ?? "";
        }
      } catch (_) {}

      if (adminToken.isEmpty) return [];

      Response response = await Dio().get(
        'http://161.35.51.188:5001/api/users?limit=10000',
        options: Options(headers: {"Authorization": "Bearer $adminToken"}),
      );

      List<dynamic> users = [];
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
          users = response.data['data'];
        } else if (response.data is List) {
          users = response.data;
        }
      }

      return users
          .whereType<Map>()
          .map((u) => Map<String, dynamic>.from(u))
          .toList();
    } catch (e) {
      print("Get All Users Admin Error: $e");
      return [];
    }
  }

  /// Update user status (Admin) — approve (2) or reject (3)
  Future<bool> updateUserStatus(int userId, int newStatus) async {
    try {
      String adminToken = "";
      try {
        Response loginResp = await Dio().post(
          'http://161.35.51.188:5001/api/auth/login',
          data: {"user_name": "ts2025", "user_password": "123456"},
          options: Options(contentType: 'application/json'),
        );
        if (loginResp.statusCode == 200 && loginResp.data != null) {
          adminToken = loginResp.data['token'] ?? "";
        }
      } catch (_) {}

      if (adminToken.isEmpty) return false;

      Response response = await Dio().put(
        'http://161.35.51.188:5001/api/users/$userId',
        data: {'statu': newStatus},
        options: Options(
          headers: {
            "Authorization": "Bearer $adminToken",
            "Content-Type": "application/json",
          },
        ),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Update User Status Error: $e");
      return false;
    }
  }

  /// Check if a user exists by email (lightweight — returns user data or null)
  Future<Map<String, dynamic>?> checkUserExistsByEmail(String email) async {
    return await getUserByEmail(email);
  }
}
