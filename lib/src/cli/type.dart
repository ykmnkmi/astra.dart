import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

enum TargetType {
  handler,
  application,
  type,
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

// TODO: update errors
TargetType getTargetType(String target, LibraryElement library) {
  for (var element in library.topLevelElements) {
    if (element.name == target) {
      if (element is FunctionElement) {
        var type = element.type;
        var returnType = type.returnType;

        if (isFuture(returnType.element) || isFutureOr(returnType.element)) {
          var interface = returnType as InterfaceType;
          returnType = interface.typeArguments.first;
        }

        if (isResponse(returnType.element)) {
          var parameters = type.parameters;

          if (parameters.length == 1) {
            var parameter = parameters.first;

            if (isRequest(parameter.type.element)) {
              return TargetType.handler;
            }

            throw Exception('target parameter is not Request');
          }

          throw Exception('target parameters count not equal 1');
        }

        throw Exception('target return type is not Response/FutureOr<Response>/Future<Response>');
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

        throw Exception('target instance type is not extends Application');
      }

      if (element is ClassElement) {
        for (var supertype in element.allSupertypes) {
          if (isApplication(supertype.element)) {
            return TargetType.type;
          }
        }

        throw Exception('target type is not extends Application');
      }

      throw Exception('$target ${element.runtimeType} unsupported');
    }

    // if (element is ClassElement && element.name == target) {
    //   // TODO: check if target is Controller or Application
    //   return TargetType.type;
    // }
  }

  throw Exception('$target not found');
}
