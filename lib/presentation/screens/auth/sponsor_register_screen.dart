import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/config/app_colors.dart';

class SponsorRegisterScreen extends StatefulWidget {
  const SponsorRegisterScreen({super.key});
  @override
  State<SponsorRegisterScreen> createState() => _SponsorRegisterScreenState();
}

class _SponsorRegisterScreenState extends State<SponsorRegisterScreen> {
  int _step = 0;
  bool _isSubmitting = false;
  bool _isLocating = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Step 1 — Account
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPass = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();

  // Step 2 — Personal
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _arabicName = TextEditingController();
  final _birthDate = TextEditingController();
  final _jobTitle = TextEditingController();
  final _country = TextEditingController();
  final _state = TextEditingController();
  final _district = TextEditingController();
  final _zipCode = TextEditingController();
  final _street = TextEditingController();
  final _building = TextEditingController();
  final _floor = TextEditingController();
  final _apt = TextEditingController();
  final _landmark = TextEditingController();

  // Step 2 documents
  File? _profilePhoto;
  File? _nationalId;
  File? _certificate;

  // Step 3 — Sponsor Info
  final _businessName = TextEditingController();
  String? _selectedCategory;
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _website = TextEditingController();
  final _comments = TextEditingController();
  final List<File> _sponsorImages = [];

  final _picker = ImagePicker();
  List<Map<String, dynamic>> _categoriesData = [];
  List<String> _categories = [];
  bool _isLoadingCategories = true;

  final _stepTitles = [
    'Account Information',
    'Personal Details',
    'Sponsor Information',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      print('DEBUG: Loading categories from API...');
      final data = await WebServices().getSponsorCategories();
      print('DEBUG: Categories API returned ${data.length} items');
      if (mounted && data.isNotEmpty) {
        setState(() {
          _categoriesData = data.cast<Map<String, dynamic>>();
          _categories = _categoriesData
              .map((c) => c['name']?.toString() ?? c['sponsor_type']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          _isLoadingCategories = false;
          print('DEBUG: Loaded ${_categories.length} categories: $_categories');
        });
      } else {
        print('DEBUG: API returned empty, using fallback');
        _setFallbackCategories();
      }
    } catch (e) {
      print('Failed to load categories: $e');
      _setFallbackCategories();
    }
  }

