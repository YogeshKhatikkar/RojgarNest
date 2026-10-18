// lib/core/utils/js_stub.dart
// ✅ SAFE FOR ANDROID / iOS / DESKTOP
// This file NO LONGER imports dart:js or dart:js_util
// (both were removed from modern Dart SDK).

/// Safe JS-object wrapper — only a stub on native platforms.
class JsObjectStub {
  final dynamic _obj;
  JsObjectStub(this._obj);

  dynamic operator [](String key) => _obj?[key];

  void operator []=(String key, dynamic value) {
    if (_obj != null) _obj[key] = value;
  }

  dynamic callMethod(String methodName, [List<dynamic>? args]) {
    if (_obj == null) return null;
    final method = _obj[methodName];
    if (method is Function) {
      return Function.apply(method, args ?? []);
    }
    return null;
  }
}

/// Always null on native.
dynamic getWindow() => null;

/// Returns callback unchanged on native.
dynamic allowInterop(dynamic callback) => callback;

/// Type aliases so legacy code keeps compiling.
typedef JsObject = dynamic;
typedef JsFunction = dynamic;
typedef JsArray = dynamic;
typedef JsNumber = dynamic;
typedef JsArrayBuffer = dynamic;
typedef JSAny = dynamic;