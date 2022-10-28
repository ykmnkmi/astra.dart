import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:astra/src/cli/command.dart';

enum TargetType {
  handlerFunction,
  handlerFunctionAsync,
  handlerType,
  handlerInstance,
  handlerInstanceAsync,
  handlerFactory,
  handlerFactoryAsync,
  applicationType,
  applicationInstance,
  applicationInstanceAsync,
  applicationFactory,
  applicationFactoryAsync;

  static String? urlOfElement(DartType type) {
    var element = type.element;

    if (element == null) {
      return null;
    }

    return element.librarySource!.uri.replace(fragment: element.name).toString();
  }

  static bool isFuture(DartType type) {
    return urlOfElement(type) == 'dart:async#Future';
  }

  static bool isFutureOr(DartType type) {
    return urlOfElement(type) == 'dart:async#FutureOr';
  }

  static bool isResponse(DartType type) {
    return urlOfElement(type) == 'package:shelf/src/response.dart#Response';
  }

  static bool isRequest(DartType type) {
    return urlOfElement(type) == 'package:shelf/src/request.dart#Request';
  }

  static bool isApplication(DartType type) {
    return urlOfElement(type) == 'package:astra/src/core/application.dart#Application';
  }

  static bool isHandler(DartType function) {
    if (function is! FunctionType) {
      return false;
    }

    var returnType = function.returnType;

    if (isFuture(returnType) || isFutureOr(returnType)) {
      var interface = returnType as InterfaceType;
      returnType = interface.typeArguments.first;
    }

    if (isResponse(returnType)) {
      var parameters = function.parameters;

      if (parameters.length == 1) {
        var parameter = parameters.first;

        if (isRequest(parameter.type)) {
          return true;
        }

        throw CliException('target parameter is not Request');
      }

      throw CliException('target parameters count not equal 1');
    }

    return false;
  }

  static TargetType getFor(ResolvedUnitResult resolvedUnitResult, {String target = 'application'}) {
    var library = resolvedUnitResult.libraryElement;

    for (var element in library.topLevelElements) {
      if (element.name == target) {
        // T target(..);
        if (element is FunctionElement) {
          var type = element.type;

          // target is Handler
          if (isHandler(type)) {
            return handlerFunction;
          }

          var returnType = type.returnType;
          var isAsync = false;

          // T = FutureOr
          if (isFuture(returnType) || isFutureOr(returnType)) {
            var interface = returnType as InterfaceType;
            returnType = interface.typeArguments.first;
            isAsync = true;
          }

          // T = Application
          if (isApplication(returnType)) {
            return isAsync ? applicationFactoryAsync : applicationFactory;
          }

          // T = Handler
          if (isHandler(returnType)) {
            return isAsync ? handlerFactoryAsync : handlerFactory;
          }

          if (returnType is InterfaceType) {
            var types = <InterfaceType>[returnType, ...returnType.allSupertypes];

            for (var type in types) {
              // T = Application
              if (isApplication(type)) {
                return applicationType;
              }

              // T = Object { FutureOr<Reponse> call(Request request); }
              var callMethod = type.getMethod('call');

              if (callMethod != null && isHandler(callMethod.type)) {
                return handlerType;
              }

              // T = Object { Handler get call; }
              var callGetter = type.getGetter('call');

              if (callGetter != null && isHandler(callGetter.returnType)) {
                return handlerType;
              }
            }
          }

          throw CliException('target function is not supported');
        }

        // class Target implements T
        if (element is ClassElement) {
          var types = <InterfaceType>[element.thisType, ...element.allSupertypes];

          for (var type in types) {
            // T = Application
            if (isApplication(type)) {
              return applicationType;
            }

            // Target/T = Object { FutureOr<Reponse> call(Request request); }
            var callMethod = type.getMethod('call');

            if (callMethod != null && isHandler(callMethod.type)) {
              return handlerType;
            }

            // Target/T = Object { Handler get call; }
            var callGetter = type.getGetter('call');

            if (callGetter != null && isHandler(callGetter.returnType)) {
              return handlerType;
            }
          }

          throw CliException('target type is not supported');
        }

        // T target = ...
        // T target get => ...
        if (element is PropertyAccessorElement) {
          var variable = element.variable;
          var type = variable.type;
          var isAsync = false;

          // T = FutureOr
          if (isFuture(type) || isFutureOr(type)) {
            var interface = type as InterfaceType;
            type = interface.typeArguments.first;
            isAsync = true;
          }

          // T = Application
          if (isApplication(type)) {
            return isAsync ? applicationInstanceAsync : applicationInstance;
          }

          // T = Handler
          if (isHandler(type)) {
            return isAsync ? handlerFunctionAsync : handlerFunction;
          }

          if (type is InterfaceType) {
            var types = <InterfaceType>[type, ...type.allSupertypes];

            for (var type in types) {
              // T = Application
              if (isApplication(type)) {
                return isAsync ? applicationInstanceAsync : applicationInstance;
              }

              // T = Object { FutureOr<Reponse> call(Request request); }
              var callMethod = type.getMethod('call');

              if (callMethod != null && isHandler(callMethod.type)) {
                return isAsync ? handlerInstanceAsync : handlerInstance;
              }

              // T = Object { Handler get call; }
              var callGetter = type.getGetter('call');

              if (callGetter != null && isHandler(callGetter.returnType)) {
                return isAsync ? handlerInstanceAsync : handlerInstance;
              }
            }
          }

          throw CliException('target instance is not supported');
        }

        throw CliException('$target is not supported');
      }
    }

    throw CliException('$target not found');
  }
}
