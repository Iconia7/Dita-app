import 'package:flutter/material.dart';

class DitaSearchDelegate extends SearchDelegate {
  // We accept Futures (Promises) instead of completed Lists
  final Future<List<dynamic>> eventsFuture;
  final Future<List<dynamic>> resourcesFuture;

  DitaSearchDelegate(this.eventsFuture, this.resourcesFuture);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF003366), 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white54),
      ),
      textTheme: const TextTheme(titleLarge: TextStyle(color: Colors.white, fontSize: 18)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
  ];

  @override
  Widget? buildLeading(BuildContext context) => 
    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildAsyncList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildAsyncList(context);

  // --- NEW: Handle the Async Data Loading ---
  Widget _buildAsyncList(BuildContext context) {
    return FutureBuilder<List<List<dynamic>>>(
      // Wait for BOTH APIs to finish
      future: Future.wait([eventsFuture, resourcesFuture]),
      builder: (context, snapshot) {
        
        // 1. Show Spinner while loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF003366)),
                const SizedBox(height: 15),
                Text("Searching database...", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        // 2. Handle Errors
        if (snapshot.hasError) {
          return const Center(child: Text("Could not load search data."));
        }

        // 3. Data is Ready! Filter it now.
        final List<dynamic> events = snapshot.data![0];
        final List<dynamic> resources = snapshot.data![1];

        return _filterAndDisplayData(context, events, resources);
      },
    );
  }

  Widget _filterAndDisplayData(BuildContext context, List<dynamic> events, List<dynamic> resources) {
    final eventResults = events.where((e) => e['title'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    final resourceResults = resources.where((r) => r['title'].toString().toLowerCase().contains(query.toLowerCase())).toList();

    if (query.isEmpty) return const Center(child: Text("Search events or resources...", style: TextStyle(color: Colors.grey)));
    if (eventResults.isEmpty && resourceResults.isEmpty) return const Center(child: Text("No results found.", style: TextStyle(color: Colors.grey)));

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        if (eventResults.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("EVENTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          ...eventResults.map((e) => ListTile(
    leading: const Icon(Icons.calendar_month, color: Color(0xFF003366)),
    title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(e['venue'] ?? "No Venue"),
    onTap: () {
        // 🛑 CRITICAL CHANGE: Close search and pass the target index 1 (Events Tab)
        close(context, {'tabIndex': 1, 'id': e['id']}); 
    },
)),
],
        if (resourceResults.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("RESOURCES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          ...resourceResults.map((r) => ListTile(
        leading: Icon(r['resource_type'] == 'PDF' ? Icons.picture_as_pdf : Icons.link, color: r['resource_type'] == 'PDF' ? Colors.red : Colors.blue),
        title: Text(r['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(r['description'] ?? ""),
        onTap: () async {
            // 🛑 CRITICAL CHANGE: Close search and pass the target index 2 (Resources Tab)
            close(context, {'tabIndex': 2, 'id': r['id']}); 
        },
    )),
],
      ],
    );
  }
}