  void _setFallbackCategories() {
    setState(() {
      _categoriesData = [
        {'id': 801, 'name': 'Restaurant'},
        {'id': 802, 'name': 'Café'},
        {'id': 803, 'name': 'Transport'},
        {'id': 804, 'name': 'Company'},
        {'id': 805, 'name': 'Medical'},
        {'id': 806, 'name': 'Grocery'},
        {'id': 807, 'name': 'Clothes'},
        {'id': 808, 'name': 'Food & Sweet'},
        {'id': 809, 'name': 'Other'},
      ];
      _categories = _categoriesData
          .map((c) => c['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      _isLoadingCategories = false;
    });
  }

  /// Look up the cat_id for the selected category name
  int? _getCatIdForCategory(String? categoryName) {
    if (categoryName == null || _categoriesData.isEmpty) return null;
    for (final cat in _categoriesData) {
      final catName = cat['name']?.toString() ?? cat['sponsor_type']?.toString();
      if (catName == categoryName) {
        return (cat['id'] ?? cat['cat_id']) as int?;
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (var c in [
      _username, _email, _password, _confirmPass, _phone, _whatsapp,
      _firstName, _lastName, _arabicName, _birthDate, _jobTitle,
      _country, _state, _district, _zipCode, _street, _building,
      _floor, _apt, _landmark, _businessName, _latitude, _longitude,
      _website, _comments,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Random Fill ──
  void _fillRandomData() {
    final r = Random();
    String rStr(int len) {
      const c = 'abcdefghijklmnopqrstuvwxyz';
      return String.fromCharCodes(Iterable.generate(len, (_) => c.codeUnitAt(r.nextInt(c.length))));
    }
    String rNum(int len) {
      const c = '0123456789';
      return String.fromCharCodes(Iterable.generate(len, (_) => c.codeUnitAt(r.nextInt(c.length))));
    }
    setState(() {
      // Step 1
      _username.text = 'user_${rStr(4)}';
      _email.text = '${rStr(5)}${rNum(2)}@test.com';
      _password.text = 'Pass${rNum(4)}';
      _confirmPass.text = _password.text;
      _phone.text = '010${rNum(8)}';
      _whatsapp.text = '012${rNum(8)}';
      // Step 2
      _firstName.text = rStr(5).replaceRange(0, 1, rStr(1).toUpperCase());
      _lastName.text = rStr(5).replaceRange(0, 1, rStr(1).toUpperCase());
      _arabicName.text = 'Test Name';
      _birthDate.text = '01/${(r.nextInt(12) + 1).toString().padLeft(2, '0')}/199${r.nextInt(10)}';
      _jobTitle.text = ['Manager', 'Owner', 'Director', 'CEO', 'Partner'][r.nextInt(5)];
      _country.text = 'Egypt';
      _state.text = ['Cairo', 'Giza', 'Alexandria'][r.nextInt(3)];
      _district.text = ['Maadi', 'Nasr City', 'Zamalek', 'Dokki'][r.nextInt(4)];
      _zipCode.text = rNum(5);
      _street.text = 'Street ${rNum(2)}';
      _building.text = rNum(2);
      _floor.text = rNum(1);
      _apt.text = rNum(2);
      _landmark.text = 'Near ${['Mall', 'Park', 'School', 'Hospital'][r.nextInt(4)]}';
      // Step 3
      _businessName.text = '${['Golden', 'Blue', 'Star', 'Prime'][r.nextInt(4)]} ${['Place', 'Center', 'Shop'][r.nextInt(3)]}';
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories[r.nextInt(_categories.length)];
      }
      _latitude.text = (30.0 + r.nextDouble()).toStringAsFixed(6);
      _longitude.text = (31.0 + r.nextDouble()).toStringAsFixed(6);
      _website.text = 'https://${rStr(6)}.com';
      _comments.text = 'Test registration ${rNum(3)}';
    });
  }

  // ── Validation ──
  final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_username.text.trim().length < 3) {
          _showError('Username must be at least 3 characters.');
          return false;
        }
        if (_username.text.trim().contains(' ')) {
          _showError('Username cannot contain spaces.');
          return false;
        }
        if (!_emailRegex.hasMatch(_email.text.trim())) {
          _showError('Please enter a valid email address.');
          return false;
        }
        if (_password.text.length < 6) {
          _showError('Password must be at least 6 characters.');
          return false;
        }
        if (_password.text != _confirmPass.text) {
          _showError('Passwords do not match.');
          return false;
        }
        final phone = _phone.text.trim();
        if (phone.isEmpty || phone.length < 10 || !RegExp(r'^[0-9+]+$').hasMatch(phone)) {
          _showError('Please enter a valid phone number (min 10 digits).');
          return false;
        }
        return true;
      case 1:
        if (_firstName.text.trim().isEmpty) {
          _showError('First name is required.');
          return false;
        }
        if (_country.text.trim().isEmpty) {
          _showError('Country is required.');
          return false;
        }
        if (_state.text.trim().isEmpty) {
          _showError('State / City is required.');
          return false;
        }
        return true;
      case 2:
        if (_businessName.text.trim().isEmpty) {
          _showError('Business name is required.');
          return false;
        }
        if (_selectedCategory == null) {
          _showError('Please select a business category.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.rightSlide,
      title: 'Validation Error',
      desc: msg,
      btnOkOnPress: () {},
    ).show();
  }

  void _next() {
    if (!_validateStep()) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _pickFile(String type) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      switch (type) {
        case 'profile':
          _profilePhoto = File(picked.path);
          break;
        case 'nid':
          _nationalId = File(picked.path);
          break;
        case 'cert':
          _certificate = File(picked.path);
          break;
        case 'sponsor':
          // Only 1 free image allowed during registration
          if (_sponsorImages.isEmpty) _sponsorImages.add(File(picked.path));
          break;
      }
    });
  }

  /// Send confirmation email to sponsor after registration
  Future<void> _sendRegistrationEmail(String email, String businessName) async {
    try {
      final emailUri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': 'Registration Received \u2014 AidMe',
          'body': 'Dear $businessName Team,\n\n'
              'Thank you for registering as a sponsor on AidMe!\n\n'
              'Your application has been submitted successfully and is now under review by our admin team.\n\n'
              'You will receive a confirmation once your account is approved.\n\n'
              'Best regards,\nAidMe Team',
        },
      );
      await launchUrl(emailUri);
    } catch (e) {
      print('Failed to send registration email: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLocating = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showError('Location services disabled.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _showError('Location permission denied.');
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _latitude.text = pos.latitude.toStringAsFixed(6);
      _longitude.text = pos.longitude.toStringAsFixed(6);

      final places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (places.isNotEmpty) {
        final p = places.first;
        if (_country.text.isEmpty) _country.text = p.country ?? '';
        if (_state.text.isEmpty) _state.text = p.locality ?? '';
        if (_district.text.isEmpty) _district.text = p.subAdministrativeArea ?? '';
        if (_street.text.isEmpty) _street.text = p.street ?? '';
        if (_zipCode.text.isEmpty) _zipCode.text = p.postalCode ?? '';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated!')),
        );
      }
    } catch (e) {
      _showError('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;
    setState(() => _isSubmitting = true);

    try {
      // Step 1: Format Date for backend (DD/MM/YYYY to YYYY-MM-DD)
      String rawDate = _birthDate.text.trim();
      String formattedDate = rawDate;
      try {
        final parts = rawDate.split('/');
        if (parts.length == 3) {
          formattedDate = "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
        }
      } catch (_) {}

      final String email = _email.text.trim();
      String? token;

      // ── FIX: Check if user already exists (handles retry after partial failure) ──
      print("0. Checking if user already exists...");
      final existingUser = await WebServices().checkUserExistsByEmail(email);

      if (existingUser != null) {
        // User exists — check if sponsor record also exists
        final userId = existingUser['id'];
        if (userId != null) {
          final existingSponsor = await WebServices().getSponsorByUserId(
            userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
          );
          if (existingSponsor != null) {
            // Both user and sponsor exist — truly already registered
            _showError('This email is already registered as a sponsor. Please login instead.');
            setState(() => _isSubmitting = false);
            return;
          }
        }

        // User exists but NO sponsor record — try to login and get token
        print("1b. User exists without sponsor. Logging in to get token...");
        token = await WebServices().loginUserForToken(
          _username.text.trim(),
          _password.text.trim(),
        );
        if (token == null || token.isEmpty) {
          _showError(
            'A user account with this email already exists but the password does not match. '
            'Please use the correct password or try a different email.',
          );
          setState(() => _isSubmitting = false);
          return;
        }
      } else {
        // ── Normal flow: Register new user ──
        final userApiData = {
          'firm_id': 1,
          'u_type_id': 2, // Provider
          'cat_id': 801, // Generic sponsor cat fallback
          'wt_id': 5,
          'user_f_name': _firstName.text.trim(),
          'user_l_name': _lastName.text.trim(),
          'user_ar_name': _arabicName.text.trim(),
          'user_email': email,
          'user_password': _password.text.trim(),
          'user_tel_no': _phone.text.trim(),
          'user_whatsapp_no': _whatsapp.text.trim(),
          'birth_date': formattedDate,
          'Gender': 1,
          'job': _jobTitle.text.trim(),
          'statu': 1,
          'country': _country.text.trim(),
          'state': _state.text.trim(),
          'district': _district.text.trim(),
          'zip_code': _zipCode.text.trim(),
          'street_name': _street.text.trim(),
          'Building_number': _building.text.trim(),
          'Floor_number': _floor.text.trim(),
          'Apartment_number': _apt.text.trim(),
          'Lead_mark': _landmark.text.trim(),
          'user_name': _username.text.trim(),
        };

        Map<String, File> userFiles = {};
        if (_profilePhoto != null) userFiles['user_photo'] = _profilePhoto!;
        if (_certificate != null) userFiles['user_cer_photo'] = _certificate!;

        print("1. Registering base User account...");
        final userResponse = await WebServices().registerUser(userApiData, userFiles);

        if (userResponse.statusCode != 200 && userResponse.statusCode != 201) {
          _showError('User Registration failed: ${userResponse.statusCode}');
          setState(() => _isSubmitting = false);
          return;
        }

        // Extract token from User Registration response
        print("2. Extracting token from registration response...");
        if (userResponse.data is Map) {
          token = userResponse.data['token'] ?? userResponse.data['accessToken'];
        }

        if (token == null || token.isEmpty) {
          _showError('Registration succeeded but no authorization token was returned.');
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Step 3: Register Sponsor profile using token
      print("3. Registering Sponsor profile...");

      // Resolve the numeric cat_id for the selected category
      final catId = _getCatIdForCategory(_selectedCategory);
      print("DEBUG: Selected category: $_selectedCategory -> cat_id: $catId");

      // Only send the first image (free tier)
      final List<File> imagesToSend = _sponsorImages.take(1).toList();

      final sponsorData = <String, dynamic>{
        'business_name': _businessName.text.trim(),
        'sponsor_name': _businessName.text.trim(),
        'sponsor_cat': catId ?? _selectedCategory ?? '',
        'Unit_latitude': _latitude.text.trim(),
        'Unit_lONGITUDE': _longitude.text.trim(),
        'sponsor_web_site': _website.text.trim(),
        'comments': _comments.text.trim(),
        'firm_id': 1,
        'statu': 1,
        'sponsor_Reg_no': 0,
      };

      final response = await WebServices().registerSponsor(sponsorData, imagesToSend, token.toString());

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Send confirmation email to sponsor
        // Email notification disabled for now
        // _sendRegistrationEmail(email, _businessName.text.trim());

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'Registration Submitted!',
          desc: 'Your sponsor application has been submitted. '
              'A confirmation email has been sent to $email. '
              'You will be notified once approved.',
          btnOkOnPress: () => Navigator.pop(context),
        ).show();
      } else {
        _showError('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _showError('Registration failed: $msg');
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── UI Builders ──

  Widget _buildStepper() {
    return Row(
      children: List.generate(3, (i) {
        final done = i < _step;
        final active = i == _step;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: done || active
                            ? AppColors.primary
                            : Colors.white24,
                      ),
                    ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: done
                        ? AppColors.success
                        : active
                            ? AppColors.primary
                            : Colors.white24,
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                  ),
                  if (i < 2)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: done ? AppColors.primary : Colors.white24,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _stepTitles[i],
                style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {bool req = false}) {
    return InputDecoration(
      labelText: req ? '$label *' : label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool req = false, bool isNum = false, bool obscure = false,
       Widget? suffix, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        obscureText: obscure,
        maxLines: maxLines,
        decoration: _inputDeco(label, icon, req: req).copyWith(
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      children: children
          .map((c) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              )))
          .toList(),
    );
  }

  Widget _uploadBtn(String label, File? file, VoidCallback onTap) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: hasFile ? AppColors.success.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.primary,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFile ? Icons.check_circle : Icons.camera_alt,
              color: hasFile ? AppColors.success : AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                hasFile ? 'Uploaded ✓' : label,
                style: TextStyle(
                  color: hasFile ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step Content ──

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 6),
      child: Row(children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(
          color: AppColors.primary, borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
        )),
      ]),
    );
  }

  Widget _step1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Login Credentials'),
      _field(_username, 'Username', Icons.person, req: true),
      _field(_email, 'Email', Icons.email, req: true),
      _field(_password, 'Password', Icons.lock, req: true, obscure: _obscurePass,
        suffix: IconButton(
          icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off,
              color: Colors.white54, size: 20),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
      ),
      _field(_confirmPass, 'Confirm Password', Icons.lock_outline, req: true,
        obscure: _obscureConfirm,
        suffix: IconButton(
          icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off,
              color: Colors.white54, size: 20),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),
      const SizedBox(height: 4),
      _sectionLabel('Contact Information'),
      _field(_phone, 'Phone Number', Icons.phone, req: true, isNum: true),
      _field(_whatsapp, 'WhatsApp Number (Optional)', Icons.chat, isNum: true),
    ]);
  }

