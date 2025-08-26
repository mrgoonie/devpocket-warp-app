# SSH Profile Data Synchronization (Phase 2) Implementation Plan

**Date:** 2025-08-25  
**Type:** Feature Enhancement  
**Priority:** High  
**Estimated Time:** 4-6 hours  

## Problem Statement

### Current Issues
- **Data Inconsistency**: Local storage contains SSH profiles that aren't synchronized with the server
- **API Mismatch**: Local storage shows 1 SSH host while API returns `{"success":true,"data":{"profiles":[],"total":0}}`
- **No Upload Sync**: Local profiles are not being uploaded to server automatically
- **Limited Conflict Resolution**: Current sync strategy has minimal conflict handling
- **User Experience**: Users see inconsistent data between local and remote states

### Impact
- Users lose access to their SSH profiles across devices
- Data inconsistency causes confusion and trust issues
- Offline-created profiles remain isolated locally
- No clear sync status feedback for users

## Solution Overview

Implement comprehensive bidirectional SSH profile synchronization with intelligent conflict resolution, user control, and transparent sync status feedback.

## Technical Implementation Plan

### Phase 1: Service Layer Enhancement

#### 1.1 Enhanced SSH Host Service (`lib/services/ssh_host_service.dart`)

**A. Modify `getHosts()` method:**
```dart
Future<List<SshProfile>> getHosts({bool forceSync = false}) async {
  try {
    // Get local cached profiles first
    final localProfiles = await _getCachedHosts();
    
    // Try API call
    final response = await _apiClient.get<Map<String, dynamic>>('/ssh/profiles');
    
    if (response.isSuccess && response.data != null) {
      final responseData = response.data!;
      final serverProfiles = (responseData['profiles'] as List<dynamic>? ?? [])
          .map((json) => SshProfile.fromJson(json))
          .toList();
      
      // Check for data inconsistency
      final inconsistency = await _detectDataInconsistency(localProfiles, serverProfiles);
      if (inconsistency.hasInconsistency) {
        // Handle based on user preference or prompt
        return await _resolveDataInconsistency(inconsistency, localProfiles, serverProfiles);
      }
      
      // Cache and return server data
      await _cacheHosts(serverProfiles);
      return serverProfiles;
    }
    
    // Fallback to local cache
    debugPrint('API call failed, using local cache');
    return localProfiles;
    
  } catch (e) {
    debugPrint('Error in getHosts: $e');
    return await _getCachedHosts();
  }
}
```

**B. Add `syncLocalProfilesToServer()` method:**
```dart
Future<SyncResult> syncLocalProfilesToServer() async {
  try {
    final localProfiles = await _getCachedHosts();
    final serverProfiles = await _getServerProfiles();
    
    final localOnly = _findLocalOnlyProfiles(localProfiles, serverProfiles);
    final syncResults = <String, bool>{};
    
    for (final profile in localOnly) {
      try {
        final result = await createHost(profile);
        syncResults[profile.id] = result != null;
      } catch (e) {
        debugPrint('Failed to sync profile ${profile.id}: $e');
        syncResults[profile.id] = false;
      }
    }
    
    return SyncResult(
      successful: syncResults.values.where((v) => v).length,
      failed: syncResults.values.where((v) => !v).length,
      details: syncResults,
    );
  } catch (e) {
    return SyncResult.error(e.toString());
  }
}
```

**C. Add `resolveDataInconsistency()` method:**
```dart
Future<List<SshProfile>> _resolveDataInconsistency(
  DataInconsistency inconsistency,
  List<SshProfile> localProfiles,
  List<SshProfile> serverProfiles,
) async {
  // Get user preference for sync strategy
  final syncStrategy = await _getSyncStrategy();
  
  switch (syncStrategy) {
    case SyncStrategy.uploadLocal:
      await syncLocalProfilesToServer();
      return await _getServerProfiles();
    
    case SyncStrategy.downloadRemote:
      await _cacheHosts(serverProfiles);
      return serverProfiles;
    
    case SyncStrategy.merge:
      return await _mergeProfiles(localProfiles, serverProfiles);
    
    case SyncStrategy.askUser:
    default:
      // Store conflict for UI resolution
      await _storeConflictForResolution(inconsistency, localProfiles, serverProfiles);
      return localProfiles; // Return local for now
  }
}
```

