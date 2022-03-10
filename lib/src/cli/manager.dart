import 'dart:developer';

import 'package:astra/core.dart';
import 'package:meta/meta.dart';

class ApplicationManager {
  @internal
  static ApplicationManager? instance;

  @internal
  ApplicationManager() : applications = <Application>{};

  final Set<Application> applications;

  static void init() {
    instance = ApplicationManager();

    registerExtension('ext.astra.reasemble', (isolateId, data) async {
      try {
        reasemble();
        return ServiceExtensionResponse.result('Done');
      } catch (error) {
        return ServiceExtensionResponse.error(0, '$error');
      }
    });
  }

  static void register(Application application) {
    instance?.applications.add(application);
  }

  static void reasemble() {
    var manager = instance;

    if (manager == null) {
      return;
    }

    for (var application in manager.applications) {
      application.reassemble();
    }
  }
}
