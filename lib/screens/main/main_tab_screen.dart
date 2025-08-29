import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../vaults/vaults_screen.dart';
import '../terminal/enhanced_terminal_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'coming_soon_screen.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;

  final List<TabItem> _tabs = const [
    TabItem(
      icon: Icons.folder_special,
      activeIcon: Icons.folder_special,
      label: 'Vaults',
      screen: VaultsScreen(),
    ),
    TabItem(
      icon: Icons.terminal,
      activeIcon: Icons.terminal,
      label: 'Terminal',
      screen: EnhancedTerminalScreen(),
    ),
    TabItem(
      icon: Icons.history,
      activeIcon: Icons.history,
      label: 'History',
      screen: HistoryScreen(),
    ),
    TabItem(
      icon: Icons.code,
      activeIcon: Icons.code,
      label: 'Editor',
      screen: ComingSoonScreen(feature: 'Code Editor'),
    ),
    TabItem(
      icon: Icons.settings,
      activeIcon: Icons.settings,
      label: 'Settings',
      screen: SettingsScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
    
    // Ensure onboarding is marked as completed when authenticated user reaches main screen
    _ensureOnboardingCompleted();
  }
  
  void _ensureOnboardingCompleted() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final onboardingCompleted = ref.read(onboardingProvider);
        if (!onboardingCompleted) {
          debugPrint('🔧 Marking onboarding as completed for authenticated user');
          await ref.read(onboardingProvider.notifier).completeOnboarding();
        }
      } catch (e) {
        debugPrint('Error ensuring onboarding completion: $e');
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      // If tapping the same tab, do nothing or implement scroll to top
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: _tabs.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return _tabs[index].screen;
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          top: BorderSide(
            color: context.isDarkMode
                ? AppTheme.darkBorderColor
                : AppTheme.lightBorderColor,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: _tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isSelected = index == _currentIndex;

              return Expanded(
                child: _buildTabButton(
                  tab: tab,
                  index: index,
                  isSelected: isSelected,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required TabItem tab,
    required int index,
    required bool isSelected,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 16; // Account for horizontal padding
    final tabWidth = availableWidth / _tabs.length;
    
    // Use icon-only mode if tab width is too small or screen is narrow
    final useIconOnlyMode = tabWidth < 70 || screenWidth < 360;
    
    // Calculate dynamic font size based on available space
    final baseFontSize = useIconOnlyMode ? 10.0 : 11.0;
    final fontSize = (tabWidth < 80 && !useIconOnlyMode) 
        ? (baseFontSize * (tabWidth / 80)).clamp(8.0, baseFontSize)
        : baseFontSize;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: useIconOnlyMode ? 4 : 6, 
          vertical: 4
        ),
        constraints: const BoxConstraints(
          minWidth: 44, // Minimum tap target size
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppTheme.primaryColor,
                  width: 1,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with flexible sizing
            Flexible(
              flex: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Icon(
                  isSelected ? tab.activeIcon : tab.icon,
                  size: useIconOnlyMode ? 24 : 22,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : context.isDarkMode
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                  semanticLabel: useIconOnlyMode ? tab.label : null,
                ),
              ),
            ),
            
            // Only show label and spacing in non-icon-only mode
            if (!useIconOnlyMode) ...[
              const SizedBox(height: 2),
              
              // Label with flexible sizing to prevent overflow
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  style: context.textTheme.labelSmall!.copyWith(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : context.isDarkMode
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: fontSize,
                    height: 1.0, // Reduce line height
                  ),
                  child: Text(
                    tab.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              // Active Indicator with reduced margin
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(top: 1),
                height: 2,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ] else if (isSelected) ...[
              // Show a smaller indicator for icon-only mode
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(top: 2),
                height: 3,
                width: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;

  const TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
  });
}

// Custom bottom navigation bar with neobrutalism style
class NeobrutalismBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<TabItem> tabs;
  final Function(int) onTap;

  const NeobrutalismBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isSelected = index == currentIndex;

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: Colors.black,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? tab.activeIcon : tab.icon,
                        size: 24,
                        color: isSelected ? Colors.black : AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: isSelected ? Colors.black : AppTheme.darkTextSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Tab navigation helper
class TabNavigationHelper {
  static void navigateToTab(BuildContext context, int tabIndex) {
    final mainTabScreenState = context.findAncestorStateOfType<_MainTabScreenState>();
    mainTabScreenState?._onTabTapped(tabIndex);
  }

  static const int vaultsTab = 0;
  static const int terminalTab = 1;
  static const int historyTab = 2;
  static const int editorTab = 3;
  static const int settingsTab = 4;
}