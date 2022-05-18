import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:astra/src/cli/command.dart';

enum TargetType {
  handler,
  handlerFactory,
  handlerFactoryAsync,
  type,
  typeFactory,
  typeFactoryAsync,
  application,
}

extension TargetTypeExtension on TargetType {
  bool get isApplication {
    return this == TargetType.type ||
        this == TargetType.typeFactory ||
        this == TargetType.typeFactoryAsync;
  }
}

String? urlOfElement(Element? element) {
  if (element == null) {
    return null;
  }

  if (element.kind == ElementKind.DYNAMIC) {
    return 'dart:core#dynamic';
  }

  return element.librarySource!.uri.replace(fragment: element.name).toString();
}

bool isFuture(Element? element) {
  return urlOfElement(element) == 'dart:async#Future';
}

bool isFutureOr(Element? element) {
  return urlOfElement(element) == 'dart:async#FutureOr';
}

bool isResponse(Element? element) {
  return urlOfElement(element) == 'package:shelf/src/response.dart#Response';
}

bool isRequest(Element? element) {
  return urlOfElement(element) == 'package:shelf/src/request.dart#Request';
}

bool isApplication(Element? element) {
  return urlOfElement(element) == 'package:astra/src/core/application.dart#Application';
}

bool isHandler(FunctionType function) {
  var returnType = function.returnType;

  if (isFuture(returnType.element) || isFutureOr(returnType.element)) {
    var interface = returnType as InterfaceType;
    returnType = interface.typeArguments.first;
  }

  if (isResponse(returnType.element)) {
    var parameters = function.parameters;

    if (parameters.length == 1) {
      var parameter = parameters.first;

      if (isRequest(parameter.type.element)) {
        return true;
      }

      throw Exception('target parameter is not Request');
    }

    throw Exception('target parameters count not equal 1');
  }

  return false;
}

TargetType getTargetType(String target, ResolvedUnitResult resolvedUnitResult) {
  var library = resolvedUnitResult.libraryElement;

  for (var element in library.topLevelElements) {
    if (element.name == target) {
      if (element is FunctionElement) {
        var type = element.type;
        var returnType = type.returnType;
        var isAsync = false;

        if (isFuture(returnType.element) || isFutureOr(returnType.element)) {
          var interface = returnType as InterfaceType;
          returnType = interface.typeArguments.first;
          isAsync = true;
        }

        if (isHandler(type)) {
          return TargetType.handler;
        }

        if (returnType is FunctionType && isHandler(returnType)) {
          return isAsync ? TargetType.handlerFactoryAsync : TargetType.handlerFactory;
        }

        if (isApplication(returnType.element)) {
          return isAsync ? TargetType.typeFactoryAsync : TargetType.typeFactory;
        }

        throw CliException('target return type is not Response/FutureOr<Response>/Future<Response>');
      }

      if (element is ClassElement) {
        for (var supertype in element.allSupertypes) {
          if (isApplication(supertype.element)) {
            return TargetType.type;
          }
        }

        var call = element.getMethod('call');

        if (call != null && isHandler(call.type)) {
          return TargetType.handlerFactory;
        }

        throw CliException('target type is not extends Application');
      }

      if (element is PropertyAccessorElement) {
        var variable = element.variable;
        var type = variable.type;

        if (isApplication(type.element)) {
          return TargetType.application;
        }

        if (type is InterfaceType) {
          for (var supertype in type.allSupertypes) {
            if (isApplication(supertype.element)) {
              return TargetType.application;
            }
          }
        }

        throw CliException('target instance type is not extends Application or ');
      }

      throw CliException('$target ${element.runtimeType} unsupported');
    }
  }

  throw CliException('$target not found');
}
