import 'map_loader_stub.dart'
    if (dart.library.html) 'map_loader_web.dart' as loader;

void initGoogleMaps() {
  loader.loadGoogleMapsScript();
}

bool hasGoogleMapsApiKey() {
  return loader.hasGoogleMapsApiKey();
}

bool isGoogleMapsInitialized() {
  return loader.isGoogleMapsInitialized();
}
