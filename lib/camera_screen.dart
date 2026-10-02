import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'gallery/media_store.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _lens;
  final _store = MediaStore();
  bool _busy = false, _video = false, _recording = false, _active = true;
  String? _error;
  String? _pendingPath;
  bool _pendingVideo = false;
  int _generation = 0, _seconds = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _open({CameraDescription? lens}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    final old = _controller;
    _controller = null;
    await old?.dispose();
    CameraController? controller;
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) throw StateError('No camera found');
      _lens =
          lens ??
          _lens ??
          _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );
      controller = CameraController(
        _lens!,
        ResolutionPreset.veryHigh,
        enableAudio: _video,
      );
      await controller.initialize();
      if (!mounted || !_active || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Could not open the camera. Allow camera access (and microphone access for video), then retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _savePending() async {
    if (_pendingPath == null) return;
    await _store.importCapture(_pendingPath!, video: _pendingVideo);
    _pendingPath = null;
    _notice('Saved to Gallery');
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_busy || controller == null || !_store.supported) return;
    setState(() => _busy = true);
    try {
      if (_pendingPath != null) {
        await _savePending();
        return;
      }
      if (_video && !_recording) {
        await controller.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _recording = true;
          _seconds = 0;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      } else {
        final result = _video
            ? await controller.stopVideoRecording()
            : await controller.takePicture();
        _timer?.cancel();
        if (mounted) setState(() => _recording = false);
        _pendingPath = result.path;
        _pendingVideo = _video;
        await _savePending();
      }
    } catch (_) {
      _notice(
        _pendingPath == null
            ? 'Capture failed. Please try again.'
            : 'Could not save. Free some space, then tap Retry save.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _release() async {
    ++_generation;
    final controller = _controller;
    _controller = null;
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _recording = false;
        _busy = controller != null;
      });
    }
    if (controller == null) return;
    try {
      if (controller.value.isRecordingVideo) {
        final result = await controller.stopVideoRecording();
        _pendingPath = result.path;
        _pendingVideo = true;
        await _savePending();
      }
    } catch (_) {
      _notice(
        'Recording was interrupted. Check Gallery before recording again.',
      );
    } finally {
      await controller.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void>? _releaseTask;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _active = false;
      _releaseTask ??= _release();
    }
    if (state == AppLifecycleState.resumed) {
      _active = true;
      () async {
        await _releaseTask;
        _releaseTask = null;
        if (mounted && _active) await _open();
      }();
    }
  }

  Future<void> _exit() async {
    await _release();
    if (_pendingPath != null && mounted) {
      await _open();
      _notice(
        'Your capture has not been saved yet. Tap Retry save before leaving.',
      );
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_recording && !_busy && _pendingPath == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy) _exit();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: [
          IconButton(
            tooltip: 'Switch front/back camera',
            onPressed:
                _busy ||
                    _recording ||
                    _pendingPath != null ||
                    _cameras.length < 2
                ? null
                : () {
                    final target =
                        _lens?.lensDirection == CameraLensDirection.front
                        ? CameraLensDirection.back
                        : CameraLensDirection.front;
                    final candidates = _cameras.where(
                      (c) => c.lensDirection == target,
                    );
                    if (candidates.isNotEmpty) _open(lens: candidates.first);
                  },
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.white),
                          ),
                          TextButton(
                            onPressed: () => _open(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _controller == null
                  ? const CircularProgressIndicator()
                  : CameraPreview(_controller!),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_store.supported)
                    const Text(
                      'Use the Android app to save photos and videos.',
                      style: TextStyle(color: Colors.white),
                    ),
                  if (_recording)
                    Text(
                      'Recording ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  SegmentedButton<bool>(
                    style: const ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Color(0xFFEDE7F6),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Photo'),
                        icon: Icon(Icons.photo_camera),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Video'),
                        icon: Icon(Icons.videocam),
                      ),
                    ],
                    selected: {_video},
                    onSelectionChanged:
                        _busy || _recording || _pendingPath != null
                        ? null
                        : (value) {
                            setState(() => _video = value.first);
                            _open();
                          },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy || _controller == null || !_store.supported
                        ? null
                        : _capture,
                    icon: Icon(
                      _recording
                          ? Icons.stop
                          : (_video
                                ? Icons.fiber_manual_record
                                : Icons.camera_alt),
                    ),
                    label: Text(
                      _busy
                          ? 'Please wait…'
                          : _pendingPath != null
                          ? 'Retry save'
                          : _recording
                          ? 'Stop and save'
                          : _video
                          ? 'Record video'
                          : 'Take photo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