  Widget _step2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Personal Information'),
      _field(_firstName, 'First Name', Icons.person, req: true),
      _field(_lastName, 'Last Name', Icons.person_outline),
      _field(_arabicName, 'Arabic Name', Icons.translate),
      _field(_birthDate, 'Birth Date (mm/dd/yyyy)', Icons.calendar_today),
      _field(_jobTitle, 'Job Title', Icons.work),
      const SizedBox(height: 4),
      _sectionLabel('Address Information'),
      _field(_country, 'Country', Icons.public, req: true),
      _row([
        _field(_state, 'State / City', Icons.location_city, req: true),
        _field(_district, 'District', Icons.map),
      ]),
      _row([
        _field(_zipCode, 'Zip Code', Icons.pin_drop, isNum: true),
        _field(_street, 'Street Name', Icons.streetview),
      ]),
      _row([
        _field(_building, 'Building No', Icons.home, isNum: true),
        _field(_floor, 'Floor No', Icons.layers, isNum: true),
      ]),
      _row([
        _field(_apt, 'Apartment No', Icons.door_front_door, isNum: true),
        _field(_landmark, 'Landmark', Icons.flag),
      ]),
      const SizedBox(height: 4),
      _sectionLabel('Upload Documents'),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Column(children: [
          const Text('Profile Photo', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          _uploadBtn('Upload Photo', _profilePhoto, () => _pickFile('profile')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(children: [
          const Text('National ID', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          _uploadBtn('Upload NID', _nationalId, () => _pickFile('nid')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(children: [
          const Text('Certificate', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          _uploadBtn('Upload Cert', _certificate, () => _pickFile('cert')),
        ])),
      ]),
      const SizedBox(height: 16),
      _field(_comments, 'Additional Comments (Optional)', Icons.comment, maxLines: 3),
    ]);
  }

  Widget _step3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Business Details'),
      _field(_businessName, 'Business Name', Icons.business, req: true),
      if (_isLoadingCategories)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_categories.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              setState(() => _isLoadingCategories = true);
              _loadCategories();
            },
            child: InputDecorator(
              decoration: _inputDeco('Business Category', Icons.category, req: true),
              child: const Text('Failed to load — tap to retry',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey('cat_${_selectedCategory ?? "none"}_${_categories.length}'),
            initialValue: _selectedCategory,
            decoration: _inputDeco('Business Category', Icons.category, req: true),
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: _categories.map((c) => DropdownMenuItem(
              value: c, child: Text(c),
            )).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
        ),
      _field(_website, 'Website (Optional)', Icons.language),
      const SizedBox(height: 4),
      _sectionLabel('Business Location'),
      _row([
        _field(_latitude, 'Latitude', Icons.location_on),
        _field(_longitude, 'Longitude', Icons.location_on),
      ]),
      Center(
        child: ElevatedButton.icon(
          onPressed: _isLocating ? null : _getLocation,
          icon: _isLocating
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.my_location, size: 18),
          label: Text(_isLocating ? 'Locating...' : 'Get Current Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('Sponsor Image (1 Free)'),
      const SizedBox(height: 4),
      Row(children: List.generate(3, (i) {
        final hasImg = i < _sponsorImages.length;
        final isLocked = i > 0; // Only first image is free
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(children: [
              Text('Image ${i + 1}${i == 0 ? ' (Free)' : ''}',
                  style: TextStyle(
                    color: isLocked ? Colors.white30 : Colors.white60,
                    fontSize: 12,
                  )),
              const SizedBox(height: 6),
              if (isLocked)
                // Locked slot — only available after approval with points
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Colors.white24, size: 22),
                      SizedBox(height: 4),
                      Text('After\napproval',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 9)),
                    ],
                  ),
                )
              else if (hasImg)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_sponsorImages[i],
                        height: 80, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(top: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _sponsorImages.removeAt(i)),
                      child: const CircleAvatar(
                        radius: 12, backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ])
              else
                _uploadBtn('Upload', null, () => _pickFile('sponsor')),
            ]),
          ),
        );
      })),
      const SizedBox(height: 8),
      const Text(
        '\u2022 You can upload 1 free image during registration.\n'
        '\u2022 Additional images can be uploaded after approval using points from your wallet.',
        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
      ),
      const SizedBox(height: 16),
      _field(_comments, 'Additional Comments (Optional)', Icons.comment, maxLines: 3),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => _step > 0 ? _back() : Navigator.pop(context),
        ),
        title: const Text('Sponsor Registration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Join as a sponsor and grow your business',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          // Stepper
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _buildStepper(),
          ),
          const SizedBox(height: 8),
          // Step title + Random button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _stepTitles[_step],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _fillRandomData,
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: const Text('Random', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _step == 0
                    ? _step1()
                    : _step == 1
                        ? _step2()
                        : _step3(),
              ),
            ),
          ),
          // Bottom buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _back,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('BACK',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : _step < 2
                            ? _next
                            : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _step < 2 ? 'NEXT' : 'REGISTER',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
