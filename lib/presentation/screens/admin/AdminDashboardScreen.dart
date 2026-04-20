import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/services/AddSponsorScreen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff030927),
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff030927),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              } catch (e) {
                print("Logout error: $e");
              }
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview Analytics',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                      'Total Users', '1,204', Icons.people, Colors.blueAccent),
                  _buildStatCard('Active Providers', '450', Icons.work,
                      Colors.orangeAccent),
                  _buildStatCard('Pending Approvals', '23',
                      Icons.pending_actions, Colors.redAccent),
                  _buildStatCard('Total Revenue', '\$12,500',
                      Icons.attach_money, Colors.greenAccent),
                ],
              ),
              const SizedBox(height: 35),
              const Text(
                'Quick Actions',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _buildActionCard(
                context,
                'Add Business Sponsor',
                'Create and manage advertising sponsors',
                Icons.add_business,
                Colors.purpleAccent,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddSponsorScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildActionCard(
                context,
                'Manage Users',
                'View, approve, or reject user registrations',
                Icons.admin_panel_settings,
                Colors.indigoAccent,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('User Management coming soon!')),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildActionCard(
                context,
                'App Settings',
                'Configure core application behaviors',
                Icons.settings,
                Colors.blueGrey,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App Settings coming soon!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff2d3142),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Text(
                value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle,
      IconData icon, Color iconColor, VoidCallback onTap) {
    return Card(
      color: const Color(0xff2d3142),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios,
            color: Colors.white54, size: 16),
        onTap: onTap,
      ),
    );
  }
}
