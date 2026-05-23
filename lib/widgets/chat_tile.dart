import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';

class ChatTile extends StatelessWidget {
  final ChatModel chat;
  final UserModel recipient;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.chat,
    required this.recipient,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
  });

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1 ||
        (difference.inDays == 0 && dateTime.day != now.day)) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('E').format(dateTime); // e.g. "Mon"
    } else {
      return DateFormat('MM/dd').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMessageText = chat.lastMessage ?? 'No messages yet';
    final timestampText = _formatTimestamp(chat.lastMessageTimestamp);
    final unreadCount = chat.getUnreadCountFor(currentUserId);
    final isOnline = recipient.status == 'online';
    final avatarColor = AppColors.getAvatarColor(recipient.displayName);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C24) : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // 1. Initials Avatar with Green Status Indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor,
                  child: Text(
                    recipient.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1C1C24)
                              : AppColors.sidebarList,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // 2. Chat Details Pane
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          recipient.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timestampText,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? AppColors.accentBlue
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lastMessageText,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Unread count badge
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.badgeBg,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
