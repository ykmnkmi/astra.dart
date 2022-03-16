import 'dart:developer';

import 'package:astra/src/core/application.dart';

class ApplicationManager {
  static final ApplicationManager instance = ApplicationManager();

  ApplicationManager() : applications = <Application>{};

  final Set<Application> applications;

  static void setup() {
    registerExtension('ext.astra.reasemble', (isolateId, data) async {
      try {
        reasemble();
        return ServiceExtensionResponse.result('{}');
      } catch (error) {
        return ServiceExtensionResponse.error(0, '$error');
      }
    });
  }

  static void register(Application application) {
    instance.applications.add(application);
  }

  static void reasemble() {
    for (var application in instance.applications) {
      application.reassemble();
    }
  }
}
