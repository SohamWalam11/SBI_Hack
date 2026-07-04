import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentsTab extends StatelessWidget {
  const PaymentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Text(
                'Payments',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transfer Money',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.spaceAround,
                        spacing: 16,
                        runSpacing: 24,
                        children: [
                          _paymentIcon(Icons.account_balance_outlined, 'Bank\nAccount'),
                          _paymentIcon(Icons.phone_android_outlined, 'Mobile\nNumber'),
                          _paymentIcon(Icons.qr_code_2, 'UPI\nID'),
                          _paymentIcon(Icons.person_outline, 'Self\nTransfer'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Transactions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                _transactionItem('Amazon.in', 'UPI Payment', '-₹1,450.00', Colors.red),
                _transactionItem('Salary Credit', 'NEFT', '+₹85,000.00', Colors.green),
                _transactionItem('Swiggy', 'UPI Payment', '-₹320.00', Colors.red),
                _transactionItem('Electricity Bill', 'BillDesk', '-₹1,240.00', Colors.red),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentIcon(IconData icon, String label) {
    return SizedBox(
      width: 65,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF2E1B6B), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          )
        ],
      ),
    );
  }

  Widget _transactionItem(String title, String subtitle, String amount, Color amountColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long, color: Colors.grey[700], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Text(
                'My Profile',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E1B6B), Color(0xFF4A90E2)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: Text('SW', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Soham Walam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('CIF: 89347201948', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _settingsGroup('Account Management', [
                  _settingsItem(Icons.credit_card, 'Manage Cards', true),
                  _settingsItem(Icons.account_balance, 'Account Details', false),
                  _settingsItem(Icons.description_outlined, 'Statements & Certificates', false),
                ]),
                const SizedBox(height: 24),
                _settingsGroup('Security & Settings', [
                  _settingsItem(Icons.lock_outline, 'Change MPIN', false),
                  _settingsItem(Icons.fingerprint, 'Biometric Setup', true),
                  _settingsItem(Icons.shield_outlined, 'Transaction Limits', false),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.red,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {},
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _settingsItem(IconData icon, String title, bool showDivider) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2E1B6B), size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFE2E8F0)),
      ],
    );
  }
}
