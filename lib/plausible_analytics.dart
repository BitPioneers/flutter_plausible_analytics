library plausible_analytics;

import 'package:universal_io/io.dart'; // instead of 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';

/// Plausible class. Use the constructor to set the parameters.
class Plausible {
  /// The url of your plausible server e.g. https://plausible.io
  String serverUrl;
  String userAgent;
  String domain;
  String screenWidth;
  bool enabled = true;

  /// Constructor
  Plausible(this.serverUrl, this.domain,
      {this.userAgent = "", this.screenWidth = ""});

  /// Generates a User Agent for the current device and saves it in the userAgent Attribute
  Future<void> generateUserAgentString() async {
    String version = "";
    //increasing the number of unique data points in the User-Agent string gives plausible a better chance of identifying unique users
    // as the uniqueness gets determined by the hash of the user agent and ip address (https://plausible.io/data-policy)
    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      var release = androidInfo.version.release;
      version = "Android $release; ${androidInfo.fingerprint};";
    } else if (Platform.isIOS) {
      var iosInfo = await DeviceInfoPlugin().iosInfo;
      var systemName = iosInfo.systemName;
      var version = iosInfo.systemVersion;
      version = "$systemName $version; ${iosInfo.identifierForVendor};";
    }
    version += Platform.operatingSystemVersion.replaceAll('"', '');
    userAgent = "Mozilla/5.0 ($version; rv:53.0) Gecko/20100101 Chrome/53.0";
  }

  /// Post event to plausible
  Future<int> event(
      {String name = "pageview",
      String referrer = "",
      String page = "",
      Map<String, String> props = const {}}) async {
    if (!enabled) {
      return 0;
    }

    // Post-edit parameters
    int lastCharIndex = serverUrl.length - 1;
    if (serverUrl.toString()[lastCharIndex] == '/') {
      // Remove trailing slash '/'
      serverUrl = serverUrl.substring(0, lastCharIndex);
    }
    page = "app://localhost/" + page;
    referrer = "app://localhost/" + referrer;

    if (userAgent == "") {
      await generateUserAgentString();
    }

    // Http Post request see https://plausible.io/docs/events-api
    try {
      HttpClient client = HttpClient();
      HttpClientRequest request =
          await client.postUrl(Uri.parse(serverUrl + '/api/event'));
      request.headers.set('User-Agent', userAgent);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      // When omitting this header plausible will automatically determine the ip address and corresponding location
      //request.headers.set('X-Forwarded-For', '127.0.0.1');

      Object body = {
        "domain": domain,
        "name": name,
        "url": page,
        "referrer": referrer,
        "screen_width": screenWidth,
        "props": props,
      };
      request.write(json.encode(body));
      final HttpClientResponse response = await request.close();
      client.close();
      return response.statusCode;
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }

    return 1;
  }
}
