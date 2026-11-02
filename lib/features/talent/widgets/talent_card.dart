import 'package:flutter/material.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

class TalentCard extends StatelessWidget {
  final TalentModel talent;
  final VoidCallback onTapProfile;
  final VoidCallback onConnect;
  final VoidCallback onMessage;

  const TalentCard({
    super.key,
    required this.talent,
    required this.onTapProfile,
    required this.onConnect,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isProd = talent.isProductionHouse ||
        talent.roles.toLowerCase().contains('production') ||
        talent.roles.toLowerCase().contains('studio');

    String buttonText;
    Color buttonBg;
    Color buttonTextColor;
    Border? buttonBorder;

    if (isProd) {
      if (talent.isFollowing) {
        buttonText = 'Following';
        buttonBg = const Color(0xFFE7F3FE);
        buttonTextColor = const Color(0xFF3899F3);
        buttonBorder = Border.all(color: const Color(0xFF3899F3), width: 1.2);
      } else {
        buttonText = 'Follow';
        buttonBg = Colors.black;
        buttonTextColor = Colors.white;
        buttonBorder = null;
      }
    } else {
      switch (talent.connectionStatus) {
        case ConnectionStatus.none:
          buttonText = 'Connect';
          buttonBg = Colors.black;
          buttonTextColor = Colors.white;
          buttonBorder = null;
          break;
        case ConnectionStatus.pendingOutgoing:
          buttonText = 'Request Sent';
          buttonBg = const Color(0xFFE7F3FE);
          buttonTextColor = const Color(0xFF3899F3);
          buttonBorder = Border.all(color: const Color(0xFF3899F3), width: 1.2);
          break;
        case ConnectionStatus.pendingIncoming:
          buttonText = 'Accept';
          buttonBg = const Color(0xFF3899F3);
          buttonTextColor = Colors.white;
          buttonBorder = null;
          break;
        case ConnectionStatus.connected:
          buttonText = 'Connected';
          buttonBg = const Color(0xFFE7F3FE);
          buttonTextColor = const Color(0xFF3899F3);
          buttonBorder = Border.all(color: const Color(0xFF3899F3), width: 1.2);
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FE),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Tappable Avatar & Info Section opening Profile
          GestureDetector(
            onTap: onTapProfile,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with white circular border
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: AppAvatar(
                    imageUrl: talent.avatarUrl,
                    name: talent.name,
                    radius: 34,
                  ),
                ),
                const SizedBox(height: 8),

                // Talent Name
                Text(
                  talent.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),

                // Talent Roles / Profession
                Text(
                  talent.roles,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8E95A0),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons: Connect Pill + Mail Box
          Row(
            children: [
              // Connect / Follow Button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onConnect,
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: buttonBg,
                        borderRadius: BorderRadius.circular(20),
                        border: buttonBorder,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          buttonText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: buttonTextColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mail Icon Button with circular border
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onMessage,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE6E7E8),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      size: 17,
                      color: Color(0xFF474B51),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}
