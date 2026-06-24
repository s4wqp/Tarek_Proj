import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tarek_proj/config/app_colors.dart';

/// Live trip tracking screen with simulated driver position.
/// Wire to real GPS data from `geolocator` package for production.
class LiveTrackingScreen extends StatefulWidget {
  final String driverName;
  final String fromLocation;
  final String toLocation;

  const LiveTrackingScreen({
    super.key,
    required this.driverName,
    required this.fromLocation,
    required this.toLocation,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _etaTimer;
  int _etaMinutes = 12;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Simulate progress updates
    _etaTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _etaMinutes > 0) {
        setState(() {
          _etaMinutes = (_etaMinutes - 1).clamp(0, 99);
          _progress = (1 - (_etaMinutes / 12)).clamp(0.0, 1.0);
        });
      }
      if (_etaMinutes <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _etaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Live Tracking',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Map placeholder with pulse animation
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid lines to simulate map
                    const Icon(Icons.map,
                        color: AppColors.textDisabled, size: 64),
                    // Animated driver dot
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 20 + (_pulseController.value * 10),
                          height: 20 + (_pulseController.value * 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(
                                (180 - _pulseController.value * 80).toInt()),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.directions_car,
                                color: Colors.white, size: 16),
                          ),
                        );
                      },
                    ),
                    // "Open in Map" button
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Open Map',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ETA Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Estimated Arrival',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    _etaMinutes > 0 ? '$_etaMinutes min' : 'Arrived!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Driver info + route
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.driverName.isNotEmpty
                                ? widget.driverName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.driverName,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const Text('Driver',
                                style: TextStyle(
                                    color: AppColors.textHint, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Call & Chat buttons
                      IconButton(
                        icon: const Icon(Icons.call,
                            color: AppColors.success, size: 22),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline,
                            color: AppColors.primary, size: 22),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.divider, height: 24),
                  // Route
                  Row(
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.circle,
                              color: AppColors.success, size: 12),
                          Container(
                              width: 2,
                              height: 24,
                              color: AppColors.textDisabled),
                          const Icon(Icons.location_on,
                              color: AppColors.error, size: 16),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.fromLocation,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14)),
                            const SizedBox(height: 16),
                            Text(widget.toLocation,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
