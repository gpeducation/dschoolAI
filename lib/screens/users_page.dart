import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../helpers/db_helper.dart'; // Import the DBHelper

class UsersPage extends StatefulWidget {
  final String type;
  final String schoolId;

  const UsersPage({super.key, required this.type, required this.schoolId});

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _idController = TextEditingController();
  Map<String, dynamic>? _studentData;
  bool _isLoading = false;

  Future<void> _fetchStudentData(String id) async {
    String url = "";
    setState(() {
      _isLoading = true;
    });
    if (widget.type == 's' || widget.type == 'p') {
      url =
          'http://www.thaidigitalschool.com/school_service2/get_catstudent3.php?servername=${widget.schoolId}&sdno=$id';
    } else {
      url =
          'http://thaidigitalschool.com/ios/findteacherData2.php?servername=${widget.schoolId}&sdno=$id';
    }
    print(url);
    final response = await http.get(
      Uri.parse(url),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['ok']) {
        setState(() {
          _studentData = data['school'][0];
        });
      } else {
        // Handle case where 'ok' is false
        setState(() {
          _studentData = null;
        });
      }
    } else {
      // Handle error response
      setState(() {
        _studentData = null;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _navigateToRegisterPage() async {
    if (_studentData != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentApp', widget.type);
      String? apptype = widget.type;
      switch (apptype) {
        case 'm':
          await prefs.setString('currentApp', 'm');
          await prefs.setString('mschool_code', widget.schoolId);
          await prefs.setString('muserid', _studentData!['sdno']);
          break;
        case 't':
          await prefs.setString('currentApp', 't');
          await prefs.setString('tschool_code', widget.schoolId);
          await prefs.setString('tuserid', _studentData!['sdno']);
          break;
        case 's':
          await prefs.setString('currentApp', 's');
          await prefs.setString('sschool_code', widget.schoolId);
          await prefs.setString('suserid', _studentData!['sdno']);
          break;
        case 'p':
          await prefs.setString('currentApp', 'p');
          await prefs.setString('pschool_code', widget.schoolId);
          await prefs.setString('puserid', _studentData!['sdno']);
          // Save to SQLite
          await DBHelper().insertStudent({
            'school_code': widget.schoolId,
            'user_id': _studentData!['sdno'],
            'sd_name':
                '${_studentData!['sdname']} ${_studentData!['sdsurname']}',
          });
          break;
        default:
          break;
      }

      String? mobileid = prefs.getString('token');
      String cname =
          '${_studentData!['sdname']} ${_studentData!['sdsurname']}' ?? '';
      String url =
          "http://www.thaidigitalschool.com/gcm_server_php2/newregister4.php?name=$cname&email=&regId=$mobileid&password=&sdno=${_studentData!['sdno']}&schoolid=${widget.schoolId}&app=${widget.type}&mobile_id=$mobileid";

      print(url);

      final response = await http.get(
        Uri.parse(url),
      );

      if (response.statusCode == 200) {
        Navigator.pushNamed(context, '/home_page');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาข้อมูลนักเรียน'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'รหัสบัตรประชาชน',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () => _fetchStudentData(_idController.text),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('ค้นหา'),
            ),
            const SizedBox(height: 16.0),
            if (_studentData != null) ...[
              Text(
                'รหัส: ${_studentData!['sdno']}',
                style: const TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              Text(
                'ชื่อ: ${_studentData!['sdname']} ${_studentData!['sdsurname']}',
                style: const TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _navigateToRegisterPage,
                child: const Text('ลงทะเบียน'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
