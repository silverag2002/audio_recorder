import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isRecording = false;
  bool isPlaying = false;
  List<String> recordings = [];
  double playbackPosition = 0;
  double totalDuration = 1;
  int selectedRecordingIndex = -1;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerCompletion.listen((event) {
      setState(() {
        isPlaying = false;
        playbackPosition = 0;
        selectedRecordingIndex = -1;
      });
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        totalDuration = duration.inMilliseconds.toDouble();
      });
    });
    _audioPlayer.onAudioPositionChanged.listen((position) {
      setState(() {
        playbackPosition = position.inMilliseconds.toDouble();
      });
    });
    _requestPermissions();
    _loadRecordings();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(path: filePath);
      setState(() {
        isRecording = true;
      });
    } catch (e) {
      print("Failed to start recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      isRecording = false;
      if (path != null) {
        recordings.add(path);
      }
    });
  }

  Future<void> _playRecording(String path) async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(path);
    }
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  Future<void> _deleteRecording(int index) async {
    final file = File(recordings[index]);
    await file.delete();
    setState(() {
      recordings.removeAt(index);
      if (selectedRecordingIndex == index) {
        selectedRecordingIndex = -1;
      }
    });
  }

  Future<void> _loadRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> fileList = directory.listSync();
    final List<String> recordingList = [];
    for (FileSystemEntity file in fileList) {
      if (file.uri.pathSegments.last.endsWith('.m4a')) {
        recordingList.add(file.uri.toFilePath());
      }
    }
    setState(() {
      recordings = recordingList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Recorder'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isRecording ? _stopRecording : _startRecording,
              child: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                primary: isRecording ? Colors.red : Colors.green,
                onPrimary: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: recordings.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Recording ${index + 1}'),
                    onTap: () {
                      _playRecording(recordings[index]);
                      setState(() {
                        selectedRecordingIndex = index;
                      });
                    },
                    trailing: Wrap(
                      spacing: 12, // space between two icons
                      children: <Widget>[
                        selectedRecordingIndex == index && isPlaying
                            ? const Icon(Icons.pause)
                            : const Icon(Icons.play_arrow),
                        GestureDetector(
                          onTap: () {
                            _deleteRecording(index);
                          },
                          child: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (isPlaying || isRecording)
              Column(
                children: [
                  Slider(
                    value: playbackPosition,
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                    },
                    min: 0,
                    max: totalDuration,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fast_rewind),
                        onPressed: () {
                          _audioPlayer.seek(Duration(
                              milliseconds: (playbackPosition - 15000)
                                  .toInt()
                                  .clamp(0, totalDuration.toInt())));
                        },
                      ),
                      IconButton(
                        icon: isPlaying
                            ? const Icon(Icons.pause)
                            : const Icon(Icons.play_arrow),
                        onPressed: () {
                          if (selectedRecordingIndex != -1) {
                            _playRecording(recordings[selectedRecordingIndex]);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.fast_forward),
                        onPressed: () {
                          _audioPlayer.seek(Duration(
                              milliseconds: (playbackPosition + 15000)
                                  .toInt()
                                  .clamp(0, totalDuration.toInt())));
                        },
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }
}
