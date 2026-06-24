import 'package:flutter/material.dart';
import 'package:tarek_proj/config/app_colors.dart';

/// Payment method selection screen.
class PaymentScreen extends StatefulWidget {
  final double amount;
  final String serviceName;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.serviceName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selectedMethod = 0;

  final List<_PaymentMethod> _methods = [
    _PaymentMethod(
      icon: Icons.money,
      name: 'Cash',
      subtitle: 'Pay in person',
      color: AppColors.success,
    ),
    _PaymentMethod(
      icon: Icons.credit_card,
      name: 'Credit Card',
      subtitle: 'Visa, Mastercard',
      color: AppColors.primary,
    ),
    _PaymentMethod(
      icon: Icons.phone_android,
      name: 'Mobile Wallet',
      subtitle: 'Vodafone Cash, Fawry, etc.',
      color: AppColors.warning,
    ),
    _PaymentMethod(
      icon: Icons.account_balance,
      name: 'Bank Transfer',
      subtitle: 'Direct bank payment',
      color: AppColors.info,
    ),
  ];

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
        title: const Text('Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Total Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.amount.toStringAsFixed(0)} EGP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.serviceName,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Payment methods
            const Text('Select Payment Method',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount: _methods.length,
                itemBuilder: (context, i) {
                  final method = _methods[i];
                  final isSelected = _selectedMethod == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMethod = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: method.color.withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(method.icon,
                                color: method.color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(method.name,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(method.subtitle,
                                    style: const TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textDisabled,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    final method = _methods[_selectedMethod];
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Payment via ${method.name} — confirmed!'),
                      ),
                    );
                    Navigator.pop(context, method.name);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Pay ${widget.amount.toStringAsFixed(0)} EGP',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethod {
  final IconData icon;
  final String name;
  final String subtitle;
  final Color color;

  _PaymentMethod({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.color,
  });
}
