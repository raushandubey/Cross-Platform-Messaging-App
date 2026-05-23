import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../providers/auth_provider.dart';

class CustomNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const CustomNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userInitials = user?.initials ?? 'ME';
    final avatarColor = AppColors.getAvatarColor(
      user?.displayName ?? 'Pulse User',
    );

    return Container(
      width: 72,
      height: double.infinity,
      color: AppColors.sidebar,
      child: Column(
        children: [
          const SizedBox(height: 24),

          // 1. Lightning Pulse Logo at the top
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentBlue.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.flash_on, color: Colors.white, size: 24),
            ),
          ),

          const Spacer(),

          // 2. Middle Navigation Items
          _buildRailItem(
            index: 0,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
          ),
          const SizedBox(height: 20),
          _buildRailItem(
            index: 1,
            icon: Icons.people_outline_rounded,
            activeIcon: Icons.people_rounded,
          ),
          const SizedBox(height: 20),
          _buildRailItem(
            index: 2,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
          ),

          const Spacer(),

          // 3. Logout Exit Button
          IconButton(
            onPressed: () {
              // Custom styled modal confirm logout
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.cardBg,
                  title: const Text('Sign out'),
                  content: const Text('Are you sure you want to exit Pulse?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        authProvider.signOut();
                      },
                      child: const Text(
                        'Sign out',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
            tooltip: 'Sign Out',
          ),
          const SizedBox(height: 20),

          // 4. ME Profile Avatar with Green Active Dot
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onDestinationSelected(3),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarColor,
                    child: Text(
                      userInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.sidebar, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRailItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => onDestinationSelected(index),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left indicator bar
          if (isActive)
            Positioned(
              left: 0,
              width: 3,
              height: 24,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ),

          // Active icon container box with subtle glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accentBlue.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.accentBlue : AppColors.textMuted,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
