import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:tarek_proj/config/app_colors.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/widgets/custom_widgets.dart';

class EditSponsorScreen extends StatefulWidget {
  final Map<String, dynamic>? initialSponsorData;
  final int initialPoints;

  const EditSponsorScreen({
    super.key,
    this.initialSponsorData,
    this.initialPoints = 0,
  });

  @override
  State<EditSponsorScreen> createState() => _EditSponsorScreenState();
}

class _EditSponsorScreenState extends State<EditSponsorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _sponsorData;
  int _pointsBalance = 0;
  String? _error;

  final _businessName = TextEditingController();
  final _website = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _comments = TextEditingController();

  String? _selectedCategory;
  List<Map<String, dynamic>> _categoriesData = [];
  List<String> _categories = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.initialSponsorData != null) {
      _sponsorData = widget.initialSponsorData;
      _pointsBalance = widget.initialPoints;
      _populateControllers();
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    for (var c in [_businessName, _website, _latitude, _longitude, _comments]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await WebServices().getSponsorCategories();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _categoriesData = data.cast<Map<String, dynamic>>();
          _categories = _categoriesData
              .map((c) => c['name']?.toString() ?? c['sponsor_type']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        });
      } else {
        _setFallbackCategories();
      }
    } catch (e) {
      print('Failed to load categories: $e');
      _setFallbackCategories();
    }
  }

  void _setFallbackCategories() {
    if (!mounted) return;
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
    });
  }

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

  String? _getCategoryNameForCatId(dynamic catId) {
    if (catId == null || _categoriesData.isEmpty) return null;
    final id = catId is int ? catId : int.tryParse(catId.toString());
    for (final cat in _categoriesData) {
      if ((cat['id'] ?? cat['cat_id']) == id) {
        return cat['name']?.toString() ?? cat['sponsor_type']?.toString();
      }
    }
    return null;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ws = WebServices();
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');

      // Fetch sponsor data
      Map<String, dynamic>? sponsor;
      try {
        sponsor = await ws.getMySponsorDirect();
      } catch (_) {}
      if (sponsor == null && userEmail != null) {
        final userData = await ws.getUserByEmail(userEmail);
        if (userData != null && userData['id'] != null) {
          final userId = userData['id'];
          sponsor = await ws.getSponsorByUserId(
            userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
          );
        }
      }

      // Fetch points
      int points = 0;
      if (userEmail != null) {
        final userData = await ws.getUserByEmail(userEmail);
        if (userData != null && userData['points_balance'] != null) {
          points = (userData['points_balance'] as num).toInt();
        }
      }

      if (mounted) {
        setState(() {
          _sponsorData = sponsor;
          _pointsBalance = points;
          _isLoading = false;
        });
        _populateControllers();
      }
    } catch (e) {
      print('Edit Sponsor Load Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _populateControllers() {
    if (_sponsorData == null) return;
    _businessName.text = _sponsorData!['sponsor_name']?.toString() ?? '';
    _website.text = _sponsorData!['sponsor_web_site']?.toString() ?? '';
    _latitude.text = _sponsorData!['Unit_latitude']?.toString() ?? '';
    _longitude.text = _sponsorData!['Unit_lONGITUDE']?.toString() ??
        _sponsorData!['Unit_longitude']?.toString() ??
        '';
    _comments.text = _sponsorData!['comments']?.toString() ?? '';

    // Resolve category
    final catId = _sponsorData!['sponsor_cat'] ?? _sponsorData!['cat_id'];
    final catName = _getCategoryNameForCatId(catId);
    if (catName != null && _categories.contains(catName)) {
      _selectedCategory = catName;
    }
  }

  Future<void> _saveChanges() async {
    if (_businessName.text.trim().isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.rightSlide,
        title: 'Validation Error',
        desc: 'Business name is required.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final catId = _getCatIdForCategory(_selectedCategory);

      final data = <String, dynamic>{
        'sponsor_name': _businessName.text.trim(),
        'sponsor_web_site': _website.text.trim(),
        'Unit_latitude': _latitude.text.trim(),
        'Unit_lONGITUDE': _longitude.text.trim(),
        'comments': _comments.text.trim(),
      };
      if (catId != null) {
        data['sponsor_cat'] = catId;
      }

      final response = await WebServices().updateMySponsor(data);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'Saved!',
          desc: 'Your business profile has been updated successfully.',
          btnOkOnPress: () {
            if (mounted) Navigator.pop(context, true);
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.rightSlide,
          title: 'Error',
          desc: 'Server returned status ${response.statusCode}',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      print('Save Sponsor Error: $e');
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.rightSlide,
          title: 'Error',
          desc: 'Failed to save changes: $e',
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadImage() async {
    int imageCount = 0;
    if (_sponsorData != null) {
      if (_sponsorData!['imag1_photo'] != null &&
          _sponsorData!['imag1_photo'].toString().isNotEmpty) imageCount++;
      if (_sponsorData!['imag2_photo'] != null &&
          _sponsorData!['imag2_photo'].toString().isNotEmpty) imageCount++;
      if (_sponsorData!['imag3_photo'] != null &&
          _sponsorData!['imag3_photo'].toString().isNotEmpty) imageCount++;
    }

    if (imageCount >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 images allowed.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (imageCount >= 1) {
      if (_pointsBalance < 1000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Not enough points! 1000 points required to upload an additional image.',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Upload Image',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Uploading an additional image costs 1000 points. Do you want to proceed?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('Proceed',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      await WebServices().addMySponsorImage(File(image.path));
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Upload Image Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(String imageField) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Image',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this image?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await WebServices().deleteMySponsorImage(imageField);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Delete Image Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── UI Helpers ──

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
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool req = false, bool isNum = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: _inputDeco(label, icon, req: req),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 6),
      child: Row(children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
      ]),
    );
  }

  // ── Build Methods ──

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFED8F03).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Points',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  '$_pointsBalance pts',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    List<MapEntry<String, String>> images = [];
    if (_sponsorData != null) {
      for (final key in ['imag1_photo', 'imag2_photo', 'imag3_photo']) {
        final val = _sponsorData![key];
        if (val != null && val.toString().isNotEmpty) {
          String imgPath = val.toString();
          if (imgPath.startsWith('/')) {
            imgPath = imgPath.substring(1);
          }
          images.add(MapEntry(key, 'https://api.aidme.online/$imgPath'));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.divider, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.image_not_supported,
                    color: Colors.white38, size: 48),
                const SizedBox(height: 16),
                const Text('No images uploaded yet',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _uploadImage,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('Upload First Image (Free)',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final entry = images[index];
                    return Stack(
                      children: [
                        Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white24, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(
                              entry.value,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.card,
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image,
                                            color: Colors.white38,
                                            size: 32),
                                        SizedBox(height: 8),
                                        Text('Image unavailable',
                                            style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 18,
                          child: GestureDetector(
                            onTap: () => _deleteImage(entry.key),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        if (images.length < 3) ...[
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: Text(
                images.isEmpty
                    ? 'Upload Image (Free)'
                    : 'Upload Image (1000 pts)',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (images.isNotEmpty)
          const Text(
            '* Note: Uploading any image after the first one costs 1000 points.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Business Profile',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check, color: AppColors.primary),
                    tooltip: 'Save Changes',
                    onPressed: _saveChanges,
                  ),
        ],
      ),
      body: _isLoading
          ? const LoadingOverlay(message: 'Loading business profile...')
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load',
                  subtitle: _error,
                  actionLabel: 'Retry',
                  onAction: _loadData,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Business Information ──
                      _sectionLabel('Business Information'),
                      _field(_businessName, 'Business Name',
                          Icons.business,
                          req: true),
                      if (_categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: _loadCategories,
                            child: InputDecorator(
                              decoration: _inputDeco(
                                  'Business Category', Icons.category,
                                  req: true),
                              child: const Text(
                                  'Loading categories — tap to retry',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14)),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                                'cat_${_selectedCategory ?? "none"}_${_categories.length}'),
                            value: _selectedCategory,
                            decoration: _inputDeco(
                                'Business Category', Icons.category,
                                req: true),
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            items: _categories
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v),
                          ),
                        ),
                      _field(
                          _website, 'Website', Icons.language),

                      const SizedBox(height: 4),

                      // ── Location ──
                      _sectionLabel('Location'),
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: _field(_latitude, 'Latitude',
                                  Icons.location_on,
                                  isNum: true),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: _field(_longitude, 'Longitude',
                                  Icons.location_on,
                                  isNum: true),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // ── Business Images ──
                      _sectionLabel('Business Images'),
                      _buildPointsCard(),
                      const SizedBox(height: 16),
                      _buildImagesSection(),

                      const SizedBox(height: 4),

                      // ── Additional Comments ──
                      _sectionLabel('Additional Comments'),
                      _field(_comments, 'Comments', Icons.comment,
                          maxLines: 3),

                      const SizedBox(height: 24),

                      // ── Save Button ──
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Text('SAVE CHANGES',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
