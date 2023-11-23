import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OPANGATIMIN',
      home: HomePage(),
    );
  }
}

class TukangOjek {
  final int? id;
  final String nama;
  final String nopol;

  TukangOjek({this.id, required this.nama, required this.nopol});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'nopol': nopol,
    };
  }

  factory TukangOjek.fromMap(Map<String, dynamic> map) {
    return TukangOjek(
      id: map['id'],
      nama: map['nama'],
      nopol: map['nopol'],
    );
  }
}

class Transaksi {
  final int? id;
  final int tukangOjekId;
  final int harga;
  final String timestamp;

  Transaksi({this.id, required this.tukangOjekId, required this.harga, required this.timestamp});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tukangOjekId': tukangOjekId,
      'harga': harga,
      'timestamp': timestamp,
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map) {
    return Transaksi(
      id: map['id'],
      tukangOjekId: map['tukangOjekId'],
      harga: map['harga'],
      timestamp: map['timestamp'],
    );
  }
}

class DatabaseHandler {
  Future<Database> initializeDB() async {
    String path = await getDatabasesPath();
    return openDatabase(
      join(path, 'opangatimin.db'),
      onCreate: (database, version) async {
        await database.execute(
          "CREATE TABLE tukangojek(id INTEGER PRIMARY KEY, nama TEXT, nopol TEXT);",
        );
        await database.execute(
          "CREATE TABLE transaksi(id INTEGER PRIMARY KEY, tukangOjekId INTEGER, harga INTEGER, timestamp TEXT);",
        );
      },
      version: 1,
    );
  }

  Future<int> insertTukangOjek(TukangOjek tukangOjek) async {
    final Database db = await initializeDB();
    return await db.insert('tukangojek', tukangOjek.toMap());
  }

  Future<int> insertTransaksi(Transaksi transaksi) async {
    final Database db = await initializeDB();
    return await db.insert('transaksi', transaksi.toMap());
  }

  Future<List<TukangOjek>> retrieveTukangOjeks() async {
    final Database db = await initializeDB();
    final List<Map<String, dynamic>> queryResult = await db.query('tukangojek');
    return queryResult.map((e) => TukangOjek.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getOjeksWithOrdersAndOmzet() async {
    final Database db = await initializeDB();
    final List<Map<String, dynamic>> results = await db.rawQuery(
        'SELECT t.nama, COUNT(tr.id) AS jumlahOrder, SUM(tr.harga) AS omzet '
            'FROM tukangojek t '
            'LEFT JOIN transaksi tr ON t.id = tr.tukangOjekId '
            'GROUP BY t.id;'
    );
    return results;
  }
}


class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DatabaseHandler handler;

  @override
  void initState() {
    super.initState();
    handler = DatabaseHandler();
    handler.initializeDB().whenComplete(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Halaman Utama'),
      ),
      body: FutureBuilder(
        future: handler.getOjeksWithOrdersAndOmzet(),
        builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data?.length,
                itemBuilder: (context, index) {
                  var ojek = snapshot.data![index];
                  return ListTile(
                    title: Text(ojek['nama']),
                    subtitle: Text('Order: ${ojek['jumlahOrder']}, Omzet: ${ojek['omzet']}'),
                  );
                },
              );
            } else {
              return Center(child: Text('Tidak ada data tukang ojek.'));
            }
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      // Add the buttons here
    );
  }
}

class TambahOjek extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nopolController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Tukang Ojek'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Nama'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'masukkan nama tukang ojek';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nopolController,
                decoration: InputDecoration(labelText: 'Nomor Polisi'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'masukkan nomor polisi';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    TukangOjek newOjek = TukangOjek(
                      nama: _nameController.text,
                      nopol: _nopolController.text,
                    );
                    DatabaseHandler handler = DatabaseHandler();
                    await handler.insertTukangOjek(newOjek);
                    Navigator.pop(context);
                  }
                },
                child: Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TambahTransaksi extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final List<String> ojekList = ['Ojek 1', 'Ojek 2', 'Ojek 3'];
  String? selectedOjek;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Transaksi'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: selectedOjek,
                hint: Text('Pilih Tukang Ojek'),
                onChanged: (value) {
                  selectedOjek = value;
                },
                items: ojekList.map((ojek) {
                  return DropdownMenuItem(
                    value: ojek,
                    child: Text(ojek),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'pilih tukang ojek';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Harga'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'masukkan harga';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    Transaksi newTransaksi = Transaksi(
                      tukangOjekId: ojekList.indexOf(selectedOjek!) + 1,
                      harga: int.parse(_priceController.text),
                      timestamp: DateTime.now().toIso8601String(),
                    );
                    DatabaseHandler handler = DatabaseHandler();
                    await handler.insertTransaksi(newTransaksi);
                    Navigator.pop(context);
                  }
                },
                child: Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
