import 'package:flutter/material.dart';
import 'package:parksmart/core/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int _expandedIndex = -1;

  final List<Map<String, dynamic>> _faqs = [
    {
      'category': 'Getting Started',
      'icon': Icons.rocket_launch_rounded,
      'color': AppColors.primary,
      'questions': [
        {
          'q': 'How do I find nearby parking?',
          'a':
              'Open the app and go to the Home tab. The map will show all nearby parking lots with colored pins — green means available, orange means filling up, and red means full. You can also use the search bar to find a specific location.',
        },
        {
          'q': 'How do I start a parking session?',
          'a':
              'Tap on a parking lot pin on the map or from the nearby list. Tap "Start Parking Session" to begin. The timer will start automatically and track your elapsed time and estimated cost.',
        },
        {
          'q': 'How do I end my parking session?',
          'a':
              'Go to the Sessions tab or tap the active session on the map. Tap "End Session" and confirm. You will be taken to the payment screen to complete payment.',
        },
      ],
    },
    {
      'category': 'EV Charging',
      'icon': Icons.electric_car_rounded,
      'color': AppColors.ev,
      'questions': [
        {
          'q': 'How do I find EV charging bays?',
          'a':
              'On the map, tap the "EV Charging" filter chip to show only EV charging bays. EV bays are shown with blue pins on the map.',
        },
        {
          'q': 'How do I start an EV charging session?',
          'a':
              'Tap on an EV bay from the map and tap "Start EV Charging". The session works the same as parking — you will be charged based on the hourly rate.',
        },
        {
          'q': 'Can I have a parking and EV session at the same time?',
          'a':
              'No. Only one active session is allowed at a time. Please end your current session before starting a new one.',
        },
      ],
    },
    {
      'category': 'Payment',
      'icon': Icons.payments_rounded,
      'color': AppColors.warning,
      'questions': [
        {
          'q': 'What payment methods are supported?',
          'a':
              'ParkSmart supports Credit/Debit Card (Visa, Mastercard), FPX Online Banking (Maybank, CIMB, RHB and more), and e-Wallets (Touch\'n Go, GrabPay, Boost, ShopeePay).',
        },
        {
          'q': 'Is my payment information safe?',
          'a':
              'Yes. We only store the last 4 digits of your card for reference. All payments are simulated and encrypted. We never store your full card number or CVV.',
        },
        {
          'q': 'How do I view my receipts?',
          'a':
              'Go to the History tab. Tap on any completed session to view its full receipt. You can also share the receipt via WhatsApp or email.',
        },
        {
          'q': 'Can I set a default payment method?',
          'a':
              'Yes! Go to Profile → Payment Methods. Add your card and tap on it to set it as default. It will be automatically selected next time you pay.',
        },
      ],
    },
    {
      'category': 'Account',
      'icon': Icons.person_rounded,
      'color': Colors.purple,
      'questions': [
        {
          'q': 'How do I update my profile?',
          'a':
              'Go to Profile → Edit Profile. You can update your name, phone number, and profile photo. Note that your email address cannot be changed.',
        },
        {
          'q': 'How do I change my password?',
          'a':
              'On the Login screen, tap "Forgot password?" and enter your email. A password reset link will be sent to your email.',
        },
        {
          'q': 'How do I add my vehicle?',
          'a':
              'Go to Profile → My Vehicle. Enter your plate number and choose your vehicle icon. This icon will appear on the map to show your location.',
        },
      ],
    },
    {
      'category': 'Technical',
      'icon': Icons.build_rounded,
      'color': Colors.teal,
      'questions': [
        {
          'q': 'Why is the map not showing my location?',
          'a':
              'Make sure you have granted location permission to ParkSmart. Go to your phone Settings → Apps → ParkSmart → Permissions → Location and enable it.',
        },
        {
          'q': 'Why is the parking availability not updating?',
          'a':
              'ParkSmart shows live data from our servers. Check your internet connection. If the issue persists, try closing and reopening the app.',
        },
        {
          'q': 'The app is running slow. What should I do?',
          'a':
              'Try closing and reopening the app. Make sure you have a stable internet connection. If the problem continues, try clearing the app cache in your phone settings.',
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'How can we help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find answers to common questions below',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha:0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // FAQ sections
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            ...List.generate(_faqs.length, (sectionIndex) {
              final section = _faqs[sectionIndex];
              final questions =
                  section['questions'] as List<Map<String, dynamic>>;
              final color = section['color'] as Color;
              final icon = section['icon'] as IconData;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          section['category'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Questions
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.withValues(alpha:0.15)),
                    ),
                    child: Column(
                      children: List.generate(questions.length, (qIndex) {
                        final globalIndex = sectionIndex * 100 + qIndex;
                        final isExpanded = _expandedIndex == globalIndex;
                        final isLast = qIndex == questions.length - 1;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () => setState(
                                () => _expandedIndex = isExpanded
                                    ? -1
                                    : globalIndex,
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: qIndex == 0
                                    ? const Radius.circular(14)
                                    : Radius.zero,
                                bottom: isLast
                                    ? const Radius.circular(14)
                                    : Radius.zero,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        questions[qIndex]['q'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isExpanded ? color : null,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: isExpanded
                                          ? color
                                          : Colors.grey[400],
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha:0.04),
                                ),
                                child: Text(
                                  questions[qIndex]['a'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            if (!isLast)
                              Divider(
                                height: 1,
                                color: Colors.grey.withValues(alpha:0.1),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            // Contact support
            const Text(
              'Still need help?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha:0.15)),
              ),
              child: Column(
                children: [
                  _buildContactItem(
                    icon: Icons.email_outlined,
                    color: AppColors.primary,
                    title: 'Email Support',
                    subtitle: 'support@parksmart.my',
                    onTap: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: 'support@parksmart.my',
                        query: 'subject=ParkSmart Support Request',
                      );
                      if (!await launchUrl(uri) && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open email app.')),
                        );
                      }
                    },
                  ),
                  Divider(height: 20, color: Colors.grey.withValues(alpha:0.1)),
                  _buildContactItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.ev,
                    title: 'Live Chat',
                    subtitle: 'Available 9AM - 6PM (Mon-Fri)',
                    onTap: () async {
                      final uri = Uri.parse(
                        'https://wa.me/60312345678?text=Hi%20ParkSmart%20Support%2C%20I%20need%20help%20with%20the%20app.',
                      );
                      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open WhatsApp.')),
                        );
                      }
                    },
                  ),
                  Divider(height: 20, color: Colors.grey.withValues(alpha:0.1)),
                  _buildContactItem(
                    icon: Icons.phone_outlined,
                    color: AppColors.warning,
                    title: 'Phone Support',
                    subtitle: '+603 1234 5678',
                    onTap: () async {
                      final uri = Uri(scheme: 'tel', path: '+60312345678');
                      if (!await launchUrl(uri) && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open phone app.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App version
            Center(
              child: Text(
                'ParkSmart v1.0.0 • Made with ❤️ in Malaysia',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
}
