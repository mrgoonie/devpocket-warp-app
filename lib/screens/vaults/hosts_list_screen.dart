import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../providers/ssh_host_providers.dart';
import 'components/host_card.dart';
import 'components/host_search_field.dart';
import 'components/host_stats_header.dart';
import 'components/host_state_widgets.dart';
import 'utils/host_utils.dart';

class HostsListScreen extends ConsumerStatefulWidget {
  const HostsListScreen({super.key});

  @override
  ConsumerState<HostsListScreen> createState() => _HostsListScreenState();
}

class _HostsListScreenState extends ConsumerState<HostsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(hostSearchProvider.notifier).state = _searchController.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: _isSearching ? HostSearchField(controller: _searchController) : const Text('SSH Hosts'),
        centerTitle: !_isSearching,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshHosts,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddHostScreen,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: !_isSearching ? FloatingActionButton(
        onPressed: _showAddHostScreen,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildBody() {
    return Consumer(
      builder: (context, ref, child) {
        final hostsAsync = ref.watch(filteredHostsProvider);
        
        return hostsAsync.when(
          data: (hosts) {
            if (hosts.isEmpty) {
              return _isSearching 
                  ? const HostNoSearchResults()
                  : HostEmptyState(onAddHost: _showAddHostScreen);
            }
            
            return _buildHostsList(hosts);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          error: (error, stackTrace) => HostErrorState(
            title: 'Failed to load hosts',
            error: error.toString(),
            onRetry: _refreshHosts,
          ),
        );
      },
    );
  }

  Widget _buildHostsList(List<SshProfile> hosts) {
    return Column(
      children: [
        HostStatsHeader(hosts: hosts),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshHosts,
            color: AppTheme.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: hosts.length,
              itemBuilder: (context, index) {
                final host = hosts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HostCard(
                    host: host,
                    onMenuAction: _handleMenuAction,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action, SshProfile host) {
    HostUtils.handleMenuAction(action, host, ref, context, _refreshHosts);
  }

  void _showAddHostScreen() {
    HostUtils.showAddHostScreen(context, _refreshHosts);
  }

  Future<void> _refreshHosts() async {
    await HostUtils.refreshHosts(ref);
  }
}