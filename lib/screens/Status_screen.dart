import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<Map<String, dynamic>> statuses = [];
  bool isLoading = false;
  String? errorMessage;
  final String baseUrl = 'https://332c-45-244-203-66.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    fetchStories();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchStories() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final token = await getToken();
    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please log in to view stories';
      });
      return;
    }

    final url = Uri.parse("$baseUrl/api/Story/stories");

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("fetchStories response status: ${response.statusCode}");
      print("fetchStories response body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> storyData = jsonDecode(response.body);
        setState(() {
          statuses =
              storyData.map<Map<String, dynamic>>((story) {
                final storyMap = story as Map<String, dynamic>;
                print("Story data: $storyMap");
                String mediaUrl = storyMap['mediaUrl']?.toString() ?? '';
                if (mediaUrl.isNotEmpty && !mediaUrl.startsWith('http')) {
                  mediaUrl = '$baseUrl$mediaUrl';
                }
                return {
                  'storyId':
                      storyMap['storyId']?.toString() ??
                      storyMap['id']?.toString() ??
                      '',
                  'userName': storyMap['userName']?.toString() ?? 'Unknown',
                  'mediaUrl': mediaUrl,
                  'mediaType': storyMap['mediaType']?.toString() ?? 'image',
                  'createdAt': storyMap['createdAt']?.toString() ?? '',
                };
              }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              'Failed to fetch stories: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching stories: $e';
      });
    }
  }

  Future<void> uploadStory() async {
    final token = await getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗ Please log in to upload a story')),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();

    if (media == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❗ No media selected')));
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final file = File(media.path);
    final url = Uri.parse("$baseUrl/api/Story/upload");

    try {
      var request =
          http.MultipartRequest('POST', url)
            ..headers['Authorization'] = 'Bearer $token'
            ..headers['Content-Type'] = 'multipart/form-data'
            ..files.add(
              await http.MultipartFile.fromPath('MediaFile', file.path),
            );

      print("Uploading file: ${file.path} with field name 'MediaFile'");

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      print("uploadStory response status: ${response.statusCode}");
      print("uploadStory response body: ${responseBody.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Story uploaded successfully')),
        );
        fetchStories();
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              'Failed to upload story: ${response.statusCode} - ${responseBody.body}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to upload story: ${responseBody.body}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error uploading story: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❗ Error uploading story: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: fetchStories,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(
                        'https://randomuser.me/api/portraits/men/1.jpg',
                      ),
                    ),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xffF37C50),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                title: const Text(
                  "My Status",
                  style: TextStyle(fontSize: 19, color: Color(0xFF1B222C)),
                ),
                subtitle: const Text(
                  "Tap to add status",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                onTap: uploadStory,
              ),
              const SizedBox(height: 16),
              const Text(
                "Recent Status",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (errorMessage != null)
                Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else if (statuses.isEmpty)
                const Center(child: Text('No stories available'))
              else
                ...statuses.map((status) {
                  if (status['storyId'].isEmpty || status['mediaUrl'].isEmpty) {
                    print("Skipping invalid story: $status");
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      onTap: () {
                        print(
                          "Navigating to story with ID: ${status['storyId']}",
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => StoryViewScreen(
                                  storyId: status['storyId'],
                                  userName: status['userName'],
                                  initialMediaUrl: status['mediaUrl'],
                                  initialMediaType: status['mediaType'],
                                ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xffF37C50),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(status['mediaUrl']),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status['userName'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                status['createdAt'].isNotEmpty
                                    ? DateTime.parse(
                                      status['createdAt'],
                                    ).toLocal().toString()
                                    : 'Unknown time',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}

class StoryViewScreen extends StatefulWidget {
  final String storyId;
  final String userName;
  final String initialMediaUrl;
  final String initialMediaType;

  const StoryViewScreen({
    super.key,
    required this.storyId,
    required this.userName,
    required this.initialMediaUrl,
    required this.initialMediaType,
  });

  @override
  _StoryViewScreenState createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  Map<String, dynamic>? storyDetails;
  bool isLoading = true;
  String? errorMessage;
  VideoPlayerController? _videoController;
  final String baseUrl = 'https://332c-45-244-203-66.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    if (widget.storyId.isEmpty) {
      setState(() {
        storyDetails = {
          'mediaUrl': widget.initialMediaUrl,
          'mediaType': widget.initialMediaType,
          'userName': widget.userName,
          'createdAt': '',
        };
        isLoading = false;
        errorMessage = 'No story ID provided, showing initial data';
      });
      initializeVideo();
    } else {
      fetchStoryDetails();
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchStoryDetails() async {
    final token = await getToken();
    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please log in to view story';
        storyDetails = {
          'mediaUrl': widget.initialMediaUrl,
          'mediaType': widget.initialMediaType,
          'userName': widget.userName,
          'createdAt': '',
        };
      });
      initializeVideo();
      return;
    }

    final url = Uri.parse("$baseUrl/api/Story/${widget.storyId}");

    try {
      print("Fetching story with URL: $url");
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("fetchStoryDetails response status: ${response.statusCode}");
      print("fetchStoryDetails response body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final storyData = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          String mediaUrl =
              storyData['mediaUrl']?.toString() ?? widget.initialMediaUrl;
          if (mediaUrl.isNotEmpty && !mediaUrl.startsWith('http')) {
            mediaUrl = '$baseUrl$mediaUrl';
          }
          storyDetails = {
            'mediaUrl': mediaUrl,
            'mediaType':
                storyData['mediaType']?.toString() ?? widget.initialMediaType,
            'userName': storyData['userName']?.toString() ?? widget.userName,
            'createdAt': storyData['createdAt']?.toString() ?? '',
          };
          isLoading = false;
        });
        initializeVideo();
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              'Failed to fetch story: ${response.statusCode} - ${response.body}';
          storyDetails = {
            'mediaUrl': widget.initialMediaUrl,
            'mediaType': widget.initialMediaType,
            'userName': widget.userName,
            'createdAt': '',
          };
        });
        initializeVideo();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching story: $e';
        storyDetails = {
          'mediaUrl': widget.initialMediaUrl,
          'mediaType': widget.initialMediaType,
          'userName': widget.userName,
          'createdAt': '',
        };
      });
      initializeVideo();
    }
  }

  void initializeVideo() {
    if (storyDetails!['mediaType'] == 'video') {
      _videoController = VideoPlayerController.network(
          storyDetails!['mediaUrl'],
        )
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {});
                _videoController!.play();
              }
            })
            .catchError((e) {
              setState(() {
                errorMessage = 'Error loading video: $e';
              });
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: const Color(0xffF37C50),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child:
                        storyDetails != null
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (storyDetails!['mediaType'] == 'image')
                                    Expanded(
                                      child: Image.network(
                                        storyDetails!['mediaUrl'],
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 50,
                                                ),
                                      ),
                                    )
                                  else if (storyDetails!['mediaType'] ==
                                          'video' &&
                                      _videoController != null)
                                    _videoController!.value.isInitialized
                                        ? Expanded(
                                          child: AspectRatio(
                                            aspectRatio:
                                                _videoController!
                                                    .value
                                                    .aspectRatio,
                                            child: VideoPlayer(
                                              _videoController!,
                                            ),
                                          ),
                                        )
                                        : const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    storyDetails!['userName'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    storyDetails!['createdAt'].isNotEmpty
                                        ? DateTime.parse(
                                          storyDetails!['createdAt'],
                                        ).toLocal().toString()
                                        : 'Unknown time',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : const Text('No story data available'),
                  ),
                ],
              ),
    );
  }
}
