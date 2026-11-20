import 'package:flutter/material.dart';

/// Bottom sheets matching the exact Figma designs for My Account
class AccountSheets {
  static void showAboutUs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'About us',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  _buildCloseButton(ctx),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    _AboutSection(
                      title: 'Our Vision',
                      body:
                          'At You2Art, we believe that art has the power to inspire, '
                          'provoke thought, and foster connections that transcend boundaries. '
                          'Our vision is to create an inclusive community where artists of all '
                          'backgrounds and disciplines can showcase their creations, receive recognition, '
                          'and find inspiration in the work of others.',
                    ),
                    _AboutSection(
                      title: 'Who We Are',
                      body:
                          'We are a team of artists, technologists, and dreamers who are passionate '
                          'about nurturing a thriving artistic ecosystem. Our diverse backgrounds allow us '
                          'to blend creativity with innovation, ensuring that the You2Art app is a place '
                          'where imagination knows no limits.',
                    ),
                    _AboutSection(
                      title: 'What We Offer',
                      body:
                          'Through the You2Art app, you can explore a diverse spectrum of art forms — '
                          'from mesmerizing paintings and captivating photographs to exhilarating '
                          'performances and soul-stirring poetry. Connect with like-minded individuals '
                          'who share your passion, engage in conversations that spark creativity, and '
                          'discover hidden gems from emerging talents.',
                    ),
                    _AboutSection(
                      title: 'Empowerment Through Connection',
                      body:
                          'We believe that art thrives in an environment of collaboration and shared experiences. '
                          'With You2Art, you can connect with fellow artists, exchange ideas, and support each '
                          'other\'s artistic journeys. Whether you\'re a seasoned creator or someone just dipping '
                          'your toes into the artistic waters, you\'ll find a supportive community ready to cheer you on.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showTermsConditions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Effective Date: 25 Nov, 2022',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                  _buildCloseButton(ctx),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    Text(
                      'Welcome to You2Art ("App," "We," "Us," or "Our"). By using or accessing the You2Art App, '
                      'you agree to comply with and be bound by the following Terms and Conditions ("Terms"). '
                      'If you do not agree to these Terms, please do not use the App.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF424242),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16),
                    _LegalSection(
                      number: '1',
                      title: 'Acceptance of Terms',
                      body:
                          'By using the You2Art App, you confirm that you are at least 18 years of age or have '
                          'obtained consent from a legal guardian. These Terms constitute a legally binding '
                          'agreement between you and You2Art.',
                    ),
                    _LegalSection(
                      number: '2',
                      title: 'User Accounts',
                      body:
                          '2.1 You may need to create a user account to access certain features of the App. You are '
                          'responsible for maintaining the confidentiality of your account credentials.\n'
                          '2.2 You agree to provide accurate and complete information during the registration process '
                          'and to update such information to keep it accurate and current.',
                    ),
                    _LegalSection(
                      number: '3',
                      title: 'Content',
                      body:
                          '3.1 The App allows users to post, upload, share, and access various types of content, including '
                          'text, images, audio, and videos ("User Content").\n'
                          '3.2 You retain ownership of your User Content. However, by submitting User Content, you grant '
                          'You2Art a non-exclusive, worldwide, royalty-free, sublicensable, and transferable license to use, '
                          'reproduce, distribute, and display such content in connection with operating and providing the App.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Effective Date: 25 Nov, 2022',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                  _buildCloseButton(ctx),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    _LegalSection(
                      number: '1',
                      title: 'Introduction',
                      body:
                          'Welcome to the You2Art App ("App," "We," "Us," or "Our"). This Privacy Policy outlines '
                          'how we collect, use, disclose, and protect your personal information when you use the App. '
                          'By using the App, you agree to the terms and practices described in this Privacy Policy.',
                    ),
                    _LegalSection(
                      number: '2',
                      title: 'Information We Collect',
                      body:
                          '2.1 Personal Information: When you create an account, we may collect personal information such '
                          'as your name, email address, profile picture, and location.\n'
                          '2.2 User Content: The App allows you to post and share User Content. This content may contain '
                          'personal information that you choose to share with others.\n'
                          '2.3 Usage Data: We collect information about your interactions with the App, including log data, '
                          'device information, and usage patterns.',
                    ),
                    _LegalSection(
                      number: '3',
                      title: 'How We Use Your Information',
                      body:
                          '3.1 Providing Services: We use your information to provide and improve the services offered by '
                          'the App, including personalized content and recommendations.\n'
                          '3.2 Communication: We may use your email address to send you notifications, updates, and marketing '
                          'materials related to the App. You can opt out of these communications at any time.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showVerifyAccount(
    BuildContext context, {
    String? email,
    bool isEmailVerified = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isEmailVerified
                      ? const Color(0xFFE8F1FC)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isEmailVerified
                      ? Icons.verified_user_outlined
                      : Icons.mark_email_unread_outlined,
                  color: isEmailVerified
                      ? const Color(0xFF3899F3)
                      : const Color(0xFFF59E0B),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEmailVerified
                    ? 'Account Verification Status'
                    : 'Email Verification Pending',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isEmailVerified ? Icons.check_circle : Icons.pending_outlined,
                          size: 18,
                          color: isEmailVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEmailVerified
                                ? 'Authentication: Signed in via OTP Code'
                                : 'Email: Confirmation Pending',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Artist Profile Badge: Standard (Unverified)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isEmailVerified
                    ? 'Entering the 6-digit code authenticated your account session. To receive the official verified badge on your profile, your credentials and portfolio must be vetted by our editorial team.'
                    : 'Please check your email inbox and confirm your email address to unlock full features.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification badge request submitted for editorial review!'),
                              backgroundColor: Color(0xFF1E293B),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3899F3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Request Badge',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showLogoutModal(BuildContext context, {required VoidCallback onLogout}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Logout?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  _buildCloseButton(ctx),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to log out?\n\n'
                'Logging out will end your current session and require you to sign in again the next time you access the app.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF616161),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEEEEE),
                          foregroundColor: const Color(0xFF424242),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onLogout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEBEE),
                          foregroundColor: const Color(0xFFE53935),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Yes, Logout',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showFaqAnswer(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCloseButton(ctx),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF616161),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  static Widget _buildCloseButton(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close, size: 16, color: Color(0xFF616161)),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final String body;

  const _AboutSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF616161),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _LegalSection({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF616161),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
