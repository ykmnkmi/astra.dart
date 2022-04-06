import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

enum TargetType {
  handler,
  application,
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

bool isExtendsApplication(Element? element) {
  if (element == null || element is! VariableElement) {
    return false;
  }

  var type = element.type;

  if (type is! InterfaceType) {
    return false;
  }

  for (var supertypes in type.allSupertypes) {
    if (isApplication(supertypes.element)) {
      return true;
    }
  }

  return false;
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
        if (isExtendsApplication(element.variable)) {
          return TargetType.application;
        }

        throw Exception('target is not extends Application');
      }
    }

    // if (element is ClassElement && element.name == target) {
    //   // TODO: check if target is Controller or Application
    //   return TargetType.type;
    // }
  }

  throw Exception('$target not found');
}