**D. Add data inconsistency detection:**
```dart
Future<DataInconsistency> _detectDataInconsistency(
  List<SshProfile> localProfiles,
  List<SshProfile> serverProfiles,
) async {
  final localCount = localProfiles.length;
  final serverCount = serverProfiles.length;
  
  if (localCount == 0 && serverCount == 0) {
    return DataInconsistency.none();
  }
  
  if (localCount > 0 && serverCount == 0) {
    return DataInconsistency.localOnly(localProfiles);
  }
  
  if (localCount == 0 && serverCount > 0) {
    return DataInconsistency.serverOnly(serverProfiles);
  }
  
  // Check for profile conflicts
  final conflicts = <ProfileConflict>[];
  for (final local in localProfiles) {
    final server = serverProfiles.firstWhereOrNull((s) => s.id == local.id);
    if (server != null && !_profilesEqual(local, server)) {
      conflicts.add(ProfileConflict(local, server));
    }
  }
  
  return DataInconsistency.conflicts(conflicts);
}
```

#### 1.2 New Data Models

**A. Sync Strategy Enum:**
```dart
enum SyncStrategy {
  uploadLocal,    // Upload local profiles to server
  downloadRemote, // Download server profiles
  merge,          // Intelligent merge
  askUser,        // Prompt user for decision
}
```

**B. Sync Result Model:**
```dart
class SyncResult {
  final bool success;
  final int successful;
  final int failed;
  final Map<String, bool> details;
  final String? error;
  
  const SyncResult({
    required this.success,
    required this.successful,
    required this.failed,
    required this.details,
    this.error,
  });
  
  factory SyncResult.error(String error) => SyncResult(
    success: false,
    successful: 0,
    failed: 0,
    details: {},
    error: error,
  );
}
```

**C. Data Inconsistency Model:**
```dart
class DataInconsistency {
  final InconsistencyType type;
  final List<SshProfile> localOnly;
  final List<SshProfile> serverOnly;
  final List<ProfileConflict> conflicts;
  
  bool get hasInconsistency => type != InconsistencyType.none;
}
```

### Phase 2: State Management Enhancement

#### 2.1 Update SSH Host Providers (`lib/providers/ssh_host_providers.dart`)

**A. Add Sync State Provider:**
```dart
enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? message;
  final SyncResult? lastResult;
  final DataInconsistency? pendingConflict;
  
  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastResult,
    this.pendingConflict,
  });
}

class SyncStateNotifier extends StateNotifier<SyncState> {
  SyncStateNotifier() : super(const SyncState());
  
  Future<void> syncToServer() async {
    state = const SyncState(status: SyncStatus.syncing);
    
    try {
      final result = await SshHostService.instance.syncLocalProfilesToServer();
      state = SyncState(
        status: SyncStatus.success,
        message: 'Synced ${result.successful} profiles',
        lastResult: result,
      );
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        message: 'Sync failed: $e',
      );
    }
  }
  
  void clearStatus() {
    state = const SyncState();
  }
}
```

**B. Enhanced SSH Hosts Notifier:**
```dart
class SshHostsNotifier extends StateNotifier<AsyncValue<List<SshProfile>>> {
  // ... existing code ...
  
  /// Enhanced refresh with conflict detection
  Future<void> refresh({bool forceSync = false}) async {
    try {
      state = const AsyncValue.loading();
      final hosts = await _hostService.getHosts(forceSync: forceSync);
      state = AsyncValue.data(hosts);
    } catch (e, stackTrace) {
      debugPrint('Error loading SSH hosts: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Manual sync trigger
  Future<SyncResult> syncToServer() async {
    return await _hostService.syncLocalProfilesToServer();
  }
  
  /// Resolve pending conflicts
  Future<void> resolveConflict(SyncStrategy strategy) async {
    // Implementation for conflict resolution
  }
}
```

### Phase 3: UI Layer Enhancement

#### 3.1 Sync Status Widget
```dart
class SyncStatusWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    
    return switch (syncState.status) {
      SyncStatus.idle => const SizedBox.shrink(),
      SyncStatus.syncing => const LinearProgressIndicator(),
      SyncStatus.success => _buildSuccessIndicator(syncState.message),
      SyncStatus.error => _buildErrorIndicator(syncState.message),
    };
  }
}
```

