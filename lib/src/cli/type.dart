import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:astra/src/cli/command.dart';

enum TargetType {
  handlerFunction,
  handlerType,
  handlerInstance,
  handlerFactory,
  handlerFactoryAsync,
  applicationType,
  applicationInstance,
  applicationFactory,
  applicationFactoryAsync;

  bool get canReload {
    return index < handlerFunction.index;
  }

  static String? urlOfElement(Element? element) {
    if (element == null) {
      return null;
    }

    if (element.kind == ElementKind.DYNAMIC) {
      return 'dart:core#dynamic';
    }

    return element.librarySource!.uri.replace(fragment: element.name).toString();
  }

  static bool isFuture(Element? element) {
    return urlOfElement(element) == 'dart:async#Future';
  }

  static bool isFutureOr(Element? element) {
    return urlOfElement(element) == 'dart:async#FutureOr';
  }

  static bool isResponse(Element? element) {
    return urlOfElement(element) == 'package:shelf/src/response.dart#Response';
  }

  static bool isRequest(Element? element) {
    return urlOfElement(element) == 'package:shelf/src/request.dart#Request';
  }

  static bool isApplication(Element? element) {
    return urlOfElement(element) == 'package:astra/src/core/application.dart#Application';
  }

  static bool isHandler(DartType function) {
    if (function is! FunctionType) {
      return false;
    }

    var returnType = function.returnType;

    if (isFuture(returnType.element2) || isFutureOr(returnType.element2)) {
      var interface = returnType as InterfaceType;
      returnType = interface.typeArguments.first;
    }

    if (isResponse(returnType.element2)) {
      var parameters = function.parameters;

      if (parameters.length == 1) {
        var parameter = parameters.first;

        if (isRequest(parameter.type.element2)) {
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
        if (element is FunctionElement && element is! ConstructorElement) {
          var type = element.type;

          if (isHandler(type)) {
            return TargetType.handlerFunction;
          }

          var returnType = type.returnType;
          var isAsync = false;

          if (isFuture(returnType.element2) || isFutureOr(returnType.element2)) {
            var interface = returnType as InterfaceType;
            returnType = interface.typeArguments.first;
            isAsync = true;
          }

          if (isHandler(returnType)) {
            return isAsync ? TargetType.handlerFactoryAsync : TargetType.handlerFactory;
          }

          if (isApplication(returnType.element2)) {
            return isAsync ? TargetType.applicationFactoryAsync : TargetType.applicationFactory;
          }

          throw CliException('target executable is not supported');
        }

        if (element is ConstructorElement) {
          throw UnimplementedError();
        }

        if (element is ClassElement) {
          for (var supertype in element.allSupertypes) {
            if (isApplication(supertype.element2)) {
              return TargetType.applicationType;
            }
          }

          var call = element.getMethod('call');

          if (call != null && isHandler(call.type)) {
            return TargetType.handlerType;
          }

          throw CliException('target type is not extends Application');
        }

        if (element is PropertyAccessorElement) {
          var variable = element.variable;
          var type = variable.type;

          if (isApplication(type.element2)) {
            return TargetType.applicationInstance;
          }

          if (isHandler(type)) {
            return TargetType.applicationInstance;
          }

          if (type is InterfaceType) {
            for (var supertype in type.allSupertypes) {
              if (isApplication(supertype.element2)) {
                return TargetType.applicationInstance;
              }
            }
          }

          throw CliException('target instance type is not extends Application');
        }

        throw CliException('$target ${element.displayName} unsupported');
      }
    }

    throw CliException('$target not found');
  }
}
