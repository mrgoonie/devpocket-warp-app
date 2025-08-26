# [Bug Fix] Auth Token Refresh and SSH Connection Issues Implementation Plan

**Date**: 2025-08-26  
**Type**: Bug Fix  
**Priority**: Critical  
**Context Tokens**: These issues prevent users from authenticating properly and connecting to SSH hosts, severely impacting core functionality.

## Executive Summary
Three critical issues are preventing proper authentication and SSH functionality in the DevPocket Flutter app:
1. Auth token refresh fails when expired tokens are detected, causing app to clear tokens instead of refreshing
2. SSH connection listener throws Riverpod error due to incorrect `ref.listen` usage
3. SSH profile deletion doesn't handle server errors gracefully, causing widget lifecycle crashes

## Issue Analysis

### Issue 1: Auth Token Refresh Failure
#### Symptoms
- [x] App clears tokens when AUTH_FAILED is received instead of attempting refresh
- [x] Users are logged out unexpectedly when tokens expire
- [x] API returns `{"success":false,"message":"Authentication failed","code":"AUTH_FAILED"}`

#### Root Cause
In `EnhancedAuthService.getCurrentUser()` (line 37-40), when authentication fails, the service immediately clears tokens without attempting to refresh them first. The API client has token refresh logic in the interceptor, but it's not being triggered properly.

#### Evidence
- **File**: `lib/services/enhanced_auth_service.dart:37-40`
- **Issue**: Calls `_clearInvalidTokens()` immediately on AUTH_FAILED
- **Missing**: Should trigger token refresh before clearing

### Issue 2: SSH Connection Riverpod Listener Error
#### Symptoms
- [x] Widget exception when clicking SSH profile to connect
- [x] Error: "ref.listen can only be used within the build method of a ConsumerWidget"
- [x] Location: `lib/screens/terminal/terminal_screen.dart:129`

#### Root Cause
`ref.listen` is being called in `didChangeDependencies()` lifecycle method (line 106) instead of the `build` method. In Riverpod, listeners must be set up during the build phase.

#### Evidence
- **File**: `lib/screens/terminal/terminal_screen.dart:127-138`
- **Issue**: `_setupSshConnectionListener()` called in `didChangeDependencies()`
- **Required**: Move to build method or use proper Riverpod patterns

### Issue 3: SSH Profile Deletion Error Handling
#### Symptoms
- [x] App crashes when deleting non-existent SSH profile
- [x] Error: "SSH profile not found or access denied" from server
- [x] Unsafe ancestor lookup error when showing SnackBar

#### Root Cause
When SSH profile deletion fails on server, the error handling tries to show a SnackBar but the widget may be deactivated. Additionally, the service doesn't properly handle 404 responses.

#### Evidence
- **File**: `lib/screens/vaults/hosts_list_screen.dart:698-719`
- **Issue**: SnackBar shown without checking `mounted` properly
- **File**: `lib/services/ssh_host_service.dart:221-240`
- **Issue**: Removes from cache even on API failure

## Solution Design

### Approach
1. Implement proper token refresh flow in auth service before clearing tokens
2. Refactor SSH connection listeners to use Riverpod's recommended patterns
3. Add proper error handling and mounted checks for SSH profile deletion

### Changes Required

#### 1. Auth Token Refresh Fix
**File**: `lib/services/enhanced_auth_service.dart`
- Modify `getCurrentUser()` to attempt token refresh before clearing
- Add `refreshTokens()` method that calls API client's refresh logic
- Update error handling flow to differentiate between refresh failure and auth failure

**File**: `lib/services/api_client.dart`
- Ensure `_handleTokenRefresh()` is properly exposed for auth service
- Fix response handling in interceptor to properly detect AUTH_FAILED

#### 2. SSH Connection Listener Fix
**File**: `lib/screens/terminal/terminal_screen.dart`
- Remove `_setupSshConnectionListener()` from `didChangeDependencies()`
- Move listeners to build method or use `ConsumerStatefulWidget` properly
- Consider using `ref.watch` instead of `ref.listen` where appropriate

#### 3. SSH Profile Deletion Error Handling
**File**: `lib/screens/vaults/hosts_list_screen.dart`
- Add proper mounted checks before showing SnackBar
- Handle async operations properly in dialog callbacks
- Add try-catch for deletion failures

