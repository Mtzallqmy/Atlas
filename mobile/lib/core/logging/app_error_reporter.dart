import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract interface class ErrorSink {
  FutureOr<void> record(Object error, StackTrace stackTrace, {String? context});
}

class DeveloperLogErrorSink implements ErrorSink {
  const DeveloperLogErrorSink();

  @override
  void record(Object error, StackTrace stackTrace, {String? context}) {
    developer.log(
      context ?? 'Unhandled application error',
      name: 'anatomy_atlas',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}

class AppErrorReporter {
  AppErrorReporter({ErrorSink sink = const DeveloperLogErrorSink()}) : _sink = sink;
  final ErrorSink _sink;

  void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _sink.record(details.exception, details.stack ?? StackTrace.current, context: details.context?.toDescription());
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _sink.record(error, stack, context: 'PlatformDispatcher');
      return true;
    };
    ErrorWidget.builder = (details) => Material(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('تعذر عرض هذا الجزء من التطبيق', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                if (kDebugMode) Text(details.exceptionAsString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
