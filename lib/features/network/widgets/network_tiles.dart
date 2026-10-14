import 'package:flutter/material.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/network/models/network_item.dart';

class ConnectionTile extends StatelessWidget {
  final ConnectionItem connection;
  final VoidCallback onTapProfile;
  final VoidCallback onMoreOptions;

  const ConnectionTile({
    super.key,
    required this.connection,
    required this.onTapProfile,
    required this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapProfile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Avatar
            AppAvatar(
              imageUrl: connection.avatarUrl,
              name: connection.name,
              radius: 26,
            ),
            const SizedBox(width: 14),

            // Name and Timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connection.connectedTimeAgo,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8E95A0),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Circular 3-dots action button
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onMoreOptions,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE6E7E8),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: Colors.black87,
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

class RequestTile extends StatelessWidget {
  final ConnectionRequestItem request;
  final VoidCallback onTapProfile;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RequestTile({
    super.key,
    required this.request,
    required this.onTapProfile,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapProfile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Avatar
            AppAvatar(
              imageUrl: request.avatarUrl,
              name: request.name,
              radius: 26,
            ),
            const SizedBox(width: 14),

            // Name and Roles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.roles,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8E95A0),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Accept & Decline Circle Action Buttons matching Figma Image 2
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accept Green Check Button
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onAccept,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1FADF),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: Color(0xFF12B76A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Decline Red Cross Button
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onDecline,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE4E2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFFF04438),
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

class NetworkSuggestionCard extends StatelessWidget {
  final NetworkSuggestionItem suggestion;
  final VoidCallback onTapProfile;
  final VoidCallback onToggleRequest;
  final VoidCallback onMoreOptions;

  const NetworkSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onTapProfile,
    required this.onToggleRequest,
    required this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FE),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tappable Avatar & Profile details
          GestureDetector(
            onTap: onTapProfile,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with white circle border
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: AppAvatar(
                    imageUrl: suggestion.avatarUrl,
                    name: suggestion.name,
                    radius: 34,
                  ),
                ),
                const SizedBox(height: 10),

                // Name
                Text(
                  suggestion.name,
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

                // Role
                Text(
                  suggestion.roles,
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
          const SizedBox(height: 12),

          // Action Row: Send Request Pill + Circular 3-dots button
          Row(
            children: [
              // Send Request Button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggleRequest,
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: suggestion.isRequested
                            ? const Color(0xFFE7F3FE)
                            : Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: suggestion.isRequested
                            ? Border.all(
                                color: const Color(0xFF3899F3),
                                width: 1.2,
                              )
                            : null,
                      ),
                      child: Text(
                        suggestion.isRequested ? 'Request Sent' : 'Send Request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: suggestion.isRequested
                              ? const Color(0xFF3899F3)
                              : Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Circular 3-dots button
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onMoreOptions,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36,
                    height: 36,
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
                      Icons.more_vert_rounded,
                      size: 18,
                      color: Color(0xFF474B51),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
