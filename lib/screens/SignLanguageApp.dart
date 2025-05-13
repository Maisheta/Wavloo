import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sign Language Recognition',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: SignLanguageScreen(cameras: cameras),
    );
  }
}

class SignLanguageScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SignLanguageScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _SignLanguageScreenState createState() => _SignLanguageScreenState();
}

class _SignLanguageScreenState extends State<SignLanguageScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  String _currentText = '';
  String? _actionFeedback;
  double _fps = 0.0;
  bool _isStable = false;
  String? _errorMessage;
  Timer? _timer;
  final String _apiUrl = 'http://20.121.41.74:5000/ws';
  final String _resetUrl = 'http://20.121.41.74:5000/reset';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final frontCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      try {
        if (_controller!.value.isInitialized) {
          await _controller!.setFlashMode(FlashMode.torch);
        }
      } catch (e) {
        print('Flash mode not supported: $e');
      }

      if (!mounted) return;

      setState(() {});
      _startImageStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing camera: $e';
        });
      }
    }
  }

  void _startImageStream() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!mounted ||
          _controller == null ||
          !_controller!.value.isInitialized) {
        return;
      }
      if (!_isProcessing) {
        await _processFrame();
      }
    });
  }

  Future<void> _processFrame() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final image = await _controller!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentText = data['current_text'] ?? '';
          _actionFeedback = data['action_feedback'];
          _fps = data['fps']?.toDouble() ?? 0.0;
          _isStable = data['is_stable'] ?? false;
        });
      } else {
        setState(() {
          _errorMessage =
              'API Error: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error processing frame: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _resetProcessor() async {
    try {
      final response = await http.post(
        Uri.parse(_resetUrl),
        headers: {'Content-Type': 'application/json'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _currentText = '';
          _actionFeedback = null;
          _errorMessage = 'Processor reset successfully';
        });
      } else {
        setState(() {
          _errorMessage =
              'Reset error: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error resetting processor: $e';
      });
    }
  }

  Future<void> _sendToChat() async {
    if (_currentText.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No text to send!';
        });
      }
      return;
    }

    // إرجاع النص للـ ChatScreen بدل إرساله مباشرة للـ API
    Navigator.pop(context, _currentText);

    if (mounted) {
      setState(() {
        _errorMessage = 'Message prepared for chat! ✅';
        _currentText = '';
        _actionFeedback = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Text sent to chat!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_controller != null) {
      _controller!.setFlashMode(FlashMode.off).catchError((e) {
        print('Error turning off flash: $e');
      });
      _controller!.dispose();
      _controller = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final scale = 1 / (_controller!.value.aspectRatio * size.aspectRatio);

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(_controller!)),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isStable
                              ? Colors.green.withOpacity(0.8)
                              : Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isStable ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isStable ? 'Stable' : 'Unstable',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'FPS: ${_fps.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_actionFeedback != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _actionFeedback!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _currentText.isEmpty
                          ? 'Waiting for sign...'
                          : _currentText,
                      style: TextStyle(
                        color:
                            _currentText.isEmpty
                                ? Colors.white.withOpacity(0.5)
                                : Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _resetProcessor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _currentText.isEmpty ? null : _sendToChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _currentText.isEmpty ? Colors.grey : Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Send to Chat',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
