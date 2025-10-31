import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/series.dart';
import '../services/database_service.dart';
import '../services/series_parser.dart';
import 'series_detail_screen.dart';

class SeriesGridScreen extends StatefulWidget {
  const SeriesGridScreen({Key? key}) : super(key: key);

  @override
  State<SeriesGridScreen> createState() => _SeriesGridScreenState();
}

class _SeriesGridScreenState extends State<SeriesGridScreen> {
  Map<String, Series> _allSeries = {};
  List<Series> _filteredSeries = [];
  Map<String, int> _categories = {}; // category -> count
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'added';

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final allChannels = await DatabaseService.getAllChannels();
    final seriesChannels = allChannels
        .where((c) => c.contentType == ContentType.series)
        .toList();

    final seriesMap = SeriesParser.groupIntoSeries(seriesChannels);

    // Extract unique categories (groups) from channels
    final categoryCount = <String, int>{};
    for (var channel in seriesChannels) {
      final category = channel.group ?? 'Uncategorized';
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    setState(() {
      _allSeries = seriesMap;
      _filteredSeries = seriesMap.values.toList();
      _categories = categoryCount;
    });
  }

  void _filterSeries() {
    // Filter by category first from the map keys
    Map<String, Series> filteredMap = {};

    if (_selectedCategory != null) {
      // Filter series that belong to selected category
      // Keys are in format: "category_seriesName"
      _allSeries.forEach((key, series) {
        if (key.startsWith('${_selectedCategory}_')) {
          filteredMap[key] = series;
        }
      });
    } else {
      filteredMap = Map.from(_allSeries);
    }

    List<Series> filtered = filteredMap.values.toList();

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'rating':
        filtered.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case 'added':
      default:
        // Keep original order
        break;
    }

    setState(() {
      _filteredSeries = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1E2B),
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 380,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2B3C),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Logo and Back button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'IPTV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Series',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search box
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: const Color(0xFF0F1E2B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _filterSeries();
                    },
                  ),
                ),

                // Categories list
                Expanded(
                  child: ListView(
                    children: [
                      // All category
                      Material(
                        color: _selectedCategory == null
                            ? const Color(0xFF2D4A5E)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                            _filterSeries();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'All',
                                  style: TextStyle(
                                    color: _selectedCategory == null
                                        ? const Color(0xFF5DD3E5)
                                        : Colors.white,
                                    fontSize: 14,
                                    fontWeight: _selectedCategory == null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  _allSeries.length.toString(),
                                  style: TextStyle(
                                    color: _selectedCategory == null
                                        ? const Color(0xFF5DD3E5)
                                        : Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Category items
                      ..._categories.entries.map((entry) {
                        final category = entry.key;
                        final count = entry.value;
                        final isSelected = _selectedCategory == category;

                        return Material(
                          color: isSelected
                              ? const Color(0xFF2D4A5E)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _filterSeries();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      category.toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF5DD3E5)
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF5DD3E5)
                                          : Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right side - Series Grid
          Expanded(
            child: Column(
              children: [
                // Top bar with search and filters
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2B3C),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Search bar
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D4A5E),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                              _filterSeries();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Sort dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4A5E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _sortBy,
                          dropdownColor: const Color(0xFF2D4A5E),
                          underline: Container(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: 'added',
                              child: Text('Ordenar por agregado'),
                            ),
                            DropdownMenuItem(
                              value: 'name',
                              child: Text('Ordenar por nombre'),
                            ),
                            DropdownMenuItem(
                              value: 'rating',
                              child: Text('Ordenar por calificación'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _sortBy = value!;
                            });
                            _filterSeries();
                          },
                        ),
                      ),

                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.grid_view, color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline,
                            color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.view_module, color: Color(0xFF5DD3E5)),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Series Grid
                Expanded(
                  child: _filteredSeries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontraron series',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredSeries.length,
                          itemBuilder: (context, index) {
                            final series = _filteredSeries[index];
                            return _buildSeriesCard(series);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(Series series) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeriesDetailScreen(series: series),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1A2B3C),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster image
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: const Color(0xFF2D4A5E),
                      ),
                      child: series.poster != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.network(
                                series.poster!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.movie,
                                      size: 48,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.movie,
                                size: 48,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                    ),

                    // Rating badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (series.rating ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  series.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
