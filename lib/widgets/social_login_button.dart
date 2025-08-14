import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../main.dart';

class SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;

  const SocialLoginButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? AppTheme.darkSurface;
    final effectiveTextColor = textColor ?? AppTheme.darkTextPrimary;
    final effectiveIconColor = iconColor ?? AppTheme.darkTextSecondary;

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          side: const BorderSide(
            color: AppTheme.darkBorderColor,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: effectiveIconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: effectiveTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Specialized social login buttons
class GoogleLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleLoginButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SocialLoginButton(
      icon: Icons.alternate_email, // Placeholder - in real app use Google icon
      label: 'Google',
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      iconColor: Colors.red,
    );
  }
}

class GitHubLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GitHubLoginButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SocialLoginButton(
      icon: Icons.code, // Placeholder - in real app use GitHub icon
      label: 'GitHub',
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: const Color(0xFF24292E),
      textColor: Colors.white,
      iconColor: Colors.white,
    );
  }
}

class AppleLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppleLoginButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SocialLoginButton(
      icon: Icons.apple, // Use Apple icon
      label: 'Apple',
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      iconColor: Colors.white,
    );
  }
}

// Social login section widget for auth screens
class SocialLoginSection extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final VoidCallback? onGitHubPressed;
  final VoidCallback? onApplePressed;
  final bool isLoading;
  final String dividerText;

  const SocialLoginSection({
    super.key,
    this.onGooglePressed,
    this.onGitHubPressed,
    this.onApplePressed,
    this.isLoading = false,
    this.dividerText = 'OR',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider with text
        Row(
          children: [
            const Expanded(
              child: Divider(color: AppTheme.darkBorderColor),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                dividerText,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.darkTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: AppTheme.darkBorderColor),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Social login buttons
        Row(
          children: [
            if (onGooglePressed != null) ...[
              Expanded(
                child: GoogleLoginButton(
                  onPressed: onGooglePressed,
                  isLoading: isLoading,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (onGitHubPressed != null) ...[
              Expanded(
                child: GitHubLoginButton(
                  onPressed: onGitHubPressed,
                  isLoading: isLoading,
                ),
              ),
            ],
            if (onApplePressed != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppleLoginButton(
                  onPressed: onApplePressed,
                  isLoading: isLoading,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}