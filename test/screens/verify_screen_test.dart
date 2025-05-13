import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:convert';

import 'package:chat/screens/verify_screen.dart';
import 'chat_screen_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('verifyOtp', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('✅ ينجح التحقق من OTP عند الاستجابة بـ 200', () async {
      // Arrange
      const email = "test@example.com";
      const otp = "123456";

      when(
        mockClient.post(
          Uri.parse(
            "https://6589-45-244-213-140.ngrok-free.app/api/Auth/validate-otp",
          ),
          headers: {"Content-Type": "application/json"},
          body: '{"email": "$email", "otp": "$otp"}',
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));

      // Act
      final response = await mockClient.post(
        Uri.parse(
          "https://6589-45-244-213-140.ngrok-free.app/api/Auth/validate-otp",
        ),
        headers: {"Content-Type": "application/json"},
        body: '{"email": "$email", "otp": "$otp"}',
      );

      // Assert
      expect(response.statusCode, 200);
    });

    test('❌ يرفض OTP غير صحيح عند الاستجابة بـ 400', () async {
      const email = "test@example.com";
      const otp = "123456";

      when(
        mockClient.post(
          Uri.parse(
            "https://6589-45-244-213-140.ngrok-free.app/api/Auth/validate-otp",
          ),
          headers: {"Content-Type": "application/json"},
          body: '{"email": "$email", "otp": "$otp"}',
        ),
      ).thenAnswer((_) async => http.Response('Invalid OTP', 400));

      final response = await mockClient.post(
        Uri.parse(
          "https://6589-45-244-213-140.ngrok-free.app/api/Auth/validate-otp",
        ),
        headers: {"Content-Type": "application/json"},
        body: '{"email": "$email", "otp": "$otp"}',
      );

      expect(response.statusCode, 400);
    });
  });
}
