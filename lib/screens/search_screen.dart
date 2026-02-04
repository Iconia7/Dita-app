import 'package:flutter/material.dart';
import '../data/models/event_model.dart';
import '../data/models/resource_model.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state_widget.dart';

class DitaSearchDelegate extends SearchDelegate {
  final Future<List<EventModel>> eventsFuture;
  final Future<List<ResourceModel>> resourcesFuture;

  DitaSearchDelegate(this.eventsFuture, this.resourcesFuture);

  @override
  ThemeData appBarTheme(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg, // 🟢 Match the rest of the app background
        foregroundColor: textColor,  // 🟢 Dynamic Text/Icon color
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[400]),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: textColor, // 🟢 Input text color
          fontSize: 18,
          fontWeight: FontWeight.normal, // Standard search input weight
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear), 
      onPressed: () => query = ''
    )
  ];

  @override
  Widget? buildLeading(BuildContext context) => 
    IconButton(
      icon: const Icon(Icons.arrow_back), 
      onPressed: () => close(context, null)
    );

  @override
  Widget buildResults(BuildContext context) => _buildAsyncList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildAsyncList(context);

  Widget _buildAsyncList(BuildContext context) {
    // 🟢 Theme Helpers
    final primaryColor = Theme.of(context).primaryColor;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    return FutureBuilder<List<List<dynamic>>>(
      future: Future.wait([eventsFuture, resourcesFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList(
            padding: EdgeInsets.all(20),
            skeleton: CardSkeleton(hasImage: false),
            itemCount: 5,
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text("Could not load search data.", style: TextStyle(color: subTextColor)));
        }

        final List<EventModel> events = snapshot.data![0] as List<EventModel>;
        final List<ResourceModel> resources = snapshot.data![1] as List<ResourceModel>;

        return _filterAndDisplayData(context, events, resources);
      },
    );
  }

  Widget _filterAndDisplayData(BuildContext context, List<EventModel> events, List<ResourceModel> resources) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;
    final cardColor = Theme.of(context).cardColor;

    final eventResults = events.where((e) => e.title.toLowerCase().contains(query.toLowerCase())).toList();
    final resourceResults = resources.where((r) => r.title.toLowerCase().contains(query.toLowerCase())).toList();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 60, color: isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 10),
            Text("Search events or resources...", style: TextStyle(color: subTextColor)),
          ],
        ),
      );
    }

    if (eventResults.isEmpty && resourceResults.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyStateWidget(
          svgPath: 'assets/svgs/no_search.svg',
          title: "No Results Found",
          message: "We couldn't find anything matching that query. Try a different keyword.",
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // 🟢 Ensure background matches theme
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          if (eventResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10), 
              child: Text("EVENTS", style: TextStyle(fontWeight: FontWeight.bold, color: subTextColor, fontSize: 12))
            ),
            ...eventResults.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardColor, // 🟢 Dynamic Item BG
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.calendar_month, color: primaryColor, size: 20)
                ),
                title: Text(e.title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), // 🟢
                subtitle: Text(e.location ?? "No Venue", style: TextStyle(color: subTextColor)),
                onTap: () {
                  close(context, {'tabIndex': 1, 'id': e.id}); 
                },
              ),
            )),
          ],

          if (resourceResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10), 
              child: Text("RESOURCES", style: TextStyle(fontWeight: FontWeight.bold, color: subTextColor, fontSize: 12))
            ),
            ...resourceResults.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardColor, // 🟢
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (r.category.toUpperCase() == 'PDF' ? Colors.red : Colors.blue).withOpacity(0.1),
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    r.category.toUpperCase() == 'PDF' ? Icons.picture_as_pdf : Icons.link, 
                    color: r.category.toUpperCase() == 'PDF' ? Colors.red : Colors.blue, 
                    size: 20
                  )
                ),
                title: Text(r.title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), // 🟢
                subtitle: Text(r.description ?? "", style: TextStyle(color: subTextColor)),
                onTap: () async {
                  close(context, {'tabIndex': 2, 'id': r.id}); 
                },
              ),
            )),
          ]
        ],
      ),
    );
  }
}