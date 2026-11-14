import 'dart:io';

import 'package:material_ui/material_ui.dart';

Widget localFileImage(String path, {required Widget fallback, BoxFit fit = BoxFit.cover}) => Image.file(
      File(path),
      fit: fit,
      gaplessPlayback: true,
      cacheWidth: 512,
      errorBuilder: (_, _, _) => fallback,
    );
