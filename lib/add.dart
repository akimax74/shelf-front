import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import 'main.dart';

class AddBookPage extends StatefulWidget {
  @override
  _AddBookPageState createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _bookTitleController = TextEditingController();
  final _bookAuthorController = TextEditingController();
  final _bookISBNController = TextEditingController();
  final _bookPubliserController = TextEditingController();
  bool _isLoading = false;
  bool _isNSFW = false;

  Future<void> _serchISBN(String isbn) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.openbd.jp/v1/get?isbn=$isbn'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data != null && data.isNotEmpty) {
          final bookData = data[0];
          final title = bookData['summary']['title'];
          final author = bookData['summary']['author'];
          String additionalTitle = '';

          try {
            if (bookData['onix']['CollateralDetail']['TextContent'] != null &&
                bookData['onix']['CollateralDetail']['TextContent'].isNotEmpty) {
              additionalTitle = bookData['onix']['CollateralDetail']['TextContent'][0]['Text'];
            }
          } catch (e) {
            // additionalTitleが存在しない場合の処理
            additionalTitle = '';
          }

          setState(() {
            _bookTitleController.text = additionalTitle.isNotEmpty ? '$title - $additionalTitle' : title;
            _bookAuthorController.text = author;
            _bookPubliserController.text = bookData['summary']['publisher'];
          });

          // 画像URLを取得
          final imageUrl = 'https://ndlsearch.ndl.go.jp/thumbnail/$isbn.jpg';

          // 画像URLをbookDataに追加
          await _addBook(imageUrl);

        } else {
          throw Exception('データが見つかりませんでした');
        }
      } else {
        throw Exception('Failed to load data');
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

  Future<void> _addBook(String imageUrl) async {
    setState(() {
      _isLoading = true;
    });

    final storage = FlutterSecureStorage();
    final String? token = await storage.read(key: 'token');
    final String? uuid = await storage.read(key: 'uuid');

    if (token == null || uuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('トークンまたはUUIDが見つかりません')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // 画像URLが有効かどうかを確認
    final response = await http.get(Uri.parse(imageUrl));
    print(imageUrl);
    if (response.statusCode != 200) {
      imageUrl = 'http://shelf-api.akimax74.net/download/nopicture.jpg/';
    }

    final bookData = {
      'book_title': _bookTitleController.text,
      'ISBN': _bookISBNController.text,
      'book_author': _bookAuthorController.text,
      'book_publisher': _bookPubliserController.text,
      'book_NSFW': _isNSFW,
      'book_owner': uuid, // UUIDを使用
      'book_image': imageUrl, // 画像URLを追加
    };

    // 本を追加するためのリクエストを送信
    final addResponse = await http.post(
      Uri.parse('http://shelf-api.akimax74.net/api/v2/books/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(bookData),
    );

    if (addResponse.statusCode == 201) {
      // 本の追加に成功
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('本が追加されました')),
      );
     Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyApp()),
      );
    } else {
      // エラーハンドリング
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('本の追加に失敗しました: ${addResponse.statusCode}')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('本を登録'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _bookISBNController,
              decoration: InputDecoration(
                labelText: 'ISBN',
                suffixIcon: IconButton(
                  icon: Icon(Icons.camera_alt),
                  onPressed: _scanISBN,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _serchISBN(_bookISBNController.text);
              },
              child: Text('ISBNを検索'),
            ),
            TextField(
              controller: _bookTitleController,
              decoration: InputDecoration(labelText: 'タイトル'),
            ),
            TextField(
              controller: _bookAuthorController,
              decoration: InputDecoration(labelText: '著者'),
            ),
            TextField(
              controller: _bookPubliserController,
              decoration: InputDecoration(labelText: '出版社'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NSFW'),
                Switch(
                  value: _isNSFW,
                  onChanged: (value) {
                    setState(() {
                      _isNSFW = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _addBook(''), // 画像データを追加
              child: Text('登録'),
            ),
          ],
        ),
      ),
    );
  }

  void _scanISBN() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('ISBNをスキャン')),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null) {
                  _bookISBNController.text = code;
                  Navigator.pop(context);
                  _serchISBN(code);
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
