import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dschool_ai/screens/schools_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dschool_ai/helpers/db_helper.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final String token;

  static const List<String> downloadPatterns = [
    'download_url0=',
    'download_url1=',
    'download_url2=',
    'download_url3=',
    'download_url4='
  ];

  const HomePage({super.key, required this.token});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late WebViewController controller;
  String? currentApp;
  String? latitude;
  String? longitude;
  String? gcm;
  bool isControllerInitialized = false;
  List<Map<String, dynamic>> _students = [];
  bool isScanning = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  Barcode? result;

  @override
  void initState() {
    super.initState();
    _checkCurrentApp();
    _getCurrentLocation();
    _loadStudents();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (qrController != null) {
      qrController!.pauseCamera();
      qrController!.resumeCamera();
    }
  }

  String? extractDownloadUrl(String url) {
    for (String pattern in HomePage.downloadPatterns) {
      if (url.contains(pattern)) {
        final parts = url.split(pattern);
        if (parts.length > 1) {
          return parts[1];
        }
      }
    }
    return null;
  }

  Future<void> _checkCurrentApp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentApp = prefs.getString('currentApp');
      gcm = prefs.getString('token');
    });

    if (gcm == null || gcm!.isEmpty) {
      print('Error: Token is empty');
      return;
    }

    if (currentApp == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRegistrationPopup();
      });
    } else {
      _initializeWebViewIfReady();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      latitude = position.latitude.toString();
      longitude = position.longitude.toString();
    });

    _initializeWebViewIfReady();
  }

  void _initializeWebViewIfReady() {
    if (currentApp != null &&
        latitude != null &&
        longitude != null &&
        gcm != null &&
        gcm!.isNotEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        String schoolCode = "";
        String userId = "";

        String cApp = currentApp!;
        switch (cApp) {
          case 'm':
            schoolCode = prefs.getString('mschool_code') ?? '';
            userId = prefs.getString('muserid') ?? '';
            break;
          case 't':
            schoolCode = prefs.getString('tschool_code') ?? '';
            userId = prefs.getString('tuserid') ?? '';
            break;
          case 's':
            schoolCode = prefs.getString('sschool_code') ?? '';
            userId = prefs.getString('suserid') ?? '';
            break;
          case 'p':
            schoolCode = prefs.getString('pschool_code') ?? '';
            userId = prefs.getString('puserid') ?? '';
            break;
          default:
            break;
        }

        _initializeWebView(schoolCode, userId, latitude, longitude);
      });
    }
  }

  void _initializeWebView(
      String? schoolCode, String? userId, String? latitude, String? longitude) {
    if (gcm == null || gcm!.isEmpty) {
      print('Error: Token is empty');
      return;
    }

    final url = Uri.parse(
        'http://www.thaidigitalschool.com/ios/dschool_re.php?mobile_id=&token=$gcm&gcm_regid=$gcm&user_id=$userId&app=$currentApp&school_id=$schoolCode&change_stat=1&type=a&latitude=${latitude ?? ''}&longitude=${longitude ?? ''}');

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(true)
      ..setUserAgent(
          "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1")
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('Loading progress: $progress%');
          },
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            if (mounted) {
              setState(() {
                isControllerInitialized = true;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final downloadUrl = extractDownloadUrl(request.url);

            if (downloadUrl != null) {
              final formattedUrl = downloadUrl.startsWith('http')
                  ? downloadUrl
                  : 'http://$downloadUrl';

              launchUrl(
                Uri.parse(formattedUrl),
                mode: LaunchMode.externalApplication,
              );
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(url);
  }

  void _showRegistrationPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('กรุณาลงทะเบียน'),
          content: const Text('โปรดเลือกประเภทผู้ใช้งานจากเมนู'),
          actions: <Widget>[
            TextButton(
              child: const Text('ตกลง'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _onQRCodePressed() {
    setState(() {
      isScanning = !isScanning;
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    qrController = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
        isScanning = false;
      });
      // Handle the scanned data here
      print('QR Code Result: ${result!.code}');
      sendQrData(result!.code!);
    });
  }

  Future<void> sendQrData(String qrtxt) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentApp = prefs.getString('currentApp');
    String? gcm = prefs.getString('token');
    String? latitude = this.latitude;
    String? longitude = this.longitude;

    if (latitude == null || longitude == null) {
      print('Error: Missing required data');
      return;
    }

    String schoolCode = "";
    String userId = "";
    String type = "a"; // Assuming _type is 'a', you can modify it as needed

    switch (currentApp) {
      case 'm':
        schoolCode = prefs.getString('mschool_code') ?? '';
        userId = prefs.getString('muserid') ?? '';
        break;
      case 't':
        schoolCode = prefs.getString('tschool_code') ?? '';
        userId = prefs.getString('tuserid') ?? '';
        break;
      case 's':
        schoolCode = prefs.getString('sschool_code') ?? '';
        userId = prefs.getString('suserid') ?? '';
        break;
      case 'p':
        schoolCode = prefs.getString('pschool_code') ?? '';
        userId = prefs.getString('puserid') ?? '';
        break;
      default:
        break;
    }

    var link = "http://www.thaidigitalschool.com/dschool_gateway/qr_re.php";
    //print(link);

    var str =
        "?mobile_id=$gcm&gcm_regid=$gcm&app=$currentApp&user_id=$userId&school_id=$schoolCode&change_stat=1&type=$type&qr=$qrtxt&latitude=$latitude&longitude=$longitude";

    var url = link + str;
    //print(url);

    controller.loadRequest(Uri.parse(url));
  }

  void _selectUserType(String type) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if the type matches the currentApp
    if (type == prefs.getString('currentApp')) {
      // Load the relevant preferences and continue
      _loadPreferencesAndContinue(type);
    } else {
      // Update the currentApp to the new type
      print('Updating currentApp to $type');
      await prefs.setString('currentApp', type);
      setState(() {
        currentApp = type;
      });

      // Close the drawer
      Navigator.of(context).pop();

      // Check if the relevant preferences exist for the new type
      if (_preferencesExistForType(type, prefs)) {
        // Continue with the operation
        _loadPreferencesAndContinue(type);
      } else {
        // Navigate to the SchoolsPage
        print('Navigating to SchoolsPage');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SchoolsPage(type: type)),
        );
      }
    }
  }

  bool _preferencesExistForType(String type, SharedPreferences prefs) {
    switch (type) {
      case 'm':
        return prefs.getString('mschool_code') != null &&
            prefs.getString('muserid') != null;
      case 't':
        return prefs.getString('tschool_code') != null &&
            prefs.getString('tuserid') != null;
      case 's':
        return prefs.getString('sschool_code') != null &&
            prefs.getString('suserid') != null;
      case 'p':
        return prefs.getString('pschool_code') != null &&
            prefs.getString('puserid') != null;
      default:
        return false;
    }
  }

  void _loadPreferencesAndContinue(String type) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String schoolCode = "";
    String userId = "";

    print('Loading preferences for type: $type');
    switch (type) {
      case 'm':
        schoolCode = prefs.getString('mschool_code') ?? '';
        userId = prefs.getString('muserid') ?? '';
        break;
      case 't':
        schoolCode = prefs.getString('tschool_code') ?? '';
        userId = prefs.getString('tuserid') ?? '';
        break;
      case 's':
        schoolCode = prefs.getString('sschool_code') ?? '';
        userId = prefs.getString('suserid') ?? '';
        break;
      case 'p':
        schoolCode = prefs.getString('pschool_code') ?? '';
        userId = prefs.getString('puserid') ?? '';
        break;
      default:
        break;
    }

    //print('ค่า ต่าง ๆ');
    //print('schoolCode: $schoolCode');
    //print('userId: $userId');
    _initializeWebView(schoolCode, userId, latitude, longitude);
  }

  void _showAllPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> allPrefs = {};

    Set<String> keys = prefs.getKeys();
    for (String key in keys) {
      allPrefs[key] = prefs.get(key);
    }

    _showPreferencesDialog(allPrefs);
  }

  void _showPreferencesDialog(Map<String, dynamic> prefs) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('All Preferences'),
          content: SingleChildScrollView(
            child: ListBody(
              children: prefs.entries.map((entry) {
                return Text('${entry.key}: ${entry.value}');
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadStudents() async {
    List<Map<String, dynamic>> students = await DBHelper().getStudents();
    setState(() {
      _students = students;
    });
  }

  Future<void> _selectStudent(Map<String, dynamic> student) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('pschool_code', student['school_code']);
    await prefs.setString('puserid', student['user_id']);
    await _loadStudents();
    _initializeWebViewIfReady(); // Reinitialize the WebView with the new student data

    // Close the drawer
    Navigator.of(context).pop();
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    await DBHelper().deleteStudent(student['id']);
    await _loadStudents();
  }

  void _showAddStudentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('เพิ่มนักเรียน'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SchoolsPage(type: 'p'),
                  ),
                ).then((_) => _loadStudents());
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return Column(
                    children: [
                      ListTile(
                        title: Text(student['sd_name']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('ยืนยันการลบ'),
                                  content: const Text(
                                      'คุณต้องการลบรายชื่อนี้หรือไม่?'),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('ยกเลิก'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('ตกลง'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _deleteStudent(student);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        onTap: () => _selectStudent(student),
                      ),
                      const Divider(),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Icon _getIconForCurrentApp() {
    switch (currentApp) {
      case 'm':
        return const Icon(Icons.business, size: 50, color: Colors.white);
      case 't':
        return const Icon(Icons.school, size: 50, color: Colors.white);
      case 's':
        return const Icon(Icons.person, size: 50, color: Colors.white);
      case 'p':
        return const Icon(Icons.family_restroom, size: 50, color: Colors.white);
      default:
        return const Icon(Icons.help, size: 50, color: Colors.white);
    }
  }

  Future<void> _deletePreferencesForType(String type) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการ Logout'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('คุณต้องการ Logout หรือไม่?'),
              SizedBox(height: 8),
              Text(
                'กรณี Logout ต้องลงทะเบียนใหม่',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              child: const Text('ตกลง'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      switch (type) {
        case 'm':
          await prefs.remove('mschool_code');
          await prefs.remove('muserid');
          break;
        case 't':
          await prefs.remove('tschool_code');
          await prefs.remove('tuserid');
          break;
        case 's':
          await prefs.remove('sschool_code');
          await prefs.remove('suserid');
          break;
        case 'p':
          await prefs.remove('pschool_code');
          await prefs.remove('puserid');
          break;
        default:
          break;
      }
      setState(() {
        if (currentApp == type) {
          currentApp = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        title: const Text(
          'Dschool AI',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isScanning)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _onQRCodePressed,
            )
          else if (currentApp != 'p')
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: _onQRCodePressed,
            ),
          if (currentApp == 'p')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddStudentMenu(context),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue[900],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dschool AI',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _getIconForCurrentApp(),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('ผู้บริหาร'),
              trailing: IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _deletePreferencesForType('m'),
              ),
              onTap: () => _selectUserType('m'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('ครู'),
              trailing: IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _deletePreferencesForType('t'),
              ),
              onTap: () => _selectUserType('t'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('นักเรียน'),
              trailing: IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _deletePreferencesForType('s'),
              ),
              onTap: () => _selectUserType('s'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.family_restroom),
              title: const Text('ผู้ปกครอง'),
              trailing: IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _deletePreferencesForType('p'),
              ),
              onTap: () => _selectUserType('p'),
            ),
            const Divider(),
          ],
        ),
      ),
      body: isScanning
          ? Column(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: (result != null)
                        ? Text(
                            'Barcode Type: ${result!.format}   Data: ${result!.code}')
                        : const Text('อ่าน QR หรือ Barcode'),
                  ),
                )
              ],
            )
          : currentApp != null
              ? Stack(
                  children: [
                    if (isControllerInitialized)
                      WebViewWidget(controller: controller),
                    if (!isControllerInitialized)
                      const Center(child: CircularProgressIndicator()),
                  ],
                )
              : const Center(child: Text('กรุณาเลือกประเภทผู้ใช้งานจากเมนู')),
    );
  }
}
