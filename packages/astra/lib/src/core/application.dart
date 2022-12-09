import 'dart:async' show Future;
import 'dart:convert' show json;
import 'dart:developer' show ServiceExtensionResponse, registerExtension;

import 'package:astra/src/core/handler.dart';

/// An object that defines the behavior specific to your application.
abstract class Application {
  const Application();

  /// Implement this accessor to define how HTTP requests are handled by
  /// your application.
  Handler get entryPoint;

  /// Override this method to perform initialization tasks.
  Future<void> prepare() async {}

  /// Override this method to rerun any initialization tasks or update any
  /// resources while developing.
  Future<void> reload() async {}

  /// Override this method to release any resources created in prepare.
  Future<void> close() async {}
}

class ApplicationReloader {
  static final Set<Application> _applications = <Application>{};

  static void add(Application application) {
    _applications.add(application);
  }

  static void remove(Application application) {
    _applications.remove(application);
  }

  static Future<void> reloadAll() async {
    await Future.any<void>(<Future<void>>[
      for (var application in _applications) application.reload()
    ]);
  }

  static void register() {
    Future<ServiceExtensionResponse> reload(
      String isolateId,
      Map<String, String> data,
    ) async {
      try {
        await reloadAll();
        return ServiceExtensionResponse.result('{}');
      } catch (error, stackTrace) {
        var data = <String, String>{
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        };

        return ServiceExtensionResponse.error(
          ServiceExtensionResponse.extensionError,
          json.encode(data),
        );
      }
    }

    registerExtension('ext.astra.reload', reload);
  }
}
