import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';

import '../../shared/app_text.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_widgets.dart';

/// Plays the intro clip once, muted until the user turns sound on; any failure or slow load falls through to the app.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = VideoPlayerController.asset('assets/intro/intro.mp4');
  Timer? _loadTimeout;
  bool _finished = false;
  bool _muted = true;

  Future<void> _toggleSound() async {
    final muted = !_muted;
    setState(() => _muted = muted);
    if (_controller.value.isInitialized) {
      await _controller.setVolume(muted ? 0 : 1);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTimeout = Timer(const Duration(seconds: 10), () {
      if (!_controller.value.isInitialized) {
        _finish();
      }
    });
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(_muted ? 0 : 1);
      if (!mounted || _finished) {
        return;
      }
      _controller.addListener(_watchEnd);
      await _controller.play();
      setState(() {});
    } catch (_) {
      _finish();
    }
  }

  void _watchEnd() {
    final value = _controller.value;
    if (value.hasError) {
      _finish();
      return;
    }
    if (value.isInitialized && value.duration > Duration.zero && value.position >= value.duration - const Duration(milliseconds: 120)) {
      _finish();
    }
  }

  void _finish() {
    if (_finished || !mounted) {
      return;
    }
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _controller.removeListener(_watchEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final ready = _controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Toon.ink,
      body: GestureDetector(
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Image(image: AssetImage('assets/intro/intro_poster.webp'), fit: BoxFit.cover),
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            // The <video> element swallows browser clicks unless something sits above it in the DOM.
            Positioned.fill(child: PointerInterceptor(child: const SizedBox.expand())),
            Positioned(
              top: 14,
              right: 14,
              child: SafeArea(
                child: Tooltip(
                  message: _muted ? text.soundOn : text.soundOff,
                  child: Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: _toggleSound,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Toon.ink.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Toon.white.withValues(alpha: 0.8), width: 1.5),
                          ),
                          child: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 18, color: Toon.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: SafeArea(
                child: ToonButton(label: text.skipIntro, color: Toon.sun, compact: true, onPressed: _finish),
              ),
            ),
            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: false,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(playedColor: Toon.sun, backgroundColor: Colors.transparent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
