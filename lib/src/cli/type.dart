import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

enum TargetType {
  handler,
}

String? urlOfElement(Element? element) {
  if (element == null) {
    return null;
  }

  print('urlOfElement: $element');

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

// TODO: update errors
TargetType getTargetType(String target, LibraryElement library) {
  for (var element in library.topLevelElements) {
    // if (declatation is TopLevelVariableDeclaration) {
    //   if (declatation.variables.isLate) {
    //     // TODO: update error
    //     throw Exception('aplication instance must be initialized.');
    //   }

    //   for (var variable in declatation.variables.variables) {
    //     if (variable.name.name == target) {
    //       // TODO: check target type
    //       return TargetType.instance;
    //     }
    //   }
    // }

    // if (element is ClassElement && element.name == target) {
    //   // TODO: check if target is Controller or Application
    //   return TargetType.type;
    // }

    if (element is FunctionElement && element.name == target) {
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
  }

  throw Exception('$target not found');
}
