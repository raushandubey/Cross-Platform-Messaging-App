import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';

class MobileChatScreen extends StatefulWidget {
  const MobileChatScreen({super.key});

  @override
  State<MobileChatScreen> createState() => _MobileChatScreenState();
}

class _MobileChatScreenState extends State<MobileChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    Provider.of<ChatProvider>(context, listen: false).sendTextMessage(text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, authProvider, chatProvider, child) {
        final currentUserId = authProvider.user?.uid ?? '';
        final recipient = chatProvider.selectedChatRecipient;
        final messages = chatProvider.messages;

        // Graceful fallback in case chat deselected or recipient is null during transition pop
        if (recipient == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final avatarColor = AppColors.getAvatarColor(recipient.displayName);
        final isOnline = recipient.status == 'online';

        return PopScope<Object?>(
          canPop: true,
          // Triggers when physical Android back button is clicked or swipe-to-back on iOS
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) {
              chatProvider.deselectChat(); // Re-enable background notifications!
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.chatBackground,
            
            // 1. Mobile Chat Header
            appBar: AppBar(
              backgroundColor: AppColors.sidebar,
              elevation: 0,
              leading: IconButton(
                onPressed: () {
                  chatProvider.deselectChat(); // Clean suppression
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
              titleSpacing: 0,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: avatarColor,
                    child: Text(
                      recipient.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOnline ? AppColors.onlineGreen : AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isOnline ? AppColors.onlineGreen : AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Message List Area
            body: Column(
              children: [
                Expanded(
                  child: _buildMessagesList(
                    chatProvider,
                    currentUserId,
                    recipient,
                    messages,
                  ),
                ),

                // 3. Message Input bar (Responsive clip controls)
                Container(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.sidebar,
                    border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Attachments functionality mocked.')),
                          );
                        },
                        icon: const Icon(Icons.attach_file_rounded, color: AppColors.textMuted, size: 22),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onSubmitted: (_) => _sendMessage(),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            fillColor: AppColors.inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(24)),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(24)),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                              borderSide: BorderSide(color: AppColors.borderFocused, width: 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.accentBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Private helper to render the messages list viewport cleanly
  Widget _buildMessagesList(
    ChatProvider chatProvider,
    String currentUserId,
    UserModel recipient,
    List<MessageModel> messages,
  ) {
    if (chatProvider.isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Say hello to ${recipient.displayName}! 👋',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Auto-scroll physics
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return ChatBubble(
          message: msg,
          isMe: msg.senderId == currentUserId,
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
