import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veritrust_sdk/veritrust_sdk.dart';
import 'tabs.dart';

void main() {
  runApp(const YonoRedesignedApp());
}

class YonoRedesignedApp extends StatelessWidget {
  const YonoRedesignedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YONO 2.0 Redesign',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFF2E1B6B),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E1B6B)),
      ),
      home: const YonoMainScreen(),
    );
  }
}

class YonoMainScreen extends StatefulWidget {
  const YonoMainScreen({super.key});

  @override
  State<YonoMainScreen> createState() => _YonoMainScreenState();
}

class _YonoMainScreenState extends State<YonoMainScreen> {
  int _currentIndex = 0;

  final _config = VeriTrustConfig(
    baseUrl: 'http://localhost:8000',
    language: 'en',
  );

  @override
  void initState() {
    super.initState();
    VeriTrustAgentPlugin.initialize(_config);
  }

  void _triggerAi() {
    VeriTrustAgentPlugin.show(context);
  }

  @override
  Widget build(BuildContext context) {
    // Determine which tab to show
    Widget activeScreen;
    switch (_currentIndex) {
      case 0:
        activeScreen = DashboardTab(onTriggerAi: _triggerAi);
        break;
      case 1:
        activeScreen = const PaymentsTab();
        break;
      case 2:
        activeScreen = const ProfileTab();
        break;
      case 3:
        activeScreen = const DummyTab(title: 'More');
        break;
      default:
        activeScreen = DashboardTab(onTriggerAi: _triggerAi);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2E1B6B), // Deep purple top background
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // The active tab content
            activeScreen,
            
            // Custom Bottom Navigation
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNav(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 85,
      decoration: const BoxDecoration(
        color: Color(0xFF2E1B6B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, 'Home', 0),
              _navItem(Icons.swap_horiz, 'Payments', 1),
              const SizedBox(width: 60), // Space for FAB
              _navItem(Icons.person_outline, 'Profile', 2),
              _navItem(Icons.more_horiz, 'More', 3),
            ],
          ),
          Positioned(
            top: -30,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF2E1B6B).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Color(0xFF2E1B6B), size: 32),
                  ),
                  const SizedBox(height: 6),
                  const Text('Scan & Pay', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.white.withOpacity(0.6), size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isActive)
               Container(
                 margin: const EdgeInsets.only(top: 6),
                 height: 3,
                 width: 20,
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(2),
                 )
               )
          ],
        ),
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  final VoidCallback onTriggerAi;

  const DashboardTab({super.key, required this.onTriggerAi});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6F9), // Light grey/white body
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120),
              children: [
                _buildQuickActions(),
                const SizedBox(height: 28),
                _buildBankingServices(),
                const SizedBox(height: 28),
                _buildBanner(),
                const SizedBox(height: 28),
                _buildShoppingAndMore(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu, color: Colors.white),
                  const SizedBox(width: 16),
                  Text(
                    'YONO',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance, size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SBI',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.headset_mic_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.shield_rounded, color: Color(0xFFFFD600)),
                    onPressed: onTriggerAi,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Current balance',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '₹3,37,582',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '.48',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.visibility_outlined, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'A/c No. : 9173 8304 1342  ⧉',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    const Text('Rewards', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
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
            'Quick Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),
          // FIX: Used Wrap to prevent horizontal overflow on smaller screens
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 16,
            children: [
              // ─────────────────────────────────────────────────────────
              // THE VERITRUST AI SDK TRIGGER BUTTON ("SEE AI")
              // ─────────────────────────────────────────────────────────
              GestureDetector(
                onTap: onTriggerAi,
                child: SizedBox(
                  width: 65,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF283593), Color(0xFF3949AB)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF3949AB).withOpacity(0.4), blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4)),
                          ]
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFFFFD600), size: 28),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'See AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF283593)),
                      )
                    ],
                  ),
                ),
              ),
              _actionIcon(Icons.person_outline, 'Pay to\nContacts'),
              _actionIcon(Icons.account_balance_outlined, 'Pay to\nBank A/c'),
              _actionIcon(Icons.receipt_long_outlined, 'Mini\nStatements'),
            ],
          )
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label) {
    return SizedBox(
      width: 65, // Explicit width for consistent wrap behavior
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
              ],
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

  Widget _buildBankingServices() {
    return Container(
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
            'Banking services',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),
          // FIX: Used Wrap to prevent horizontal overflow on smaller screens
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 16,
            runSpacing: 24,
            children: [
              _serviceIcon(Icons.savings_outlined, 'Loans'),
              _serviceIcon(Icons.credit_card_outlined, 'Cards'),
              _serviceIcon(Icons.account_balance_wallet_outlined, 'Deposit'),
              _serviceIcon(Icons.payments_outlined, 'Yono Cash'),
              _serviceIcon(Icons.qr_code_scanner, 'Yono Pay'),
              _serviceIcon(Icons.health_and_safety_outlined, 'Insurance'),
              _serviceIcon(Icons.trending_up_outlined, 'Investment'),
              _serviceIcon(Icons.currency_rupee_outlined, 'Request\nMoney'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceIcon(IconData icon, String label) {
    return SizedBox(
      width: 65,
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4A90E2), size: 30),
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

  Widget _buildBanner() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF7A1B36),
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF901A40), Color(0xFF6B1230)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'SBI HOME TOP-UP LOAN\nTOP UP LOAN SE KARO, KHUSHIYON KO TOP-UP.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildShoppingAndMore() {
    return Container(
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
            'Shopping and more',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 16,
            runSpacing: 24,
            children: [
              _serviceIcon(Icons.receipt_outlined, 'Bill Pay'),
              _serviceIcon(Icons.train_outlined, 'Train tickets'),
              _serviceIcon(Icons.directions_car_outlined, 'Vehicle'),
              _serviceIcon(Icons.shopping_bag_outlined, 'Shopping'),
            ],
          )
        ],
      ),
    );
  }
}

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

class DummyTab extends StatelessWidget {
  final String title;
  const DummyTab({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Text(
                title,
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.construction, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '$title Screen',
                    style: TextStyle(fontSize: 24, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Integration mockup',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
