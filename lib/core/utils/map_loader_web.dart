// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, avoid_print
import 'dart:html' as html;
import 'dart:js' as js;

void loadGoogleMapsScript() {
  const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  if (apiKey.isEmpty) {
    print("Warning: GOOGLE_MAPS_API_KEY is not defined");
    return;
  }

  // Check if google maps script is already loaded
  if (html.document.getElementById('google-maps-js-sdk') != null) {
    return;
  }

  final script = html.ScriptElement()
    ..id = 'google-maps-js-sdk'
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..async = true
    ..defer = true;

  html.document.head?.append(script);
}

bool hasGoogleMapsApiKey() {
  return const String.fromEnvironment('GOOGLE_MAPS_API_KEY').isNotEmpty;
}

bool isGoogleMapsInitialized() {
  if (js.context.hasProperty('google')) {
    final google = js.context['google'];
    if (google != null && js.JsObject.fromBrowserObject(google).hasProperty('maps')) {
      return true;
    }
  }
  return false;
}