**File**: `lib/services/ssh_host_service.dart`
- Don't remove from cache if server deletion fails (except for 404)
- Add proper error message parsing for better user feedback

### Testing Changes
- [ ] Add unit tests for token refresh flow
- [ ] Add widget tests for SSH connection lifecycle
- [ ] Add integration tests for SSH profile deletion scenarios

## Implementation Steps

### Phase 1: Auth Token Refresh Fix
1. [ ] Update `EnhancedAuthService.getCurrentUser()` - file: `lib/services/enhanced_auth_service.dart`
   ```dart
   // Lines 26-48: Replace current implementation
   Future<User?> getCurrentUser() async {
     try {
       final response = await _apiClient.get<User>(
         '/auth/me',
         fromJson: (json) => User.fromJson(json),
       );
       
       if (response.isSuccess) {
         return response.data;
       }
       
       // Check if it's an auth failure that might be resolved by refresh
       if (response.errorMessage.contains('AUTH_FAILED') || 
           response.statusCode == 401) {
         debugPrint('Auth failed, attempting token refresh...');
         
         // Attempt token refresh
         final refreshed = await refreshTokens();
         if (refreshed) {
           // Retry the request with new tokens
           final retryResponse = await _apiClient.get<User>(
             '/auth/me',
             fromJson: (json) => User.fromJson(json),
           );
           
           if (retryResponse.isSuccess) {
             return retryResponse.data;
           }
         }
         
         // If refresh failed or retry failed, clear tokens
         debugPrint('Token refresh failed, clearing tokens...');
         await _clearInvalidTokens();
       }
       
       debugPrint('Get current user failed: ${response.errorMessage}');
       return null;
     } catch (e) {
       debugPrint('Error getting current user: $e');
       return null;
     }
   }
   ```

2. [ ] Add `refreshTokens()` method - file: `lib/services/enhanced_auth_service.dart`
   ```dart
   // Add after line 58
   Future<bool> refreshTokens() async {
     try {
       return await _apiClient.refreshTokens();
     } catch (e) {
       debugPrint('Token refresh failed in auth service: $e');
       return false;
     }
   }
   ```

3. [ ] Expose refresh method in API client - file: `lib/services/api_client.dart`
   ```dart
   // Add after line 168
   Future<bool> refreshTokens() async {
     return await _handleTokenRefresh();
   }
   ```

### Phase 2: SSH Connection Listener Fix
1. [ ] Refactor terminal screen to use proper Riverpod patterns - file: `lib/screens/terminal/terminal_screen.dart`
   ```dart
   // Lines 61-68: Keep ConsumerStatefulWidget
   
   // Lines 92-107: Remove from didChangeDependencies
   @override
   void didChangeDependencies() {
     super.didChangeDependencies();
     
     // Watch for SSH profile connections after providers are available
     _handleSshProfileConnection();
     
     // Remove this line - will be handled in build
     // _setupSshConnectionListener();
   }
   
   // Add to build method or create separate widget method
   // After line 1000 (in build method, before return)
   void _setupListeners(WidgetRef ref) {
     // Listen to SSH connection status changes
     ref.listen<SshTerminalConnectionState>(
       sshTerminalConnectionProvider,
       (previous, next) {
         _handleSshConnectionStateChange(previous, next);
       },
     );
     
     // Listen to SSH output changes
     ref.listen<String>(
       sshTerminalOutputProvider,
       (previous, next) {
         if (next.isNotEmpty && next != previous) {
           _handleSshOutput(next);
         }
       },
     );
   }
   
   // In build method, add before the return statement
   @override
   Widget build(BuildContext context) {
     // Add this at the beginning of build
     _setupListeners(ref);
     
     // ... rest of build method
   }
   ```

