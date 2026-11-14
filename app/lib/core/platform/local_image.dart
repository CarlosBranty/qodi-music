import 'package:material_ui/material_ui.dart';

import 'local_image_stub.dart' if (dart.library.io) 'local_image_io.dart' as impl;

/// Image from a local file path (native); [fallback] on web or on error.
Widget localFileImage(String path, {required Widget fallback, BoxFit fit = BoxFit.cover}) =>
    impl.localFileImage(path, fallback: fallback, fit: fit);
