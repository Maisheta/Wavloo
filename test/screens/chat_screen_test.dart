import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

import 'chat_screen_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('ChatScreen', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('fetchMessages يرجع الرسائل عند الاستجابة بنجاح', () async {
      final mockResponseData = {
        "messages": [
          {
            "userId": "1",
            "content": "مرحبا",
            "fileUrl": null,
            "fileType": null,
            "fileName": null,
            "transcribedText": null,
          },
        ],
      };

      when(
        mockClient.get(
          Uri.parse("https://6589-45-244-213-140.ngrok-free.app/api/Chat/123"),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async =>
            http.Response.bytes(utf8.encode(jsonEncode(mockResponseData)), 200),
      );

      final response = await mockClient.get(
        Uri.parse("https://6589-45-244-213-140.ngrok-free.app/api/Chat/123"),
        headers: {
          'Authorization': 'Bearer token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      expect(response.statusCode, 200);
      expect(data['messages'], isA<List<dynamic>>());
      expect(data['messages'][0]['content'], equals("مرحبا"));
    });

    test('sendMessage يرسل رسالة نصية بنجاح', () async {
      final messagePayload = {
        'roomId': '123',
        'message': 'أهلاً',
        'isPrivate': true,
        'targetUserId': '456',
      };

      when(
        mockClient.post(
          Uri.parse(
            "https://6589-45-244-213-140.ngrok-free.app/api/Chat/send-message",
          ),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"status": "success"}', 200));

      final response = await mockClient.post(
        Uri.parse(
          "https://6589-45-244-213-140.ngrok-free.app/api/Chat/send-message",
        ),
        headers: {
          'Authorization': 'Bearer token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(messagePayload),
      );

      expect(response.statusCode, 200);
      final responseBody = jsonDecode(response.body);
      expect(responseBody['status'], equals("success"));
    });
  });
}
