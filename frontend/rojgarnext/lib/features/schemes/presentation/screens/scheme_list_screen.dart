// lib/features/schemes/presentation/screens/scheme_list_screen.dart
// ✅ COMPLETE FIXED - Shows all schemes from local master data
// ✅ Works even if backend is unavailable

import 'package:flutter/material.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/master_date/schemes_data.dart';
import 'package:rojgarnext/features/schemes/data/scheme_service.dart';
import 'package:rojgarnext/features/schemes/presentation/screens/scheme_detail_screen.dart';

class SchemeListScreen extends StatefulWidget {
  final bool isEmbedded;
  final Function(Map<String, dynamic>)? onSchemeSelected;
  final VoidCallback? onBack;

  const SchemeListScreen({
    super.key,
    this.isEmbedded = false,
    this.onSchemeSelected,
    this.onBack,
  });

  @override
  State<SchemeListScreen> createState() => _SchemeListScreenState();
}

class _SchemeListScreenState extends State<SchemeListScreen> {
  List<dynamic> _schemes = [];
  List<dynamic> _filteredSchemes = [];
  List<String> _states = [];
  List<dynamic> _categories = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedLevel = 'all';
  String? _selectedState;
  String? _selectedCategory;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Load schemes, states, and categories
      final schemesResult = await SchemeService.listSchemes(limit: 200);
      
      if (!mounted) return;

      setState(() {
        _schemes = (schemesResult['schemes'] as List?) ?? [];
        _filteredSchemes = List.from(_schemes);
        
        // Get states and categories from the schemes
        final stateSet = <String>{};
        final categorySet = <String>{};
        
        for (final scheme in _schemes) {
          final state = scheme['state']?.toString();
          if (state != null && state.isNotEmpty) {
            stateSet.add(state);
          }
          final category = scheme['category']?.toString();
          if (category != null && category.isNotEmpty) {
            categorySet.add(category);
          }
        }
        
        _states = stateSet.toList()..sort();
        _categories = categorySet.map((c) => {
          'id': c,
          'name': _getCategoryName(c),
          'name_hindi': _getCategoryNameHindi(c),
        }).toList();
        
        _isLoading = false;
      });

