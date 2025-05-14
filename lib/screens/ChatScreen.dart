import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'SignLanguageApp.dart';
import 'package:flutter_sound/flutter_sound.dart' as fs;
import 'package:audioplayers/audioplayers.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String userName;
  final String firstName;
  final String lastName;
  final String userImage;
  final String targetUserId;
  final VoidCallback? onMessageSent;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.userImage,
    required this.targetUserId,
    this.onMessageSent,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isWriting = false;
  List<Map<String, dynamic>> messages = [];
  String? token;
  final ImagePicker _picker = ImagePicker();
  bool isMicMode = true;
  bool isRecording = false;
  String? currentUserId;
  fs.FlutterSoundRecorder? _recorder;
  String? recordedFilePath;
  bool isRecordingMessage = false;
  late AudioPlayer audioPlayer;
  int? selectedMessageIndex;
  String transcribeEndpoint = "http://20.121.41.74:8000/speech-to-text";
  String textToSpeechEndpoint = "http://20.121.41.74:8000/text-to-speech";

  @override
  void initState() {
    super.initState();
    print("Username: ${widget.userName}");
    _recorder = fs.FlutterSoundRecorder();
    audioPlayer = AudioPlayer();
    Future.microtask(() async {
      await _recorder!.openRecorder();
      await loadTokenAndMessages();
    });
  }

  Future<void> loadTokenAndMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    print("Saved Token: $savedToken");

    if (savedToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❗ Token مش موجود")));
      return;
    }

    String? userIdFromToken;
    try {
      final parts = savedToken.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid token format');
      }
      final payload = parts[1];
      final payloadPadded = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final decodedPayload = utf8.decode(base64Url.decode(payloadPadded));
      final payloadMap = jsonDecode(decodedPayload) as Map<String, dynamic>;
      userIdFromToken = payloadMap['nameid'] as String?;
      print("UserId from token: $userIdFromToken");
    } catch (e) {
      print("❗ Failed to decode token: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ فشل في قراءة userId من التوكن")),
      );
      return;
    }

    if (userIdFromToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ userId مش موجود في التوكن")),
      );
      return;
    }

    setState(() {
      token = savedToken;
      currentUserId = userIdFromToken;
    });

    await fetchMessages();
  }

  Future<void> fetchMessages() async {
    final url = Uri.parse(
      "https://45ff-45-244-177-153.ngrok-free.app/api/Chat/${widget.chatId}",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
        "استجابة استرجاع الرسائل: ${response.statusCode} - ${response.body}",
      );

      if (response.statusCode == 200 && currentUserId != null) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> fetchedMessages = data['messages'] ?? [];

        final updatedMessages =
            fetchedMessages.map((msg) {
              print(
                "Comparing - My ID: $currentUserId | Message from: ${msg['userId']}",
              );
              print("Message data: $msg");
              final isMe = msg['userId'] == currentUserId;
              print("isMe for this message: $isMe");
              String fileType = msg['fileType'] ?? '';
              String? fileUrl = msg['attachmentUrl'] ?? msg['fileUrl'];
              if (fileUrl != null &&
                  (fileUrl.endsWith('.aac') || fileUrl.endsWith('.opus'))) {
                fileType = 'audio';
              } else if (fileUrl != null &&
                  (fileUrl.endsWith('.jpg') || fileUrl.endsWith('.png'))) {
                fileType = 'image';
              }
              return {
                'text': msg['content'] ?? '',
                'isMe': isMe,
                'filePath': fileUrl,
                'fileType': fileType,
                'fileName': msg['fileName'],
                'transcribedText': msg['transcribedText'] ?? null,
                'localPath': null,
                'audioPath': null,
              };
            }).toList();

        setState(() {
          messages = updatedMessages;
        });
      } else {
        print(
          "❌ فشل في استرجاع الرسائل أو userId مفقود: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("❗ خطأ: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في استرجاع الرسائل: $e")));
    }
  }

  Future<void> sendMessage([File? file, String? localPath]) async {
    final text = _messageController.text.trim();
    if ((text.isEmpty && file == null) || token == null) return;

    final url = Uri.parse(
      file != null
          ? "https://45ff-45-244-177-153.ngrok-free.app/api/storage/upload"
          : "https://45ff-45-244-177-153.ngrok-free.app/api/Chat/send-message",
    );

    try {
      if (file != null) {
        print("رفع ملف: ${file.path}");
        var request =
            http.MultipartRequest('POST', url)
              ..headers['Authorization'] = 'Bearer $token'
              ..files.add(await http.MultipartFile.fromPath('file', file.path));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        final fileName = file.path.split('/').last;
        String fileType = 'file';
        if (file.path.endsWith('.jpg') || file.path.endsWith('.png')) {
          fileType = 'image';
        } else if (file.path.endsWith('.aac') || file.path.endsWith('.opus')) {
          fileType = 'audio';
        }

        print("استجابة رفع الملف: ${response.statusCode} - ${response.body}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final fileUrl = data['blob']?['fileUrl'];
          if (fileUrl == null) {
            throw Exception('فشل في استرجاع رابط الملف');
          }
          print("رابط الملف: $fileUrl");

          final messageResponse = await http.post(
            Uri.parse(
              "https://45ff-45-244-177-153.ngrok-free.app/api/Chat/send-message",
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'roomId': widget.chatId,
              'message': text.isNotEmpty ? text : 'Voice message',
              'isPrivate': true,
              'targetUserId': widget.targetUserId,
              'fileUrl': fileUrl,
              'attachmentUrl': fileUrl,
              'fileType': fileType,
              ' fileName': fileName,
            }),
          );

          print(
            "استجابة إرسال الرسالة: ${messageResponse.statusCode} - ${messageResponse.body}",
          );

          if (messageResponse.statusCode == 200) {
            setState(() {
              messages.add({
                'text': text.isNotEmpty ? text : 'Voice message',
                'filePath': fileUrl,
                'localPath': localPath,
                'fileType': fileType,
                'fileName': fileName,
                'isMe': true,
                'transcribedText': null,
                'audioPath': null,
              });
              _messageController.clear();
              _isWriting = false;
            });
            widget.onMessageSent?.call();
          } else {
            throw Exception(
              'فشل في إرسال الرسالة: ${messageResponse.statusCode}',
            );
          }
        } else {
          print("❌ فشل في رفع الملف: ${response.statusCode}");
          print("Body: ${response.body}");
          setState(() {
            messages.add({
              'text': text.isNotEmpty ? text : 'Voice message',
              'filePath': localPath ?? file.path,
              'localPath': localPath,
              'fileType': fileType,
              'fileName': fileName,
              'isMe': true,
              'transcribedText': null,
              'audioPath': null,
            });
            _messageController.clear();
            _isWriting = false;
          });
          widget.onMessageSent?.call();
        }
      } else {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'roomId': widget.chatId,
            'message': text,
            'isPrivate': true,
            'targetUserId': widget.targetUserId,
          }),
        );

        print(
          "استجابة إرسال الرسالة: ${response.statusCode} - ${response.body}",
        );

        if (response.statusCode == 200) {
          setState(() {
            messages.add({
              'text': text,
              'isMe': true, // تم تعديله ليكون دايمًا true للرسايل المبعتة
              'filePath': null,
              'fileType': null,
              'fileName': null,
              'transcribedText': null,
              'audioPath': null,
            });
            _messageController.clear();
            _isWriting = false;
          });
          widget.onMessageSent?.call();
        } else {
          print("❌ فشل في إرسال الرسالة: ${response.statusCode}");
          print("Body: ${response.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "❗ فشل في إرسال الرسالة: ${response.statusCode} - ${response.body}",
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("❗ خطأ في الإرسال: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في إرسال الرسالة: $e")));
    }
  }

  Future<void> pickFromCamera() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      sendMessage(File(photo.path));
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      sendMessage(File(result.files.single.path!));
    }
  }

  Future<void> startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ لازم تدي صلاحية للمايكروفون")),
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path =
        "${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac";

    try {
      await _recorder!.startRecorder(
        toFile: path,
        codec: fs.Codec.aacADTS,
        audioSource: fs.AudioSource.microphone,
        sampleRate: 44100,
        bitRate: 64000,
      );
      print("تم بدء التسجيل: $path");
    } catch (e) {
      print("خطأ في بدء التسجيل: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في بدء التسجيل: $e")));
      return;
    }

    setState(() {
      isRecording = true;
      isRecordingMessage = true;
      recordedFilePath = path;
      messages.add({
        'text': 'Recording...',
        'isMe': true,
        'filePath': null,
        'fileType': 'recording',
        'fileName': null,
        'transcribedText': null,
      });
    });
  }

  Future<void> stopRecording() async {
    try {
      final path = await _recorder!.stopRecorder();
      print("تم إيقاف التسجيل: $path");

      setState(() {
        isRecording = false;
        isRecordingMessage = false;
        messages.removeWhere((msg) => msg['fileType'] == 'recording');
      });

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          print("الملف موجود: $path");
          await audioPlayer.play(DeviceFileSource(path));
          await sendMessage(file, path);
        } else {
          throw Exception("الملف غير موجود: $path");
        }
      } else {
        throw Exception("لم يتم تسجيل أي ملف");
      }
    } catch (e) {
      print("خطأ في إيقاف التسجيل: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في إيقاف التسجيل: $e")));
    }
  }

  void showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo = await _picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (photo != null) sendMessage(File(photo.path));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) sendMessage(File(image.path));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: const Text('File'),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await FilePicker.platform.pickFiles();
                    if (result != null && result.files.single.path != null) {
                      sendMessage(File(result.files.single.path!));
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  void deleteMessage(int index) {
    setState(() {
      messages.removeAt(index);
      selectedMessageIndex = null;
    });
  }

  void replyToMessage(int index) {
    final message = messages[index];
    setState(() {
      _messageController.text = "رد على: ${message['text']}\n";
      selectedMessageIndex = null;
    });
  }

  Future<void> forwardMessage(int index) async {
    final message = messages[index];
    String? newChatId = await _selectChatToForward();
    if (newChatId != null) {
      final url = Uri.parse(
        "https://6589-45-244-213-140.ngrok-free.app/api/Chat/send-message",
      );

      try {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'roomId': newChatId,
            'message': message['text'],
            'isPrivate': true,
            'targetUserId': widget.targetUserId,
            'fileUrl': message['filePath'],
            'attachmentUrl': message['filePath'],
            'fileType': message['fileType'],
            'fileName': message['fileName'],
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم إعادة توجيه الرسالة بنجاح")),
          );
        } else {
          throw Exception('فشل في إعادة توجيه الرسالة: ${response.statusCode}');
        }
      } catch (e) {
        print("❗ خطأ في إعادة التوجيه: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❗ خطأ في إعادة التوجيه: $e")));
      }
    }
    setState(() {
      selectedMessageIndex = null;
    });
  }

  Future<String?> _selectChatToForward() async {
    String? newChatId;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Forward To"),
          content: TextField(
            onChanged: (value) {
              newChatId = value;
            },
            decoration: const InputDecoration(hintText: "Enter ChatID"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Send"),
            ),
          ],
        );
      },
    );
    return newChatId;
  }

  Future<File?> downloadAudioFile(String audioUrl) async {
    try {
      final response = await http.get(
        Uri.parse(audioUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("استجابة تحميل الملف الصوتي: ${response.statusCode}");

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final filePath =
            "${dir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.aac";
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        print("تم  file: $filePath");
        return file;
      } else {
        throw Exception('فشل في تحميل الملف الصوتي: ${response.statusCode}');
      }
    } catch (e) {
      print("❗ خطأ في تحميل الملف الصوتي: $e");
      return null;
    }
  }

  Future<void> transcribeMessage(int index) async {
    final message = messages[index];
    if (message['filePath'] == null || !message['fileType'].contains('audio')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❗ هذه الرسالة ليست صوتية")));
      return;
    }

    File? audioFile;
    if (message['localPath'] != null &&
        File(message['localPath']).existsSync()) {
      audioFile = File(message['localPath']);
      print("استخدام الملف المحلي: ${message['localPath']}");
    } else {
      audioFile = await downloadAudioFile(message['filePath']);
      if (audioFile != null) {
        setState(() {
          messages[index]['localPath'] = audioFile?.path;
        });
      }
    }

    if (audioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ فشل في تحميل الملف الصوتي")),
      );
      setState(() {
        selectedMessageIndex = null;
      });
      return;
    }

    final url = Uri.parse(transcribeEndpoint);
    print("محاولة الاتصال بالـ API: $url مع الملف: ${audioFile.path}");
    try {
      var request =
          http.MultipartRequest('POST', url)
            ..headers['Accept-Charset'] = 'utf-8'
            ..files.add(
              await http.MultipartFile.fromPath('audio_file', audioFile.path),
            );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("استجابة Transcribe: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        final transcribedText = data['text'] ?? 'لا يوجد نص مستخرج';
        print("النص المستخرج بعد التحويل: $transcribedText");
        setState(() {
          messages[index]['transcribedText'] = transcribedText;
          selectedMessageIndex = null;
        });
      } else {
        throw Exception(
          'فشل في استخراج النص: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("❗ خطأ في Transcribe: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في استخراج النص: $e")));
      setState(() {
        selectedMessageIndex = null;
      });
    } finally {
      if (audioFile.existsSync()) {
        await audioFile.delete();
        print("تم حذف الملف المؤقت: ${audioFile.path}");
      }
    }
  }

  Future<void> textToSpeech(int index) async {
    final message = messages[index];
    print("محتويات الرسالة المختارة: $message");
    final textToConvert = message['text']?.trim() ?? '';

    print("قيمة النص قبل التحويل: $textToConvert");

    if (textToConvert.isEmpty || message['fileType'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❗ هذه الرسالة لا تحتوي على نص صالح أو ليست نصية"),
        ),
      );
      setState(() {
        selectedMessageIndex = null;
      });
      return;
    }

    final url = Uri.parse(textToSpeechEndpoint);
    final body = {'text': textToConvert};
    print("الـ Body قبل الإرسال: ${jsonEncode(body)}");
    print(
      "محاولة الاتصال بالـ API Text-to-Speech: $url مع النص: $textToConvert",
    );

    var request =
        http.MultipartRequest('POST', url)
          ..fields['text'] = textToConvert
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/x-www-form-urlencoded',
          });

    print("الطلب الكامل: ${request.toString()}");
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(
        "استجابة Text-to-Speech: ${response.statusCode} - ${response.body}",
      );

      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('audio/') ?? false) {
          final dir = await getTemporaryDirectory();
          final filePath =
              "${dir.path}/temp_speech_${DateTime.now().millisecondsSinceEpoch}.mp3";
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          print("تم حفظ الملف الصوتي: $filePath");
          setState(() {
            messages[index]['audioPath'] = filePath;
            selectedMessageIndex = null;
          });
          await audioPlayer.play(DeviceFileSource(filePath));
        } else {
          final data = jsonDecode(response.body);
          final audioUrl = data['audioUrl'] ?? data['url'];
          if (audioUrl != null) {
            print("رابط الصوت: $audioUrl");
            setState(() {
              messages[index]['audioPath'] = audioUrl;
              selectedMessageIndex = null;
            });
            await audioPlayer.play(UrlSource(audioUrl));
          } else {
            throw Exception('لا يوجد رابط صوتي في الاستجابة');
          }
        }
      } else {
        throw Exception(
          'فشل في تحويل النص لصوت: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("❗ خطأ في Text-to-Speech: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في تحويل النص لصوت: $e")));
      setState(() {
        selectedMessageIndex = null;
      });
    }
  }

  void pinMessage(int index) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("تم تثبيت الرسالة")));
    setState(() {
      selectedMessageIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar:
          selectedMessageIndex != null
              ? AppBar(
                backgroundColor: Color(0xFFFDF1EB),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      selectedMessageIndex = null;
                    });
                  },
                ),
                title: const Text(
                  "Selected Message",
                  style: TextStyle(color: Colors.black),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.reply, color: Colors.black),
                    onPressed: () {
                      replyToMessage(selectedMessageIndex!);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward, color: Colors.black),
                    onPressed: () {
                      forwardMessage(selectedMessageIndex!);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.black),
                    onPressed: () {
                      deleteMessage(selectedMessageIndex!);
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'Copy') {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text("Copied")));
                      } else if (value == 'Share') {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text("Shared")));
                      } else if (value == 'Transcribe') {
                        transcribeMessage(selectedMessageIndex!);
                      } else if (value == 'TextToSpeech') {
                        textToSpeech(selectedMessageIndex!);
                      } else if (value == 'Pin') {
                        pinMessage(selectedMessageIndex!);
                      }
                      if (value != 'Transcribe' && value != 'TextToSpeech') {
                        setState(() {
                          selectedMessageIndex = null;
                        });
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'Copy',
                            child: Text('Copy'),
                          ),
                          const PopupMenuItem(
                            value: 'Share',
                            child: Text('Share'),
                          ),
                          const PopupMenuItem(
                            value: 'Transcribe',
                            child: Text('Transcribe'),
                          ),
                          const PopupMenuItem(
                            value: 'TextToSpeech',
                            child: Text('TextToSpeech'),
                          ),
                          const PopupMenuItem(value: 'Pin', child: Text('Pin')),
                        ],
                    icon: const Icon(Icons.more_vert, color: Colors.black),
                  ),
                ],
              )
              : AppBar(
                backgroundColor: const Color(0xFFFDF1EB),
                elevation: 1,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                titleSpacing: 0,
                title: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(widget.userImage),
                      radius: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userName.isNotEmpty
                                ? widget.userName
                                : "${widget.firstName.isNotEmpty ? widget.firstName : "Unknown"} ${widget.lastName.isNotEmpty ? widget.lastName : ""}"
                                    .trim(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(
                            "Online",
                            style: TextStyle(color: Colors.green, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: const [
                  IconButton(
                    icon: Icon(Icons.videocam_outlined, color: Colors.black),
                    onPressed: null,
                  ),
                  IconButton(
                    icon: Icon(Icons.call_outlined, color: Colors.black),
                    onPressed: null,
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.black),
                    onPressed: null,
                  ),
                ],
              ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
                  alignment:
                      message['isMe']
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () {
                      setState(() {
                        selectedMessageIndex = index;
                      });
                    },
                    child: ChatBubble(
                      message: message['text'],
                      filePath: message['filePath'],
                      fileType: message['fileType'],
                      fileName: message['fileName'],
                      isMe: message['isMe'],
                      isSelected: selectedMessageIndex == index,
                      transcribedText: message['transcribedText'],
                      audioPath: message['audioPath'],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_emoticon, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            onChanged: (value) {
                              setState(() {
                                _isWriting = value.trim().isNotEmpty;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: "Message",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.attach_file,
                            color: Colors.grey,
                          ),
                          onPressed: showAttachmentOptions,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: pickFromCamera,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_isWriting) {
                      sendMessage();
                    } else {
                      setState(() {
                        isMicMode = !isMicMode;
                      });
                    }
                  },
                  onLongPress: () async {
                    if (isMicMode) {
                      if (isRecording) {
                        await stopRecording();
                      } else {
                        await startRecording();
                      }
                    } else {
                      try {
                        final cameras = await availableCameras();
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    SignLanguageScreen(cameras: cameras),
                          ),
                        );
                        if (result != null &&
                            result is String &&
                            result.isNotEmpty) {
                          setState(() {
                            _messageController.text = result;
                            _isWriting = true;
                          });
                          await sendMessage();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("خطأ في تحميل الكاميرا"),
                          ),
                        );
                      }
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFF37C50),
                    radius: 24,
                    child: Icon(
                      _isWriting
                          ? Icons.send
                          : (isMicMode ? Icons.mic : Icons.videocam),
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    audioPlayer.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

class ChatBubble extends StatefulWidget {
  final String? message;
  final String? filePath;
  final String? fileType;
  final String? fileName;
  final bool isMe;
  final bool isSelected;
  final String? transcribedText;
  final String? audioPath;

  const ChatBubble({
    super.key,
    this.message,
    this.filePath,
    this.fileType,
    this.fileName,
    required this.isMe,
    required this.isSelected,
    this.transcribedText,
    this.audioPath,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  late AudioPlayer audioPlayer;
  bool isPlaying = false;
  String? token;

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token');
    });
  }

  Future<void> _playAudio() async {
    try {
      if (widget.filePath != null) {
        print('محاولة تشغيل: ${widget.filePath}');
        if (widget.filePath!.startsWith('http') ||
            widget.filePath!.startsWith('https')) {
          final response = await http.head(Uri.parse(widget.filePath!));
          print("فحص الرابط: ${response.statusCode}");
          if (response.statusCode != 200) {
            throw Exception(
              'الرابط غير صالح أو لا يمكن الوصول إليه: ${response.statusCode}',
            );
          }
          await audioPlayer.play(UrlSource(widget.filePath!));
        } else if (File(widget.filePath!).existsSync()) {
          await audioPlayer.play(DeviceFileSource(widget.filePath!));
        } else {
          throw Exception('الملف غير موجود في المسار: ${widget.filePath}');
        }
      } else if (widget.audioPath != null) {
        print('محاولة تشغيل الصوت الناتج: ${widget.audioPath}');
        if (widget.audioPath!.startsWith('http') ||
            widget.audioPath!.startsWith('https')) {
          await audioPlayer.play(UrlSource(widget.audioPath!));
        } else if (File(widget.audioPath!).existsSync()) {
          await audioPlayer.play(DeviceFileSource(widget.audioPath!));
        } else {
          throw Exception('الملف الصوتي الناتج غير موجود: ${widget.audioPath}');
        }
      } else {
        throw Exception('لا يوجد رابط للملف الصوتي');
      }
    } catch (e) {
      print('خطأ في تشغيل الصوت: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❗ خطأ في تشغيل الصوت: $e")));
    }
  }

  @override
  void dispose() {
    audioPlayer.stop();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    bool isAudioMessage =
        widget.fileType == 'audio' ||
        (widget.filePath != null &&
            (widget.filePath!.endsWith('.aac') ||
                widget.filePath!.endsWith('.opus')));

    if (widget.fileType == 'image' &&
        widget.filePath != null &&
        widget.filePath!.isNotEmpty) {
      content = Image.network(
        widget.filePath!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
      );
    } else if (isAudioMessage && widget.filePath != null) {
      content = Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: widget.isMe ? Colors.black : Colors.grey[700],
                ),
                onPressed: () async {
                  if (isPlaying) {
                    await audioPlayer.pause();
                  } else {
                    await _playAudio();
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(
                widget.fileName ?? 'Voice Message',
                style: TextStyle(
                  color: widget.isMe ? Colors.black : Colors.grey[700],
                ),
              ),
            ],
          ),
          if (widget.transcribedText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                widget.transcribedText!,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isMe ? Colors.black54 : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      );
    } else if (widget.fileType == 'file' && widget.fileName != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.fileName!,
              style: TextStyle(
                color: widget.isMe ? Colors.black : Colors.grey[700],
              ),
            ),
          ),
        ],
      );
    } else if (widget.fileType == 'recording') {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text('يتم التسجيل...'),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            widget.message ?? '',
            style: TextStyle(
              fontSize: 15,
              color: widget.isMe ? Colors.black : Colors.grey[700],
            ),
          ),
          if (widget.audioPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe ? Colors.black : Colors.grey[700],
                    ),
                    onPressed: () async {
                      if (isPlaying) {
                        await audioPlayer.pause();
                      } else {
                        await _playAudio();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  const Text('تشغيل الصوت'),
                ],
              ),
            ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color:
            widget.isSelected
                ? Colors.grey[400]
                : widget.isMe
                ? const Color(0xFFF8E2D3)
                : Colors.grey[300],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft:
              widget.isMe
                  ? const Radius.circular(12)
                  : const Radius.circular(0),
          bottomRight:
              widget.isMe
                  ? const Radius.circular(0)
                  : const Radius.circular(12),
        ),
      ),
      child: content,
    );
  }
}
