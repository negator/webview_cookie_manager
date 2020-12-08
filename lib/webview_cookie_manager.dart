import 'dart:async';
import 'package:flutter/services.dart';
import 'package:webview_cookie_manager/cookie.dart';
export 'package:webview_cookie_manager/cookie.dart';

class WebviewCookieManager {
  static const _channel = MethodChannel('webview_cookie_manager');

  /// Creates a [CookieManager] -- returns the instance if it's already been called.
  factory WebviewCookieManager() {
    return _instance ??= WebviewCookieManager._();
  }

  WebviewCookieManager._();

  static WebviewCookieManager _instance;

  /// Gets whether there are stored cookies
  Future<bool> hasCookies() {
    return _channel
        .invokeMethod<bool>('hasCookies')
        .then<bool>((bool result) => result);
  }

  /// Read out all cookies, or all cookies for a [url] when provided
  Future<List<Cookie>> getCookies(String url) {
    return _channel.invokeListMethod<Map>('getCookies', {
      'url': url
    }).then((results) => results.map((Map result) {
          final c =
              Cookie(result['name'], removeInvalidCharacter(result['value']), result['domain'] )
                // following values optionally work on iOS only
                ..path = result['path']                
                ..secure = result['secure']
                ..maxAge = result['maxAge']
                ..httpOnly = result['httpOnly'];

          if (result['expires'] != null) {
            c.expires = DateTime.fromMillisecondsSinceEpoch(
                (result['expires'] * 1000).toInt());
          }

          return c;
        }).toList());
  }

  /// Remove cookies with [currentUrl] for IOS and Android
  Future<void> removeCookie(String currentUrl) async {
    final listCookies = await getCookies(currentUrl);
    final serializedCookies = listCookies
        .where((element) => currentUrl.contains(element.domain))
        .toList();
    serializedCookies
        .forEach((c) => c.expires = DateTime.fromMicrosecondsSinceEpoch(0));
    await setCookies(serializedCookies);
  }

  /// Remove all cookies
  Future<void> clearCookies() {
    return _channel.invokeMethod<void>('clearCookies');
  }

  /// Set [cookies] into the web view
  Future<void> setCookies(List<Cookie> cookies) {
    final transferCookies = cookies.map((Cookie c) {
      final output = <String, dynamic>{
        'name': c.name,
        'value': c.value,
        'path': c.path,
        'domain': c.domain,
        'secure': c.secure,
        'httpOnly': c.httpOnly,
        'maxAge': c.maxAge,
        'asString': c.toString(),
      };

      if (c.expires != null) {
        output['expires'] = c.expires.millisecondsSinceEpoch ~/ 1000;
      }

      return output;
    }).toList();
    return _channel.invokeMethod<void>('setCookies', transferCookies);
  }

  String removeInvalidCharacter(String value) {
    // Remove Invalid Character
    var valueModified = value.replaceAll('\\"', "'");
    valueModified = valueModified.replaceAll(String.fromCharCode(32), "");
    return valueModified;
  }
}
