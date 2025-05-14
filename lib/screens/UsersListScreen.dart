import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ChatScreen.dart';

class UsersListScreen extends StatefulWidget {
  final String token;

  const UsersListScreen({super.key, required this.token});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<dynamic> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final url = Uri.parse(
      "https://45ff-45-244-177-153.ngrok-free.app/api/chat/users",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          users = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❗ Error: $e")));
      }
    }
  }

  // دالة مساعدة لتحويل الاسم إلى جزأين فقط
  String formatNameToTwoParts(
    String? name,
    String? firstName,
    String? lastName,
  ) {
    // إذا كان name موجودًا، نقسمه إلى أجزاء ونأخذ أول جزأين فقط
    if (name != null && name.trim().isNotEmpty) {
      final nameParts = name.trim().split(RegExp(r'\s+'));
      if (nameParts.length == 1) {
        return nameParts[0]; // إذا كان جزء واحد فقط
      } else if (nameParts.length >= 2) {
        return "${nameParts[0]} ${nameParts[1]}"; // أول جزأين فقط
      }
    }

    // إذا لم يكن name موجودًا، نستخدم firstName وlastName
    final formattedFirstName = (firstName ?? '').trim();
    final formattedLastName = (lastName ?? '').trim();
    if (formattedFirstName.isEmpty && formattedLastName.isEmpty) {
      return "Unknown User";
    } else if (formattedLastName.isEmpty) {
      return formattedFirstName;
    } else if (formattedFirstName.isEmpty) {
      return formattedLastName;
    }
    return "$formattedFirstName $formattedLastName";
  }

  Future<void> createPrivateChat(
    String targetUserId,
    String targetUserName,
    String userImage,
    String firstName,
    String lastName,
  ) async {
    final url = Uri.parse(
      "https://45ff-45-244-177-153.ngrok-free.app/api/chat/create-private-chat?userId=$targetUserId&name=$targetUserName",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final chatData = jsonDecode(response.body);
        String chatId = chatData['chatId'].toString();

        // الانتقال إلى شاشة الشات مع تمرير الاسم المكون من جزأين
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chatId: chatId,
                  userName: targetUserName,
                  userImage:
                      userImage.isNotEmpty
                          ? userImage
                          : 'https://randomuser.me/api/portraits/men/1.jpg',
                  targetUserId: targetUserId,
                  firstName: firstName,
                  lastName: lastName,
                ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to create chat: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Registered Users",
          style: TextStyle(
            fontSize: 22,
            color: Color(0xffF37C50),
            fontWeight: FontWeight.bold,
            fontFamily: "ADLaMDisplay",
          ),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
              ? const Center(child: Text("No users found"))
              : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];

                  // بناء الاسم باستخدام الدالة المساعدة
                  String displayName = formatNameToTwoParts(
                    user['name'],
                    user['firstName'],
                    user['lastName'],
                  );

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        user['imageUrl'] ??
                            'https://randomuser.me/api/portraits/men/${index % 100}.jpg',
                      ),
                    ),
                    title: Text(displayName),
                    subtitle: Text(user['email'] ?? "No email"),
                    onTap: () {
                      createPrivateChat(
                        user['id'].toString(),
                        displayName, // تمرير الاسم المكون من جزأين
                        user['imageUrl'] ?? '',
                        user['firstName'] ?? '',
                        user['lastName'] ?? '',
                      );
                    },
                  );
                },
              ),
    );
  }
}
