import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DitaSearchDelegate extends SearchDelegate {
  final List<dynamic> events;
  final List<dynamic> resources;

  DitaSearchDelegate(this.events, this.resources);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF003366), // Primary Dark
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
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context); // <--- PASS CONTEXT HERE

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context); // <--- PASS CONTEXT HERE

  // Updated method signature to accept context
  Widget _buildList(BuildContext context) {
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
               // Now 'context' is defined!
               close(context, null); 
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
               close(context, null); // Now 'context' is defined!
               if (r['link'] != null) await launchUrl(Uri.parse(r['link']));
            },
          )),
        ]
      ],
    );
  }
}