import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/navigation_rail.dart';
import '../widgets/chat_tile.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ad_banner_widget.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavIndex = 0;
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // Profile Edit & Settings State
  final _profileNameController = TextEditingController();
  bool _isSavingProfile = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _activeColorTheme = "Indigo-Cyan Gradient";

  // Selected contact detail on Desktop
  UserModel? _selectedContactForDetail;

  @override
  void initState() {
    super.initState();
    // Initialize the user ID in ChatProvider after authentication is completed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<ChatProvider>(
          context,
          listen: false,
        ).setUserId(auth.user!.uid);
        _profileNameController.text = auth.user?.displayName ?? '';
      }
    });

    _searchController.addListener(() {
      Provider.of<ChatProvider>(
        context,
        listen: false,
      ).setSearchQuery(_searchController.text);
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    Provider.of<ChatProvider>(context, listen: false).sendTextMessage(text);
    _messageController.clear();
  }

  /// Opens a list of all registered users to start a new chat
  void _openNewChatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            final users = chatProvider.getFilteredUsers();

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New conversation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Simple in-modal Search bar
                  TextField(
                    onChanged: (val) => chatProvider.setSearchQuery(val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search people...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      fillColor: AppColors.background.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: users.isEmpty
                        ? const Center(
                            child: Text(
                              'No contacts found',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final u = users[index];
                              final avatarColor = AppColors.getAvatarColor(
                                u.displayName,
                              );

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: avatarColor,
                                  child: Text(
                                    u.initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  u.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  u.status == 'online' ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    color: u.status == 'online'
                                        ? AppColors.onlineGreen
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  chatProvider.selectChatByRecipientUid(u.uid);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // ==========================================
  // DESKTOP GRID LAYOUT (3-PANES SIDE-BY-SIDE)
  // ==========================================
  Widget _buildDesktopLayout() {
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, authProvider, chatProvider, child) {
        final currentUserId = authProvider.user?.uid ?? '';
        final filteredChats = chatProvider.getFilteredChats();

        return Row(
          children: [
            // 1. Navigation Rail (Left pane)
            CustomNavigationRail(
              selectedIndex: _activeNavIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  _activeNavIndex = idx;
                });
              },
            ),
            const VerticalDivider(width: 1, color: AppColors.border),

            // 2 & 3. Dynamic Side-by-side Middle & Right Panes
            ..._buildDesktopPanes(
              authProvider,
              chatProvider,
              currentUserId,
              filteredChats,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopEmptyState() {
    return Container(
      color: AppColors.chatBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Speech Bubble Logo
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentBlue.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.12),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.accentBlue,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select a conversation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose from your chats on the left',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopChatArea(
    ChatProvider chatProvider,
    String currentUserId,
  ) {
    final recipient = chatProvider.selectedChatRecipient!;
    final messages = chatProvider.messages;
    final avatarColor = AppColors.getAvatarColor(recipient.displayName);
    final isOnline = recipient.status == 'online';

    return Container(
      color: AppColors.chatBackground,
      child: Column(
        children: [
          // A. Chat Area Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarColor,
                  child: Text(
                    recipient.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.onlineGreen
                                : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline
                                ? AppColors.onlineGreen
                                : AppColors.textMuted,
                            fontSize: 12,
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

          // B. Messages Scroll List
          Expanded(
            child: chatProvider.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
                    child: Text(
                      'Say hello to ${recipient.displayName}! 👋',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse:
                        true, // Crucial for instant updates and scroll physics!
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return ChatBubble(
                        message: msg,
                        isMe: msg.senderId == currentUserId,
                      );
                    },
                  ),
          ),

          // C. Bottom Input Send Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Attachments clip icon
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Attachments functionality mocked.'),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      fillColor: AppColors.inputBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(24),
                        ),
                        borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(24),
                        ),
                        borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        borderSide: BorderSide(
                          color: AppColors.borderFocused,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.accentBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DESKTOP SUBPANES ROUTER (CHATS, PEOPLE, SETTINGS, PROFILE)
  // ==========================================
  List<Widget> _buildDesktopPanes(
    AuthProvider authProvider,
    ChatProvider chatProvider,
    String currentUserId,
    List<ChatModel> filteredChats,
  ) {
    switch (_activeNavIndex) {
      case 0: // CHATS PANEL
        return [
          SizedBox(
            width: 320,
            child: Container(
              color: AppColors.sidebarList,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Messages',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: _openNewChatDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.accentBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: chatProvider.isLoadingChats
                        ? const Center(child: CircularProgressIndicator())
                        : filteredChats.isEmpty
                        ? const Center(
                            child: Text(
                              'No conversations',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredChats.length,
                            itemBuilder: (context, index) {
                              final chat = filteredChats[index];
                              final otherUid = chat.participants.firstWhere(
                                (id) => id != currentUserId,
                                orElse: () => '',
                              );
                              final recipient =
                                  chatProvider.getUserProfile(otherUid) ??
                                  UserModel(
                                    uid: otherUid,
                                    email: '',
                                    displayName: 'Pulse User',
                                    lastSeen: DateTime.now(),
                                  );

                              return ChatTile(
                                chat: chat,
                                recipient: recipient,
                                currentUserId: currentUserId,
                                isSelected:
                                    chatProvider.selectedChat?.id == chat.id,
                                onTap: () => chatProvider.selectChat(chat),
                              );
                            },
                          ),
                  ),
                  const AdBannerWidget(),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: chatProvider.selectedChat == null
                ? _buildDesktopEmptyState()
                : _buildDesktopChatArea(chatProvider, currentUserId),
          ),
        ];

      case 1: // PEOPLE PANEL (Registered users only!)
        final filteredUsers = chatProvider.getFilteredUsers();
        return [
          SizedBox(
            width: 320,
            child: Container(
              color: AppColors.sidebarList,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'People',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search people...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(
                            child: Text(
                              'No registered users',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final u = filteredUsers[index];
                              final avatarColor =
                                  AppColors.getAvatarColor(u.displayName);
                              final isSelected =
                                  _selectedContactForDetail?.uid == u.uid;

                              return Container(
                                color: isSelected
                                    ? AppColors.accentBlue.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      u.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    u.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    u.status == 'online' ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      color: u.status == 'online'
                                          ? AppColors.onlineGreen
                                          : AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedContactForDetail = u;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const AdBannerWidget(),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: _selectedContactForDetail == null
                ? Container(
                    color: AppColors.chatBackground,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            color: AppColors.textMuted,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Select a person',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Select a contact from the left list to view their profile details.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.chatBackground,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.getAvatarColor(
                                _selectedContactForDetail!.displayName,
                              ),
                              child: Text(
                                _selectedContactForDetail!.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _selectedContactForDetail!.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedContactForDetail!.email,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _selectedContactForDetail!.status ==
                                            'online'
                                        ? AppColors.onlineGreen
                                        : AppColors.textMuted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedContactForDetail!.status == 'online'
                                      ? 'Online'
                                      : 'Offline',
                                  style: TextStyle(
                                    color: _selectedContactForDetail!.status ==
                                            'online'
                                        ? AppColors.onlineGreen
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                chatProvider.selectChatByRecipientUid(
                                  _selectedContactForDetail!.uid,
                                );
                                setState(() {
                                  _activeNavIndex = 0;
                                });
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Send Message',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ];

      case 2: // SETTINGS PANEL
        return [
          SizedBox(
            width: 320,
            child: Container(
              color: AppColors.sidebarList,
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const ListTile(
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Privacy & Security',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(
                      Icons.palette_outlined,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Appearance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Help & Feedback',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const AdBannerWidget(),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: Container(
              color: AppColors.chatBackground,
              padding: const EdgeInsets.all(40),
              child: ListView(
                children: [
                  const Text(
                    'General Preferences',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSwitchTile(
                    title: 'Enable Notifications',
                    subtitle: 'Show push notifications for new messages.',
                    icon: Icons.notifications_none_rounded,
                    value: _notificationsEnabled,
                    onChanged: (val) {
                      setState(() {
                        _notificationsEnabled = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Notifications ${val ? 'enabled' : 'disabled'} successfully.',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  _buildSettingsSwitchTile(
                    title: 'Message Sound Alerts',
                    subtitle: 'Play notification sounds for incoming messages.',
                    icon: Icons.volume_up_outlined,
                    value: _soundEnabled,
                    onChanged: (val) {
                      setState(() {
                        _soundEnabled = val;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Appearance & Styling',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.color_lens_outlined,
                              color: AppColors.accentBlue,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Active Theme Color',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select your preferred color theme gradient for the application UI.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildThemeBadge('Indigo-Cyan Gradient', true),
                            _buildThemeBadge('Deep Purple Glow', false),
                            _buildThemeBadge('Vibrant Amber Dark', false),
                            _buildThemeBadge(
                              'Minimalist Stealth Black',
                              false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'App Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'App Version',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '1.0.0 (Production Build)',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        Divider(height: 24, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Developer License',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Apache 2.0',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

      case 3: // PROFILE PANEL
        return [
          SizedBox(
            width: 320,
            child: Container(
              color: AppColors.sidebarList,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.getAvatarColor(
                      authProvider.user?.displayName ?? 'Pulse User',
                    ),
                    child: Text(
                      authProvider.user?.initials ?? 'ME',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.user?.displayName ?? 'Pulse User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authProvider.user?.email ?? '',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.onlineGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Online Status Active',
                          style: TextStyle(
                            color: AppColors.onlineGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: Container(
              color: AppColors.chatBackground,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Edit Profile Info',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Display Name',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _profileNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter name...',
                          fillColor: AppColors.inputBg,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSavingProfile
                            ? null
                            : () async {
                                setState(() {
                                  _isSavingProfile = true;
                                });
                                final success = await authProvider.updateProfile(
                                  _profileNameController.text,
                                  'online',
                                );
                                setState(() {
                                  _isSavingProfile = false;
                                });
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Profile updated successfully!'
                                          : 'Failed to update profile.',
                                    ),
                                  ),
                                );
                              },
                        child: _isSavingProfile
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 48),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          authProvider.signOut();
                        },
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        label: const Text(
                          'Sign Out of Pulse',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];

      default:
        return [const SizedBox.shrink()];
    }
  }

  Widget _buildSettingsSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        secondary: Icon(icon, color: AppColors.accentBlue),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.accentBlue,
        activeTrackColor: AppColors.accentBlue.withValues(alpha: 0.3),
        inactiveTrackColor: Colors.white10,
        inactiveThumbColor: AppColors.textMuted,
      ),
    );
  }

  Widget _buildThemeBadge(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.accentBlue.withValues(alpha: 0.12) : AppColors.sidebar,
        border: Border.all(
          color: active ? AppColors.accentBlue : AppColors.border,
          width: active ? 1.5 : 0.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : AppColors.textMuted,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE ADAPTIVE VIEW LAYOUT (SINGLE-PANE GRID)
  // ==========================================
  Widget _buildMobileLayout() {
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, authProvider, chatProvider, child) {
        final currentUserId = authProvider.user?.uid ?? '';
        final filteredChats = chatProvider.getFilteredChats();
        final filteredUsers = chatProvider.getFilteredUsers();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.sidebar,
            title: Text(
              _activeNavIndex == 0
                  ? 'Messages'
                  : _activeNavIndex == 1
                  ? 'People'
                  : _activeNavIndex == 2
                  ? 'Settings'
                  : 'Profile',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: false,
            actions: [
              if (_activeNavIndex == 0)
                IconButton(
                  onPressed: _openNewChatDialog,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.accentBlue,
                    size: 26,
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: _activeNavIndex <= 1
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Main dynamic pane based on bottom nav
          body: Column(
            children: [
              Expanded(
                child: _buildMobileTabBody(
                  chatProvider,
                  currentUserId,
                  filteredChats,
                  filteredUsers,
                  authProvider,
                ),
              ),
              const AdBannerWidget(),
            ],
          ),

          // Platform Adaptive Bottom Navigation bar
          bottomNavigationBar: Theme(
            data: Theme.of(context).copyWith(canvasColor: AppColors.sidebar),
            child: BottomNavigationBar(
              currentIndex: _activeNavIndex,
              onTap: (index) {
                setState(() {
                  _activeNavIndex = index;
                });
              },
              backgroundColor: AppColors.sidebar,
              selectedItemColor: AppColors.accentBlue,
              unselectedItemColor: AppColors.textMuted,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  activeIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Chats',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline_rounded),
                  activeIcon: Icon(Icons.people_rounded),
                  label: 'People',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileTabBody(
    ChatProvider chatProvider,
    String currentUserId,
    List<ChatModel> filteredChats,
    List<UserModel> filteredUsers,
    AuthProvider authProvider,
  ) {
    switch (_activeNavIndex) {
      case 0: // Chats List
        return chatProvider.isLoadingChats
            ? const Center(child: CircularProgressIndicator())
            : filteredChats.isEmpty
            ? const Center(
                child: Text(
                  'No active chats yet. Start one!',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : ListView.builder(
                itemCount: filteredChats.length,
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  final otherUid = chat.participants.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => '',
                  );
                  final recipient =
                      chatProvider.getUserProfile(otherUid) ??
                      UserModel(
                        uid: otherUid,
                        email: '',
                        displayName: 'Pulse User',
                        lastSeen: DateTime.now(),
                      );

                  return ChatTile(
                    chat: chat,
                    recipient: recipient,
                    currentUserId: currentUserId,
                    isSelected: false,
                    onTap: () async {
                      // Select the chat and then push the full mobile chat screen!
                      final nav = Navigator.of(context);
                      await chatProvider.selectChat(chat);
                      nav.push(
                        MaterialPageRoute(
                          builder: (context) => const MobileChatScreen(),
                        ),
                      );
                    },
                  );
                },
              );
      case 1: // Contacts/People List
        return filteredUsers.isEmpty
            ? const Center(
                child: Text(
                  'No contacts found',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final u = filteredUsers[index];
                  final avatarColor = AppColors.getAvatarColor(u.displayName);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: avatarColor,
                      child: Text(
                        u.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      u.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      u.status == 'online' ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: u.status == 'online'
                            ? AppColors.onlineGreen
                            : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await chatProvider.selectChatByRecipientUid(u.uid);
                      nav.push(
                        MaterialPageRoute(
                          builder: (context) => const MobileChatScreen(),
                        ),
                      );
                    },
                  );
                },
              );
      case 2: // SETTINGS
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildSettingsTile(
                Icons.notifications_active_outlined,
                'Notifications',
                _notificationsEnabled ? 'Active alerts enabled' : 'Alerts disabled',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.cardBg,
                    builder: (context) => StatefulBuilder(
                      builder: (context, setModalState) => Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Notification Preferences', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            SwitchListTile(
                              title: const Text('Show Banners', style: TextStyle(color: Colors.white)),
                              value: _notificationsEnabled,
                              activeThumbColor: AppColors.accentBlue,
                              onChanged: (val) {
                                setState(() {
                                  _notificationsEnabled = val;
                                });
                                setModalState(() {});
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Play Sounds', style: TextStyle(color: Colors.white)),
                              value: _soundEnabled,
                              activeThumbColor: AppColors.accentBlue,
                              onChanged: (val) {
                                setState(() {
                                  _soundEnabled = val;
                                });
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                Icons.lock_outline_rounded,
                'Privacy & Security',
                'End-to-end encrypted chats',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.cardBg,
                      title: const Text('End-to-End Encryption'),
                      content: const Text('Pulse guarantees that all messages sent are encrypted end-to-end. Neither Pulse nor any third party can read your conversations.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it', style: TextStyle(color: AppColors.accentBlue)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                Icons.palette_outlined,
                'Appearance',
                'Theme: $_activeColorTheme',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.cardBg,
                    builder: (context) => Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Appearance Options', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ListTile(
                            title: const Text('Indigo-Cyan Gradient', style: TextStyle(color: Colors.white)),
                            trailing: _activeColorTheme == 'Indigo-Cyan Gradient' ? const Icon(Icons.check, color: AppColors.accentBlue) : null,
                            onTap: () {
                              setState(() { _activeColorTheme = 'Indigo-Cyan Gradient'; });
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text('Deep Purple Glow', style: TextStyle(color: Colors.white)),
                            trailing: _activeColorTheme == 'Deep Purple Glow' ? const Icon(Icons.check, color: AppColors.accentBlue) : null,
                            onTap: () {
                              setState(() { _activeColorTheme = 'Deep Purple Glow'; });
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                Icons.help_outline_rounded,
                'Help & Feedback',
                'Version 1.0.0',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Pulse Messaging',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.flash_on, color: AppColors.accentBlue, size: 40),
                    children: const [
                      Text('A high-fidelity cross-platform messaging application designed with modern aesthetics and state of the art responsive layouts.'),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      case 3: // PROFILE PAGE
        final u = authProvider.user;
        final avatarColor = AppColors.getAvatarColor(
          u?.displayName ?? 'Pulse User',
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: avatarColor,
                child: Text(
                  u?.initials ?? 'ME',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                u?.email ?? '',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Display Name',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _profileNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter name...',
                        fillColor: AppColors.inputBg,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSavingProfile
                          ? null
                          : () async {
                              setState(() {
                                _isSavingProfile = true;
                              });
                              final success = await authProvider.updateProfile(
                                _profileNameController.text,
                                'online',
                              );
                              setState(() {
                                _isSavingProfile = false;
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Profile updated successfully!'
                                        : 'Failed to update profile.',
                                  ),
                                ),
                              );
                            },
                      child: _isSavingProfile
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Profile Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              OutlinedButton(
                onPressed: () => authProvider.signOut(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 16,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out of Pulse',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accentBlue),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textMuted,
          size: 14,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
