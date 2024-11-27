import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'students.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            school_code TEXT,
            user_id TEXT,
            sd_name TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertStudent(Map<String, dynamic> student) async {
    Database db = await database;
    return await db.insert('students', student);
  }

  Future<List<Map<String, dynamic>>> getStudents() async {
    Database db = await database;
    return await db.query('students');
  }

  Future<int> deleteStudent(int id) async {
    Database db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }
}
