import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/home/HomePage.dart';
import 'package:tarek_proj/presentation/screens/home/ServicesHomeScreen.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/ride_dashboard.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/driver_dashboard.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/companion_dashboard.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/nursing_dashboard.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/cleaning_dashboard.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/teacher_dashboard.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/rental_dashboard.dart';
import 'package:tarek_proj/presentation/screens/admin/AdminDashboardScreen.dart';

/// Routes to the correct dashboard based on the user's service category ID.
/// [catId] - The category code (101-109 for seekers, 201-209 for providers,
///           901-902 for admin/sponsor)
/// [isProvider] - Whether the user is a provider (u_type_id == 2 or 3)
Widget getServiceDashboard(int catId, {bool isProvider = false}) {
  switch (catId) {
    // Admin / Sponsor management
    case 901:
    case 902:
      return const AdminDashboardScreen();
    // Ride services
    case 101:
    case 201:
      return RideDashboard(isProvider: isProvider);

    // Driver services
    case 102:
    case 202:
      return DriverDashboard(isProvider: isProvider);

    // Companion / Senior / Babysitter
    case 103:
    case 203:
    case 104:
      return CompanionDashboard(isProvider: isProvider);

    // Nursing / Physical Therapy
    case 105:
    case 204:
    case 205:
    case 106:
      return NursingDashboard(isProvider: isProvider);

    // Cleaning
    case 107:
    case 206:
    case 207:
      return CleaningDashboard(isProvider: isProvider);

    // Teacher
    case 108:
    case 208:
      return TeacherDashboard(isProvider: isProvider);

    // Rental
    case 109:
    case 209:
      return RentalDashboard(isProvider: isProvider);

    default:
      // Fallback to generic home
      return isProvider ? const Homepage() : const ServicesHomeScreen();
  }
}
