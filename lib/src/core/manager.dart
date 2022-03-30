import 'dart:developer';

import 'package:astra/src/core/controller.dart';

class ControllerManager {
  static final ControllerManager instance = ControllerManager();

  ControllerManager() : controllers = <Controller>{};

  final Set<Controller> controllers;

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

  static void register(Controller controller) {
    instance.controllers.add(controller);
  }

  static void reasemble() {
    for (var application in instance.controllers) {
      application.reassemble();
    }
  }
}
