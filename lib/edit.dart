import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';

class EditPage extends StatefulWidget {
  const EditPage({Key? key, required this.book}) : super(key: key);
  final Map<String, dynamic> book;

  @override
  _EditPageState createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _bookTitleController = TextEditingController();
  final _bookAuthorController = TextEditingController();
  final _bookISBNController = TextEditingController();
  final _bookPublisherController = TextEditingController();
  bool _isLoading = false;
  bool _isNSFW = false;

  

  @override
  void initState() {
    super.initState();
    _bookTitleController.text = widget.book['book_title'] ?? '';
    _bookAuthorController.text = widget.book['book_author'] ?? '';
    _bookISBNController.text = widget.book['ISBN'] ?? '';
    _bookPublisherController.text = widget.book['book_publisher'] ?? ''; // 修正
    _isNSFW = widget.book['book_NSFW'] ?? false;
  }

  @override
  void dispose() {
    _bookTitleController.dispose();
    _bookAuthorController.dispose();
    _bookISBNController.dispose();
    _bookPublisherController.dispose();
    super.dispose();
  }

  Future<void> _updateBook(String imageUrl) async {
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

    final bookData = {
      'book_title': _bookTitleController.text,
      'ISBN': _bookISBNController.text,
      'book_author': _bookAuthorController.text,
      'book_publisher': _bookPublisherController.text,
      'book_NSFW': _isNSFW,
      'book_owner': uuid, // UUIDを使用
      'book_image': imageUrl, // 画像URLを追加
    };

    try {
      final updateResponse = await http.put(
        Uri.parse('https://shelfapi.akimax74.net/api/v2/books/${widget.book['uuid']}/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode(bookData),
      );

      if (updateResponse.statusCode == 200) {
        // 更新成功
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('本が更新されました')),
        );
        // MyAppに戻る
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MyApp()),
        );
      } else {
        // エラーハンドリング
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('本の更新に失敗しました: ${updateResponse.statusCode}')),
        );
      }
    } catch (e) {
      // エラーハンドリング
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Book'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _bookTitleController,
              decoration: InputDecoration(labelText: 'Book Title'),
            ),
            TextField(
              controller: _bookISBNController,
              decoration: InputDecoration(labelText: 'ISBN'),
            ),
            TextField(
              controller: _bookAuthorController,
              decoration: InputDecoration(labelText: 'Author'),
            ),
            TextField(
              controller: _bookPublisherController,
              decoration: InputDecoration(labelText: 'Publisher'),
            ),
            SwitchListTile(
              title: Text('NSFW'),
              value: _isNSFW,
              onChanged: (bool value) {
                setState(() {
                  _isNSFW = value;
                });
              },
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () {
                      final isbn = _bookISBNController.text;
                      _updateBook('https://shelfapi.akimax74.net/download/$isbn.jpg'); // 画像URLを指定
                    },
                    child: Text('Update Book'),
                  ),
          ],
        ),
      ),
    );
  }
}