import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // release 模式下框架异常默认渲染为空白（白屏根因之一），
    // 这里改为可见的错误页，便于定位问题
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exception}\n${details.stack}');
    };
    ErrorWidget.builder = (details) => StartupErrorScreen(details.exception);

    // 同步进入 UI：绝不让任何插件/网络调用阻塞首帧
    runApp(const SecondHandApp());
  }, (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}
