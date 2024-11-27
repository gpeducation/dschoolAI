import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dschool_ai/screens/home_page.dart'; // Import your home page
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dschool_ai/screens/users_page.dart'; // Import the UsersPage
// Import the DBHelper
import 'firebase_options.dart';

// Import the DBHelper

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the default options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
// Request notification permissions
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  await initNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> showNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'dschool_main_channel',
    'DSchool Notifications',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  showNotification(
    message.notification?.title ?? 'New Message',
    message.notification?.body ?? 'You have a new message',
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSchool',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color.fromARGB(
            255, 247, 247, 248), // Set the background color here
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false, // Hide the debug banner
      routes: {
        '/home_page': (context) => const HomePage(
            token: ''), // Define the home_page route with a default token
        '/users_page': (context) => const UsersPage(
            type: 'p', schoolId: 'your_school_id'), // Add the users_page route
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/home_page') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('token')) {
            return MaterialPageRoute(
              builder: (context) {
                return HomePage(token: args['token']);
              },
            );
          } else {
            // Handle the case where arguments are null or do not contain 'token'
            return MaterialPageRoute(
              builder: (context) {
                return const Scaffold(
                  body: Center(
                    child: Text('No token provided'),
                  ),
                );
              },
            );
          }
        }
        // Handle other routes here if needed
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('Unknown route: ${settings.name}'),
            ),
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFCMToken();
    _setupFCM();
  }

  Future<void> _loadFCMToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    setState(() {
      _isLoading = false;
    });
    _navigateToHomePage(token);
  }

  Future<void> _saveFCMToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  void _navigateToHomePage(String token) {
    print('token: $token');
    Navigator.of(context).pushReplacementNamed(
      '/home_page',
      arguments: {'token': token},
    );
  }

  Future<void> _setupFCM() async {
    // Get APNS token first
    String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();

    // Then get FCM token
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $fcmToken');
    if (mounted) {
      if (fcmToken != null) {
        _saveFCMToken(fcmToken);
        _navigateToHomePage(fcmToken);
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      //if (mounted) {
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        showNotification(
          message.notification?.title ?? 'New Message',
          message.notification?.body ?? 'You have a new message',
        );
      }
      //}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.blue.shade900, // Set the background color here
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : const Text(
                  'ยินดีต้อนรับ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
        ),
      ),
    );
  }
}
