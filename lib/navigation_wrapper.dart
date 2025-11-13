import 'package:flutter/material.dart';
import 'main.dart' show DashboardScreen, ChatScreen;
import 'study_space_screen.dart';
import 'note_scanner_page.dart'; // Import the note scanner
import 'database_helper.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    ChatScreen(),
    StudySpaceScreen(),
    NoteScannerPage(),
  ];

  Future<void> clearMemory() async {
    await DatabaseHelper.instance.clearChatMemory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Home',
                  activeColor: const Color(0xFF1976D2),
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.smart_toy_rounded,
                  label: 'Agent',
                  activeColor: const Color(0xFF42A5F5),
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.menu_book_rounded,
                  label: 'Study',
                  activeColor: const Color(0xFF1565C0),
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.document_scanner_rounded,
                  label: 'Scanner',
                  activeColor: const Color(0xFF2196F3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
  }) {
    final bool isActive = _currentIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (index == 1) {
            await clearMemory();
          }
          setState(() => _currentIndex = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isActive ? 8 : 6),
                decoration: BoxDecoration(
                  color: isActive ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.grey[600],
                  size: isActive ? 26 : 24,
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? activeColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}