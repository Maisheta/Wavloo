import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/screens/status_screen.dart';
import 'package:chat/screens/call_screen.dart';
import 'package:chat/screens/welcome_screen.dart';
import 'package:chat/screens/SettingsScreen.dart';
import 'package:chat/screens/UsersListScreen.dart';
import 'package:chat/screens/ChatScreen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List<dynamic> chats = [];
  bool isLoading = true;
  bool _fabExpanded = false;
  String? token;
  String? userId;

  final String baseUrl = "https://45ff-45-244-177-153.ngrok-free.app";

  @override
  void initState() {
    super.initState();
    loadTokenAndFetchChats();
    startChatPolling();
  }

  void startChatPolling() {
    Future.delayed(Duration.zero, () {
      fetchChats();
    });

    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      fetchChats();
    });
  }

  Future<void> loadTokenAndFetchChats() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getString('userId');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No token found. Please login again.")),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => WelcomeScreen()),
          (route) => false,
        );
      }
    } else {
      fetchChats();
    }
  }

  Future<void> fetchChats() async {
    final url = Uri.parse("$baseUrl/api/chat/chats");

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> fetchedChats = jsonDecode(response.body);

        fetchedChats.sort((a, b) {
          final aTime = a['lastMessageTime'] ?? '';
          final bTime = b['lastMessageTime'] ?? '';
          if (aTime.isEmpty && bTime.isEmpty) return 0;
          if (aTime.isEmpty) return 1;
          if (bTime.isEmpty) return -1;
          return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
        });

        setState(() {
          chats = fetchedChats;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to load chats")));
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("❗ خطأ في استرجاع الشاتات: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في استرجاع الشاتات: $e")));
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: buildAppBar(),
        body:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    buildChatList(),
                    const StatusScreen(),
                    const CallScreen(),
                  ],
                ),
        floatingActionButton: buildFloatingActionButton(),
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      title: const Text(
        "Wavlo",
        style: TextStyle(
          fontSize: 22,
          color: Color(0xffF37C50),
          fontWeight: FontWeight.bold,
          fontFamily: "ADLaMDisplay",
        ),
      ),
      actions: [
        const Icon(Icons.search, color: Color(0xffF37C50)),
        const SizedBox(width: 10),
        Theme(
          data: ThemeData(
            popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
          ),
          child: PopupMenuButton<String>(
            offset: const Offset(-18, 40),
            icon: const Icon(Icons.more_vert, color: Color(0xffF37C50)),
            onSelected: (value) {
              switch (value) {
                case 'Setting':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => const [
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('Profile'),
                  ),
                  PopupMenuItem<String>(
                    value: 'Starred message',
                    child: Text('Starred message'),
                  ),
                  PopupMenuItem<String>(value: 'help', child: Text('Help')),
                  PopupMenuItem<String>(
                    value: 'Setting',
                    child: Text('Setting'),
                  ),
                ],
          ),
        ),
        const SizedBox(width: 10),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const TabBar(
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicator: BoxDecoration(
              color: Color(0xffF37C50),
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            tabs: [
              Tab(child: Center(child: Text("All Chats"))),
              Tab(child: Center(child: Text("Status"))),
              Tab(child: Center(child: Text("Call"))),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildChatList() {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final lastMessage = chat['lastMessage'] ?? '';
        final lastMessageTime = chat['lastMessageTime'];
        final unreadCount = chat['unread'] ?? 0;

        final List<dynamic> participants = chat['participants'] ?? [];
        print("Participants in chat ${chat['id']}: $participants");

        Map<String, dynamic>? otherUser;

        if (participants.isNotEmpty) {
          otherUser = participants.firstWhere(
            (u) => u['id'] != userId,
            orElse: () => null,
          );
        }

        final String fullName =
            otherUser != null
                ? '${otherUser['firstName'] ?? ''} ${otherUser['lastName'] ?? ''}'
                : (chat['name'] ?? 'Unknown');

        final String userImage =
            otherUser != null && otherUser['profileImage'] != null
                ? '$baseUrl${otherUser['profileImage'].startsWith('/') ? otherUser['profileImage'] : '/${otherUser['profileImage']}'}'
                : 'https://randomuser.me/api/portraits/men/1.jpg';

        print("User Image URL: $userImage");

        return ListTile(
          leading: CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(userImage),
            onBackgroundImageError: (exception, stackTrace) {
              print("Error loading image: $exception");
            },
          ),
          title: Text(
            fullName,
            style: TextStyle(
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            formatLastMessage(chat),
            style: TextStyle(
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              color: unreadCount > 0 ? Colors.black : Colors.grey[600],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formatEgyptTime(lastMessageTime),
                style: TextStyle(
                  color:
                      unreadCount > 0 ? const Color(0xffF37C50) : Colors.grey,
                ),
              ),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xffF37C50),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ChatScreen(
                      chatId: chat['id'].toString(),
                      userName: fullName,
                      userImage: userImage,
                      targetUserId: otherUser?['id'] ?? '',
                      firstName: otherUser?['firstName'] ?? '',
                      lastName: otherUser?['lastName'] ?? '',
                      onMessageSent: fetchChats,
                    ),
              ),
            ).then((_) {
              fetchChats();
            });
          },
        );
      },
    );
  }

  String formatLastMessage(Map<String, dynamic> chat) {
    final senderId = chat['lastMessageSenderId'];
    final message = chat['lastMessage'] ?? 'لا توجد رسائل';

    if (senderId == null || userId == null) return message;

    if (senderId == userId) {
      return "YOU: $message";
    } else {
      final List<dynamic> participants = chat['participants'] ?? [];
      final otherUser = participants.firstWhere(
        (u) => u['id'] == senderId,
        orElse: () => null,
      );
      final senderName =
          otherUser != null ? '${otherUser['firstName'] ?? ''}' : 'Unknown';
      return "$senderName: $message";
    }
  }

  String formatEgyptTime(String? utcString) {
    if (utcString == null || utcString.isEmpty) return 'غير متاح';

    try {
      // تحويل النص لـ DateTime (UTC)
      DateTime utcTime = DateTime.parse(utcString);

      // إضافة فرق التوقيت (مصر عادةً +2 ساعة عن UTC)
      final egyptTime = utcTime.add(const Duration(hours: 0));

      final now = DateTime.now().toUtc().add(const Duration(hours: 2));

      if (isSameDay(egyptTime, now)) {
        return DateFormat('hh:mm a').format(egyptTime); // استخدام am/pm
      } else if (isSameDay(egyptTime, now.subtract(const Duration(days: 1)))) {
        return 'Yesterday';
      } else {
        return DateFormat('dd/MM/yyyy').format(egyptTime);
      }
    } catch (e) {
      print("خطأ في تحليل الوقت: $e");
      return 'غير متاح';
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Column buildFloatingActionButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          buildMiniFab(Icons.person_add, 'fab1', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UsersListScreen(token: token!),
              ),
            );
          }),
          buildMiniFab(Icons.group, 'fab2', () {}),
          buildMiniFab(Icons.add, 'fab3', () {}),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          backgroundColor: const Color(0xffF37C50),
          onPressed: toggleFab,
          shape: const CircleBorder(),
          child: Icon(
            _fabExpanded ? Icons.close : Icons.add,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  FloatingActionButton buildMiniFab(
    IconData icon,
    String heroTag, [
    VoidCallback? onPressed,
  ]) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: const Color(0xffF37C50),
      onPressed: onPressed ?? () {},
      child: Icon(icon, color: Colors.white),
    );
  }

  void toggleFab() {
    setState(() {
      _fabExpanded = !_fabExpanded;
    });
  }
}
