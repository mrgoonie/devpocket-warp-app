import 'package:flutter/material.dart';

/// Service for managing terminal viewport calculations and responsive behavior.
/// Handles optimal height constraints and viewport optimization for mobile devices.
class TerminalViewportManager {
  /// Calculates the maximum height for welcome message containers.
  /// Ensures the terminal input area remains accessible by limiting welcome message height.
  /// 
  /// Returns a height that is at most 40% of the available screen height,
  /// with reserved space for header, input area, and system UI.
  static double calculateMaxWelcomeHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeArea = MediaQuery.of(context).padding;
    final availableHeight = screenHeight - safeArea.top - safeArea.bottom;
    
    // Reserve space for:
    // - Terminal header/status bar (~80px)
    // - Input area (~120px)
    // - Padding and margins (~40px)
    const reservedSpace = 240;
    final remainingHeight = availableHeight - reservedSpace;
    
    // Use maximum 40% of remaining space for welcome messages
    final maxWelcomeHeight = remainingHeight * 0.4;
    
    // Ensure minimum usable height (100px) and maximum reasonable height
    return maxWelcomeHeight.clamp(100.0, 400.0);
  }
  
  /// Determines if a welcome message should use scrollable container
  /// based on estimated content height.
  static bool shouldUseScrollableWelcome(String content, double fontSize) {
    if (content.isEmpty) return false;
    
    // Rough estimation based on character count and line breaks
    final lines = content.split('\n').length;
    final estimatedLinesFromLength = (content.length / 80).ceil(); // ~80 chars per line
    final totalEstimatedLines = (lines + estimatedLinesFromLength) / 2; // Average estimate
    
    // Calculate estimated height (line height ~1.4x font size)
    final estimatedHeight = totalEstimatedLines * fontSize * 1.4;
    
    // Use scrollable if estimated height > 300px
    return estimatedHeight > 300;
  }
  
  /// Calculates optimal constraints for welcome message containers
  /// based on current viewport and content characteristics.
  static BoxConstraints calculateWelcomeConstraints(
    BuildContext context, {
    String content = '',
    double fontSize = 14.0,
    bool isExpandable = false,
  }) {
    final maxHeight = calculateMaxWelcomeHeight(context);
    final shouldScroll = shouldUseScrollableWelcome(content, fontSize);
    
    if (shouldScroll) {
      // For scrollable content, use strict height limits
      return BoxConstraints(
        minHeight: 100,
        maxHeight: maxHeight,
      );
    } else if (isExpandable) {
      // For expandable content, provide more flexible constraints
      return BoxConstraints(
        minHeight: 50, // Reduced minimum for better flexibility
        maxHeight: maxHeight * 0.8, // More generous height for expansion
      );
    } else {
      // For standard short content, allow natural height up to reasonable limit
      return BoxConstraints(
        minHeight: 60,
        maxHeight: maxHeight * 0.6, // Use 60% of max for non-scrollable
      );
    }
  }
  
  /// Returns responsive padding values based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 360) {
      // Small screens (iPhone SE)
      return const EdgeInsets.all(8);
    } else if (width < 768) {
      // Medium screens (standard phones)
      return const EdgeInsets.all(12);
    } else {
      // Large screens (tablets)
      return const EdgeInsets.all(16);
    }
  }
  
  /// Handles orientation change notifications and recalculates constraints
  static void handleOrientationChange(BuildContext context, VoidCallback onUpdate) {
    // Force recalculation of viewport constraints
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onUpdate();
    });
  }
  
  /// Gets optimal font size scaling for different screen sizes
  static double getFontSizeScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 360) {
      return 0.85; // Slightly smaller text on very small screens
    } else if (width > 768) {
      return 1.1; // Slightly larger text on tablets
    }
    
    return 1.0; // Standard scaling for normal phones
  }
}