      debugPrint("✅ Loaded ${_schemes.length} schemes");
      debugPrint("   States: ${_states.length}");
      debugPrint("   Categories: ${_categories.length}");
    } catch (e) {
      if (!mounted) return;
      
      // ✅ Even on error, try to load from local master data directly
      final localSchemes = SchemesMasterData.allSchemes.map((s) => {
        'scheme_id': s.schemeId,
        'scheme_name': s.schemeName,
        'scheme_name_hindi': s.schemeNameHindi,
        'short_description': s.shortDescription,
        'short_description_hindi': s.shortDescriptionHindi,
        'level': s.level,
        'state': s.state,
        'category': s.category,
        'icon': s.icon,
        'color': s.color,
        'is_featured': s.isFeatured,
      }).toList();

      setState(() {
        _schemes = localSchemes;
        _filteredSchemes = localSchemes;
        _isLoading = false;
        _errorMessage = null;
      });
      
      debugPrint("⚠️ Fallback: Loaded ${localSchemes.length} schemes from local data");
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'agriculture': return 'Agriculture';
      case 'education': return 'Education';
      case 'health': return 'Health';
      case 'housing': return 'Housing';
      case 'employment': return 'Employment';
      case 'women_child': return 'Women & Child';
      case 'social_welfare': return 'Social Welfare';
      case 'financial_inclusion': return 'Financial Inclusion';
      case 'pension': return 'Pension';
      case 'insurance': return 'Insurance';
      case 'skill_development': return 'Skill Development';
      case 'entrepreneurship': return 'Entrepreneurship';
      case 'disability': return 'Disability';
      case 'sc_st_welfare': return 'SC/ST Welfare';
      case 'minority_welfare': return 'Minority Welfare';
      default: return category;
    }
  }

  String _getCategoryNameHindi(String category) {
    switch (category) {
      case 'agriculture': return 'कृषि';
      case 'education': return 'शिक्षा';
      case 'health': return 'स्वास्थ्य';
      case 'housing': return 'आवास';
      case 'employment': return 'रोजगार';
      case 'women_child': return 'महिला एवं बाल';
      case 'social_welfare': return 'समाज कल्याण';
      case 'financial_inclusion': return 'वित्तीय समावेशन';
      case 'pension': return 'पेंशन';
      case 'insurance': return 'बीमा';
      case 'skill_development': return 'कौशल विकास';
      case 'entrepreneurship': return 'उद्यमिता';
      case 'disability': return 'विकलांगता';
      case 'sc_st_welfare': return 'अनुसूचित जाति/जनजाति कल्याण';
      case 'minority_welfare': return 'अल्पसंख्यक कल्याण';
      default: return category;
    }
  }

  void _applyFilters() {
    List<dynamic> result = List.from(_schemes);

    if (_selectedLevel != 'all') {
      result = result.where((s) => s['level'] == _selectedLevel).toList();
    }

    if (_selectedState != null && _selectedState!.isNotEmpty) {
      result = result.where((s) =>
        s['state']?.toString().toLowerCase() ==
        _selectedState!.toLowerCase()).toList();
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      result = result.where((s) => s['category'] == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        final name = (s['scheme_name'] ?? '').toString().toLowerCase();
        final nameHindi = (s['scheme_name_hindi'] ?? '').toString();
        final shortDesc = (s['short_description'] ?? '').toString().toLowerCase();
        final shortDescHindi = (s['short_description_hindi'] ?? '').toString();
        return name.contains(q) ||
            nameHindi.contains(_searchQuery) ||
            shortDesc.contains(q) ||
            shortDescHindi.contains(_searchQuery);
      }).toList();
    }

    setState(() {
      _filteredSchemes = result;
    });
  }

  void _onLevelChanged(String level) {
    setState(() {
      _selectedLevel = level;
      if (level != 'state') {
        _selectedState = null;
      }
    });
    _applyFilters();
  }

  void _onStateChanged(String? state) {
    setState(() => _selectedState = state);
    _applyFilters();
  }

  void _onCategoryChanged(String? category) {
    setState(() => _selectedCategory = category);
    _applyFilters();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      _selectedLevel = 'all';
      _selectedState = null;
      _selectedCategory = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  void _openSchemeDetail(Map<String, dynamic> scheme) {
    final schemeId = scheme['scheme_id']?.toString() ?? '';
    final schemeName = scheme['scheme_name_hindi']?.toString() ??
        scheme['scheme_name']?.toString() ?? 'योजना';

    if (widget.onSchemeSelected != null) {
      widget.onSchemeSelected!({
        'scheme_id': schemeId,
        'scheme_name': schemeName,
        'scheme': scheme,
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchemeDetailScreen(
          schemeId: schemeId,
          schemeName: schemeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildLevelTabs(),
        if (_selectedLevel == 'state') _buildStateFilter(),
        _buildCategoryFilter(),
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _filteredSchemes.isEmpty
                  ? _buildEmptyState()
                  : _buildSchemeList(),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
          ),
        ),
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
          ),
        ),
        child: SafeArea(child: content),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.isEmbedded && widget.onBack != null)
            Material(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onBack,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
            ),
          if (widget.isEmbedded && widget.onBack != null)
            const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'सरकारी योजनाएं',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Government Schemes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_filteredSchemes.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'योजना खोजें... / Search schemes...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          icon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLevelTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildLevelChip('all', 'सभी', Icons.apps),
          _buildLevelChip('central', 'केंद्रीय', Icons.account_balance),
          _buildLevelChip('state', 'राज्य', Icons.location_city),
        ],
      ),
    );
  }

  Widget _buildLevelChip(String value, String label, IconData icon) {
    final isSelected = _selectedLevel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onLevelChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState,
          isExpanded: true,
          hint: Text(
            'राज्य चुनें / Select State',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6C63FF)),
          style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
          items: _states.map((state) {
            return DropdownMenuItem<String>(
              value: state,
              child: Text(state, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: _onStateChanged,
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip(null, 'सभी', Icons.grid_view),
          ..._categories.map((cat) {
            final id = cat['id']?.toString();
            final nameHindi = cat['name_hindi']?.toString() ?? '';
            return _buildCategoryChip(
              id,
              nameHindi,
              _getCategoryIcon(id ?? ''),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label, IconData icon) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _onCategoryChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6C63FF)
                  : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'agriculture': return Icons.agriculture;
      case 'education': return Icons.school;
      case 'health': return Icons.local_hospital;
      case 'housing': return Icons.home;
      case 'employment': return Icons.work;
      case 'women_child': return Icons.pregnant_woman;
      case 'social_welfare': return Icons.people;
      case 'financial_inclusion': return Icons.account_balance_wallet;
      case 'pension': return Icons.elderly;
      case 'insurance': return Icons.security;
      case 'skill_development': return Icons.construction;
      case 'entrepreneurship': return Icons.rocket_launch;
      case 'disability': return Icons.accessible;
      case 'sc_st_welfare': return Icons.groups;
      case 'minority_welfare': return Icons.mosque;
      default: return Icons.category;
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
          SizedBox(height: 16),
          Text(
            'योजनाएं लोड हो रही हैं...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.1),
                    const Color(0xFFFF6588).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 60,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'कोई योजना नहीं मिली',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No schemes found. Try changing the filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('फ़िल्टर हटाएं / Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchemeList() {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: _filteredSchemes.length,
        itemBuilder: (context, index) {
          return _buildSchemeCard(_filteredSchemes[index], index);
        },
      ),
    );
  }

  Widget _buildSchemeCard(Map<String, dynamic> scheme, int index) {
    final schemeNameHindi = scheme['scheme_name_hindi']?.toString() ??
        scheme['scheme_name']?.toString() ?? 'योजना';
    final schemeName = scheme['scheme_name']?.toString() ?? 'Scheme';
    final shortDescHindi = scheme['short_description_hindi']?.toString() ??
        scheme['short_description']?.toString() ?? '';
    final level = scheme['level']?.toString() ?? 'central';
    final state = scheme['state']?.toString();
    final icon = scheme['icon']?.toString() ?? '📋';
    final isFeatured = scheme['is_featured'] == true;
    final colorKey = scheme['color']?.toString() ?? 'blue';

    final levelLabel = level == 'central'
        ? 'केंद्रीय योजना'
        : 'राज्य योजना${state != null ? " • $state" : ""}';

    final accentColor = _getAccentColor(colorKey);

    return GestureDetector(
      onTap: () => _openSchemeDetail(scheme),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.15),
                          accentColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                schemeNameHindi,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFeatured)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 10,
                                      color: Colors.amber,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Featured',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          schemeName,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            levelLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (shortDescHindi.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    shortDescHindi,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        accentColor.withOpacity(0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _openSchemeDetail(scheme),
                    icon: const Icon(Icons.visibility, size: 17),
                    label: const Text(
                      'विवरण देखें / View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAccentColor(String colorKey) {
    switch (colorKey) {
      case 'green': return const Color(0xFF10B981);
      case 'red': return const Color(0xFFEF4444);
      case 'orange': return const Color(0xFFF59E0B);
      case 'purple': return const Color(0xFF8B5CF6);
      case 'teal': return const Color(0xFF14B8A6);
      case 'pink': return const Color(0xFFEC4899);
      case 'indigo': return const Color(0xFF4F46E5);
      case 'amber': return const Color(0xFFD97706);
      case 'cyan': return const Color(0xFF06B6D4);
      case 'grey': return const Color(0xFF6B7280);
      case 'blue':
      default: return const Color(0xFF2563EB);
    }
  }
}