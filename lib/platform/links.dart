import 'dart:async';

import 'package:flutter/services.dart';

/// Challenge invite links (https://zerotrust.bz/join#zt1.fitness...) the app
/// was opened with.
/// Android keeps them until the unlocked app takes them, so a link opened
/// while signed out or locked still works after unlocking.
class IncomingLinks {
  IncomingLinks._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'linksArrived') _arrived.add(null);
    });
  }

  static final IncomingLinks instance = IncomingLinks._();

  static const _channel = MethodChannel('zt_fitness/links');
  final _arrived = StreamController<void>.broadcast();

  Stream<void> get arrived => _arrived.stream;

  Future<List<String>> take() async {
    try {
      final list = await _channel.invokeListMethod<String>('takePending');
      return list ?? const [];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }
}