### Phase 3: SSH Profile Deletion Error Handling Fix
1. [ ] Fix mounted checks in hosts list screen - file: `lib/screens/vaults/hosts_list_screen.dart`
   ```dart
   // Lines 698-720: Update delete action
   ElevatedButton(
     onPressed: () async {
       Navigator.pop(context);
       
       // Store context before async operation
       final scaffoldMessenger = ScaffoldMessenger.of(context);
       
       try {
         final success = await ref.read(sshHostsProvider.notifier).deleteHost(host.id);
         
         // No need for mounted check with stored messenger
         if (success) {
           scaffoldMessenger.showSnackBar(
             const SnackBar(
               content: Text('Host deleted successfully'),
               backgroundColor: AppTheme.terminalGreen,
             ),
           );
         } else {
           scaffoldMessenger.showSnackBar(
             const SnackBar(
               content: Text('Failed to delete host. It may not exist on the server.'),
               backgroundColor: AppTheme.terminalRed,
             ),
           );
         }
       } catch (e) {
         debugPrint('Error deleting host: $e');
         scaffoldMessenger.showSnackBar(
           SnackBar(
             content: Text('Error: ${e.toString()}'),
             backgroundColor: AppTheme.terminalRed,
           ),
         );
       }
     },
     style: ElevatedButton.styleFrom(
       backgroundColor: AppTheme.terminalRed,
     ),
     child: const Text('Delete'),
   ),
   ```

2. [ ] Improve error handling in SSH host service - file: `lib/services/ssh_host_service.dart`
   ```dart
   // Lines 221-240: Update deleteHost method
   Future<bool> deleteHost(String id) async {
     try {
       final response = await _apiClient.delete('/ssh/profiles/$id');
       
       if (response.isSuccess) {
         await _removeFromCache(id);
         return true;
       }
       
       // Check if it's a 404 (profile doesn't exist)
       if (response.statusCode == 404 || 
           response.errorMessage.contains('not found')) {
         debugPrint('SSH profile not found on server, removing from cache');
         await _removeFromCache(id);
         return true; // Consider it successful if already deleted
       }
       
       debugPrint('Delete SSH host failed: ${response.errorMessage}');
       // Don't remove from cache for other errors
       return false;
       
     } catch (e) {
       debugPrint('Error deleting SSH host: $e');
       return false;
     }
   }
   ```

## Verification Plan

### Test Cases
1. [ ] **Auth Token Refresh Test**
   - Start app with valid tokens
   - Manually expire access token in storage
   - Navigate to authenticated screen
   - Verify token is refreshed (not cleared)
   - Verify user remains logged in

2. [ ] **SSH Connection Test**
   - Open terminal screen
   - Click on SSH profile to connect
   - Verify no Riverpod listener errors
   - Verify connection establishes properly
   - Test multiple connections/disconnections

3. [ ] **SSH Profile Deletion Test**
   - Create test SSH profile
   - Delete from app
   - Verify success message
   - Delete non-existent profile
   - Verify proper error handling (no crash)
   - Verify SnackBar shows correctly

### Regression Tests
- [ ] Verify normal login/logout flow still works
- [ ] Verify SSH profile creation/update still works
- [ ] Verify terminal commands still execute properly
- [ ] Run existing test suite: `flutter test`

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Token refresh loop | High | Add max retry counter (2-3 attempts) |
| Breaking existing auth flow | High | Comprehensive testing of all auth scenarios |
| Performance impact from listeners | Medium | Use computed providers where possible |
| Race conditions in deletion | Medium | Add proper async/await and error boundaries |

## Rollback Plan
If issues are discovered after implementation:
1. Revert commits for each phase independently
2. Auth fix: `git revert <auth-commit-hash>`
3. SSH listener fix: `git revert <listener-commit-hash>`
4. Deletion fix: `git revert <deletion-commit-hash>`
5. Re-deploy previous working version
6. Investigate issues in staging environment

## TODO Checklist

### Pre-Implementation
- [ ] Review current auth flow documentation
- [ ] Backup current working state
- [ ] Set up test environment

### Implementation
- [x] Phase 1: Implement auth token refresh fix
- [x] Phase 2: Fix SSH connection listeners
- [x] Phase 3: Fix SSH profile deletion handling
- [ ] Update relevant documentation

### Testing
- [ ] Run unit tests for auth service
- [ ] Run widget tests for terminal screen
- [ ] Run integration tests for SSH operations
- [ ] Manual testing of all three issues
- [ ] Performance testing for listeners

### Deployment
- [ ] Code review by team
- [ ] Deploy to staging environment
- [ ] Verify fixes in staging
- [ ] Deploy to production
- [ ] Monitor error logs for 24 hours

## Success Criteria
- No AUTH_FAILED errors cause immediate logout
- No Riverpod listener errors in terminal screen
- SSH profile deletion handles all error cases gracefully
- All existing functionality remains intact
- Test coverage maintained or improved

## Notes
- Consider implementing a more robust token management system in future
- May want to add retry logic for SSH operations
- Consider adding user-facing error recovery suggestions