#### 3.2 Conflict Resolution Dialog
```dart
class ConflictResolutionDialog extends StatelessWidget {
  final DataInconsistency conflict;
  final Function(SyncStrategy) onResolve;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Conflict Detected'),
      content: _buildConflictDescription(),
      actions: [
        TextButton(
          onPressed: () => onResolve(SyncStrategy.uploadLocal),
          child: const Text('Upload Local'),
        ),
        TextButton(
          onPressed: () => onResolve(SyncStrategy.downloadRemote),
          child: const Text('Download Remote'),
        ),
        TextButton(
          onPressed: () => onResolve(SyncStrategy.merge),
          child: const Text('Smart Merge'),
        ),
      ],
    );
  }
}
```

### Phase 4: Testing Strategy

#### 4.1 Unit Tests
- Test sync logic with various scenarios
- Test conflict detection algorithms
- Test error handling and edge cases
- Test encryption/decryption of synced data

#### 4.2 Integration Tests  
- Test full sync workflow
- Test offline/online transitions
- Test UI state updates during sync
- Test API failure scenarios

#### 4.3 User Acceptance Tests
- Verify user can sync local profiles to server
- Verify conflict resolution works as expected
- Verify sync status is clearly communicated
- Verify no data loss occurs during sync

## Implementation Schedule

### Day 1: Service Layer (4 hours)
- [ ] Implement enhanced `getHosts()` method
- [ ] Add `syncLocalProfilesToServer()` method
- [ ] Add conflict detection logic
- [ ] Add data models for sync operations
- [ ] Unit tests for service layer

### Day 2: State Management & UI (3 hours)
- [ ] Update providers with sync state management
- [ ] Add sync status UI components
- [ ] Add conflict resolution dialog
- [ ] Integration tests
- [ ] UI testing and refinement

### Day 3: Testing & Documentation (2 hours)
- [ ] Comprehensive testing
- [ ] Bug fixes and edge case handling
- [ ] Documentation updates
- [ ] Code review and optimization

## Risk Mitigation

### Data Loss Prevention
- Always backup local data before sync operations
- Use transactions for atomic operations
- Implement rollback mechanisms for failed syncs
- Never delete local data automatically

### Performance Considerations
- Implement sync debouncing to avoid excessive API calls
- Use incremental sync for large profile collections
- Cache sync results to improve responsiveness
- Optimize encryption/decryption operations

### Error Handling
- Graceful degradation when API is unavailable
- Clear error messages for users
- Retry mechanisms with exponential backoff
- Logging for debugging sync issues

## Success Criteria

### Functional Requirements
- [x] Local profiles sync successfully to server
- [x] Conflicts are detected and resolved appropriately
- [x] Users maintain control over sync decisions
- [x] Sync status is clearly communicated
- [x] No data loss occurs during sync operations
- [x] Offline/online transitions work smoothly

### Technical Requirements
- [x] Code follows Flutter/Dart best practices
- [x] Comprehensive test coverage (>80%)
- [x] Proper error handling and logging
- [x] Performance meets requirements (<2s sync time)
- [x] Security standards maintained

### User Experience Requirements  
- [x] Intuitive sync conflict resolution
- [x] Clear visual feedback during sync
- [x] Non-blocking UI during sync operations
- [x] Consistent behavior across app sessions

## Next Steps After Implementation

1. **Monitor Sync Performance**: Track sync success rates and performance metrics
2. **User Feedback Collection**: Gather feedback on conflict resolution UX
3. **Advanced Sync Features**: Consider implementing automatic sync scheduling
4. **Cross-device Optimization**: Optimize for multi-device usage patterns

---

**Acceptance Criteria Checklist:**
- [ ] Local profiles are synced to server when API is available
- [ ] User sees consistent data between local and remote
- [ ] Proper error handling for sync failures
- [ ] Clear user feedback on sync status
- [ ] No data loss during sync process
- [ ] Handles offline/online transitions gracefully
- [ ] Conservative sync approach with user control
- [ ] Transparent sync status communication