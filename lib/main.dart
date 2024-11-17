import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shelf/edit.dart';
import 'add.dart';

import 'login.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<bool> _isLoggedIn() async {
    String? token = await _storage.read(key: 'token');
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          if (snapshot.data == true) {
            return MaterialApp(
              title: 'Shelf',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
              ),
              home: const ShelfList(title: 'User`s Shelf'),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            );
          } else {
            return MaterialApp(
              title: 'Shelf',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
              ),
              home: LoginPage(),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            );
          }
        }
      },
    );
  }
}

class ShelfList extends StatefulWidget {
  const ShelfList({super.key, required this.title});
  final String title;

  @override
  State<ShelfList> createState() => _ShelfListState();
}

class _ShelfListState extends State<ShelfList> {
  bool _isNSFWMode = false;
  bool _isRichMode = false;
  List<dynamic> _books = [];
  List<dynamic> _filteredBooks = [];
  bool _isLoading = false;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  String? _token;
  String? _uuid;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

 Future<void> _loadCredentials() async {
    _token = await _storage.read(key: 'token');
    _uuid = await _storage.read(key: 'uuid');
    setState(() {});
    await _loadUserdata();
    _fetchData();
  }

  Future<void> _loadUserdata() async {
    final response = await http.get(
      Uri.parse('https://shelf-api.akimax74.net/api/v1/accounts/$_uuid/'),
      headers: {
        'Authorization': 'Token $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _username = data['username'];
      });
    } else {
      // エラーハンドリング
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザーデータの取得に失敗しました')),
      );
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://shelf-api.akimax74.net/api/v2/books/user/$_uuid/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {

        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        print(data);
        setState(() {
          if (_isNSFWMode) {
            _books = data;
          } else {
            _books = data.where((book) => !book['book_NSFW']).toList();
          }
          _filteredBooks = _books;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBook(String uuid) async {
    print('削除処理を開始します: bookId = $uuid');
    try {
      final response = await http.delete(
        Uri.parse('https://shelf-api.akimax74.net/api/v2/books/$uuid/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );

      print('HTTPステータスコード: ${response.statusCode}');
      if (response.statusCode == 204) {
        print('削除成功');
        await _fetchData();
      } else {
        // エラーハンドリング
        print('削除に失敗しました: ${response.statusCode}');
      }
    } catch (e) {
      print('エラーが発生しました: $e');
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'uuid');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _filterBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = _books;
      } else {
        _filteredBooks = _books.where((book) {
          final titleLower = book['book_title'].toLowerCase();
          final authorLower = book['book_author'].toLowerCase();
          final searchLower = query.toLowerCase();
          return titleLower.contains(searchLower) ||
              authorLower.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '検索...',
                ),
                onChanged: _filterBooks,
              )
            : const Text("Books List"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterBooks('');
                }
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.book, size: 100),
                    Text('$_username`s Shelf'),
                  ],
                ),
              ),
            ),
            ListTile(
              title: const Text('NSFWモード'),
              trailing: Switch(
                value: _isNSFWMode,
                onChanged: (bool value) {
                  setState(() {
                    _isNSFWMode = value;
                  });
                  _fetchData(); // トグルが変更されたときにデータを再フェッチ
                },
              ),
            ),
            ListTile(
              title: const Text('リッチモード'),
              trailing: Switch(
                value: _isRichMode,
                onChanged: (bool value) {
                  setState(() {
                    _isRichMode = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('ライセンス'),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () {},
            ),
            ListTile(
              title: const Text('ログアウト'),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () {
                _logout();
              },
            ),
          ],
        ),
        
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _isRichMode
                ? GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // カラム数を指定
                      childAspectRatio: 0.7, // カードの縦横比を指定
                    ),
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, i) {
                      final book = _filteredBooks[i];
                      final isbn = book['ISBN'];
                      return Card(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0), // 角を丸くする場合
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(book['book_image']),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Container(
                                alignment: Alignment.center,
                                color: Colors.black54, // 背景を半透明にする
                                child: Text(
                                  book['book_title'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white),
                                  onSelected: (String result) async {
                                    if (result == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => EditPage(book: book)),
                                      );
                                      print('編集');
                                    } else if (result == 'delete') {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('削除しますか？'),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop(); // ダイアログを閉じる
                                                      },
                                                      child: const Text('キャンセル'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        print(
                                                            '削除ボタンが押されました bookId = ${book['uuid']}');
                                                        try {
                                                          await _deleteBook(book[
                                                              'uuid']); // 削除処理を呼び出す
                                                          Navigator.of(context)
                                                              .pop(); // ダイアログを閉じる
                                                        } catch (e) {
                                                          print('削除処理中にエラーが発生しました: $e');
                                                        }
                                                      },
                                                      child: const Text('削除'),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return [
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('編集'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('削除'),
                                      ),
                                    ];
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, i) {
                      final book = _filteredBooks[i];
                      return ListTile(
                        title: Text(
                          book['book_title'],
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          book['book_author'],
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (String result) async {
                            if (result == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditPage(book: book)),
                              );
                              print('編集');
                            } else if (result == 'delete') {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('削除しますか？'),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(context)
                                                    .pop(); // ダイアログを閉じる
                                              },
                                              child: const Text('キャンセル'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                print(
                                                    '削除ボタンが押されました bookId = ${book['uuid']}');
                                                try {
                                                  await _deleteBook(book[
                                                      'uuid']); // 削除処理を呼び出す
                                                  Navigator.of(context)
                                                      .pop(); // ダイアログを閉じる
                                                } catch (e) {
                                                  print('削除処理中にエラーが発生しました: $e');
                                                }
                                              },
                                              child: const Text('削除'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('編集'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('削除'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddBookPage()),
          );

          if (result == true) {
            _fetchData(); // 登録が成功した場合にデータを再フェッチ
          }
        },
        tooltip: 'Reload',
        child: const Icon(Icons.add),
      ),
    );
  }
}
