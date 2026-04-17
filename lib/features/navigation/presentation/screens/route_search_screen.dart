import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/recent_destinations_repository.dart';
import 'package:drivelink/features/navigation/data/datasources/local_geocoding_source.dart';

/// Address search screen — the user types a destination, picks from results,
/// and pops back with the selected [LatLng].
class RouteSearchScreen extends ConsumerStatefulWidget {
  const RouteSearchScreen({super.key});

  @override
  ConsumerState<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends ConsumerState<RouteSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<GeocodingResult> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  // Recent destinations loaded from the Drift database.
  List<GeocodingResult> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentDestinations();
    // Auto-focus the text field so keyboard appears immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadRecentDestinations() async {
    final repo = ref.read(recentDestinationsRepositoryProvider);
    final destinations = await repo.getRecent(limit: 10);
    if (!mounted) return;
    setState(() {
      _recentSearches = destinations
          .map<GeocodingResult>((d) => (
                displayName: d.name,
                coordinate: LatLng(d.latitude, d.longitude),
              ))
          .toList();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final geocoder = ref.read(localGeocodingSourceProvider);
    final results = await geocoder.search(query);

    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  void _selectResult(GeocodingResult result) {
    // Persist to the Drift database.
    final repo = ref.read(recentDestinationsRepositoryProvider);
    repo.addDestination(
      result.displayName,
      result.coordinate.latitude,
      result.coordinate.longitude,
    );

    // Update the in-memory list for immediate UI feedback.
    _recentSearches.removeWhere(
        (r) => r.coordinate == result.coordinate);
    _recentSearches.insert(0, result);
    if (_recentSearches.length > 10) _recentSearches.removeLast();

    Navigator.of(context).pop(result.coordinate);
  }

  @override
  Widget build(BuildContext context) {
    final showRecents = _controller.text.trim().length < 3 && _results.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hedef Ara'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          // ── Search field ────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Adres veya yer adi yazin...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ── Loading indicator ──────────────────────────────────────────
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
              minHeight: 2,
            ),

          // ── Results / recents ──────────────────────────────────────────
          Expanded(
            child: showRecents
                ? _buildRecentSearches()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          _controller.text.trim().length >= 3
              ? 'Sonuc bulunamadi'
              : 'En az 3 karakter yazin',
          style: TextStyle(color: AppColors.textDisabled),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _ResultTile(
          result: result,
          icon: Icons.location_on_outlined,
          onTap: () => _selectResult(result),
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Text(
          'Gecmis arama yok',
          style: TextStyle(color: AppColors.textDisabled),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Son aramalar',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _recentSearches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = _recentSearches[index];
              return _ResultTile(
                result: result,
                icon: Icons.history,
                onTap: () => _selectResult(result),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.result,
    required this.icon,
    required this.onTap,
  });

  final GeocodingResult result;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        result.displayName,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${result.coordinate.latitude.toStringAsFixed(4)}, '
        '${result.coordinate.longitude.toStringAsFixed(4)}',
        style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
