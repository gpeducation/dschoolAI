import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dschool_ai/screens/users_page.dart';

class SchoolsPage extends StatefulWidget {
  final String type; // Declare the type variable

  const SchoolsPage({super.key, required this.type}); // Update the constructor

  @override
  _SchoolsPageState createState() => _SchoolsPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
  List<Map<String, dynamic>> schools = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print(
        'Type in initState: ${widget.type}'); // Print the type parameter in initState
  }

  Future<void> searchSchools(String query) async {
    final response = await http.get(
      Uri.parse(
          'http://www.thaidigitalschool.com/ios/findSchoolData2.php?school_name=$query'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['ok'] == true) {
        setState(() {
          schools = List<Map<String, dynamic>>.from(data['school']);
        });
      }
    } else {
      throw Exception('Failed to load schools');
    }
  }

  void _selectSchool(Map<String, dynamic> school) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UsersPage(type: widget.type, schoolId: school['schoolid']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Type in build: ${widget.type}'); // Print the type parameter in build

    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาโรงเรียน'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ค้นหาโรงเรียน',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    searchSchools(_searchController.text);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: schools.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(schools[index]['schoolname']),
                  onTap: () => _selectSchool(schools[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
