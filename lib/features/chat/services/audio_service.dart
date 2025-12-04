import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Service to handle audio recording and playback using SoLoud
class AudioService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  SoLoud? _soloud;
  AudioSource? _currentSource;
  SoundHandle? _currentHandle;
  
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasPermission = false;
  bool _isInitialized = false;
  
  StreamSubscription? _recordingSubscription;
  final _audioStreamController = StreamController<Uint8List>.broadcast();
  
  // Audio buffer for playback
  final List<Uint8List> _audioBuffer = [];
  bool _isBuffering = false;
  
  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get hasPermission => _hasPermission;
  bool get isInitialized => _isInitialized;
  
  /// Stream of recorded audio data (PCM format)
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  /// Initialize audio service
  Future<void> initialize() async {
    await _checkPermissions();
    await _initializeSoLoud();
  }

  /// Initialize SoLoud engine
  Future<void> _initializeSoLoud() async {
    try {
      _soloud = SoLoud.instance;
      await _soloud!.init();
      _isInitialized = true;
      debugPrint('SoLoud initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing SoLoud: $e');
      _isInitialized = false;
    }
  }

  /// Check and request microphone permission using record package
  Future<bool> _checkPermissions() async {
    try {
      // Use record package's built-in permission check
      // This works on all platforms including macOS
      _hasPermission = await _recorder.hasPermission();
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      // On macOS, if permission check fails, assume we need to try recording
      // The system will prompt for permission when we actually try to record
      if (Platform.isMacOS) {
        _hasPermission = true; // Optimistically assume permission
        notifyListeners();
        return true;
      }
      _hasPermission = false;
      notifyListeners();
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    return await _checkPermissions();
  }

  /// Start recording audio
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    try {
      // Check if recorder has permission (this also requests if needed)
      final isAvailable = await _recorder.hasPermission();
      if (!isAvailable) {
        debugPrint('Microphone permission not granted');
        _hasPermission = false;
        notifyListeners();
        return;
      }
      
      _hasPermission = true;
      
      // Configure for PCM streaming (16-bit, 16kHz, mono)
      // This is the format expected by Gemini Live API
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      );
      
      // Start streaming
      final stream = await _recorder.startStream(config);
      
      _isRecording = true;
      notifyListeners();
      
      // Forward audio data
      _recordingSubscription = stream.listen(
        (data) {
          _audioStreamController.add(data);
        },
        onError: (error) {
          debugPrint('Recording error: $error');
          stopRecording();
        },
      );
      
      debugPrint('Started recording (16kHz, 16-bit, mono)');
      
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      _hasPermission = false;
      notifyListeners();
    }
  }

  /// Stop recording audio
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      await _recordingSubscription?.cancel();
      _recordingSubscription = null;
      
      await _recorder.stop();
      
      _isRecording = false;
      notifyListeners();
      
      debugPrint('Stopped recording');
      
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  /// Add audio data to playback buffer
  void addToBuffer(Uint8List audioData) {
    _audioBuffer.add(audioData);
    
    // Start playing if not already playing and we have enough data
    if (!_isPlaying && !_isBuffering && _audioBuffer.isNotEmpty) {
      _playBuffer();
    }
  }

  /// Play buffered audio
  Future<void> _playBuffer() async {
    if (_audioBuffer.isEmpty || _isBuffering || _soloud == null) return;
    
    _isBuffering = true;
    
    try {
      // Combine all audio chunks
      final totalLength = _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combinedAudio = Uint8List(totalLength);
      
      int offset = 0;
      for (final chunk in _audioBuffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      _audioBuffer.clear();
      
      // Create WAV from PCM data (Gemini returns 24kHz audio)
      final wavData = _createWavFromPcm(combinedAudio, 24000, 1, 16);
      
      // Load audio from memory using SoLoud
      _currentSource = await _soloud!.loadMem(
        'response.wav',
        wavData,
      );
      
      if (_currentSource != null) {
        _isPlaying = true;
        notifyListeners();
        
        // Play the audio
        _currentHandle = await _soloud!.play(_currentSource!);
        
        // Wait for playback to complete
        if (_currentHandle != null) {
          // Poll for completion
          while (_soloud!.getIsValidVoiceHandle(_currentHandle!)) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
      }
      
    } catch (e) {
      debugPrint('Error playing audio: $e');
    } finally {
      _isBuffering = false;
      _isPlaying = false;
      
      // Dispose the source
      if (_currentSource != null) {
        await _soloud?.disposeSource(_currentSource!);
        _currentSource = null;
      }
      
      notifyListeners();
      
      // Check if there's more audio to play
      if (_audioBuffer.isNotEmpty) {
        _playBuffer();
      }
    }
  }

  /// Create WAV file from PCM data
  Uint8List _createWavFromPcm(Uint8List pcmData, int sampleRate, int channels, int bitsPerSample) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = dataSize + 36;
    
    final header = ByteData(44);
    
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    
    // fmt subchunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // data subchunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);
    
    // Combine header and PCM data
    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataSize, pcmData);
    
    return wav;
  }

  /// Play audio data directly (from AI response)
  Future<void> playAudio(Uint8List audioData) async {
    addToBuffer(audioData);
  }

  /// Stop playing audio
  Future<void> stopPlaying() async {
    if (_currentHandle != null && _soloud != null) {
      _soloud!.stop(_currentHandle!);
    }
    
    _audioBuffer.clear();
    _isPlaying = false;
    _isBuffering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopRecording();
    stopPlaying();
    _recorder.dispose();
    _soloud?.deinit();
    _audioStreamController.close();
    super.dispose();
  }
}
