// import 'package:ansicolor/ansicolor.dart';
// import 'package:flutter/widgets.dart';
//
// /// Function type for transforming an instance into a display name.
// ///
// /// Return a non-null string to use that as the class name,
// /// or null to try the next transformer.
// typedef ClassNameTransformer = String? Function(Object instance);
//
// /// Registry of class name transformers.
// ///
// /// Transformers are applied in order until one returns a non-null value.
// /// Register custom transformers using [registerClassNameTransformer].
// final List<ClassNameTransformer> _classNameTransformers = [];
//
// /// Register a custom class name transformer.
// ///
// /// Transformers are applied in registration order. The first transformer
// /// that returns a non-null value will be used. If all transformers return
// /// null, the instance's runtimeType will be used.
// void registerClassNameTransformer(ClassNameTransformer transformer) {
//   _classNameTransformers.add(transformer);
// }
//
// /// Initialize default transformers.
// void _initializeDefaultTransformers() {
//   if (_classNameTransformers.isNotEmpty) return;
//
//   // State → Widget transformer
//   registerClassNameTransformer((instance) {
//     if (instance is State) {
//       // ignore: no_runtimetype_tostring
//       final widgetName = instance.widget.runtimeType;
//       final instanceType = instance.runtimeType;
//       if ('$instanceType' == '_${widgetName}State') {
//         return '$widgetName';
//       }
//       return '$instanceType';
//     }
//     return null;
//   });
//
//   // StatelessElement transformer
//   registerClassNameTransformer((instance) {
//     if (instance is BuildContext) {
//       if (instance is StatelessElement) {
//         final widgetName = instance.widget.runtimeType;
//         return '$widgetName\$Element';
//       }
//     }
//     return null;
//   });
// }
//
// /// Get the display name for an instance by applying transformers.
// String _getClassName(Object instance) {
//   _initializeDefaultTransformers();
//
//   // Try each transformer in order
//   for (final transformer in _classNameTransformers) {
//     final result = transformer(instance);
//     if (result != null) return result;
//   }
//
//   // Fallback to runtimeType
//   // ignore: no_runtimetype_tostring
//   return instance.runtimeType.toString();
// }
//
// /// Extension for logging from any object with class context
// extension ChirpObjectExt<T extends Object> on T {
//   void chirpError(Object? message, [Object? e, StackTrace? stack]) {
//     chirp(message, e, stack);
//   }
//
//   void chirp(Object? message, [Object? e, StackTrace? stack]) {
//     ansiColorDisabled = false;
//
//     final clazz = _getClassName(this);
//     final instanceHash = identityHashCode(this);
//
//     // Always include instance hash for clarity
//     final hashHex = instanceHash.toRadixString(16).padLeft(4, '0');
//     final shortHash = hashHex.substring(hashHex.length - 4);
//     final classLabel = '$clazz:$shortHash';
//
//     // Generate readable color using HSL
//     final double hue;
//     const saturation = 0.7;
//     const lightness = 0.6;
//
//     if (e != null) {
//       // Use red color for errors/exceptions
//       hue = 0.0; // Red
//     } else {
//       // Hue varies by class name, avoiding red shades (reserved for errors)
//       // Hue range: 60° to 300° (yellow → green → cyan → blue → magenta, skipping red)
//       final hash = classLabel.hashCode;
//       const minHue = 60.0;
//       const maxHue = 300.0;
//       final hueRange = maxHue - minHue;
//       final hueDegrees = minHue + (hash.abs() % hueRange.toInt());
//       hue = hueDegrees / 360.0;
//     }
//
//     final rgb = _hslToRgb(hue, saturation, lightness);
//     final pen = AnsiPen()..rgb(r: rgb.$1, g: rgb.$2, b: rgb.$3);
//
//     // Format timestamp
//     final now = DateTime.now();
//     final hour = now.hour.toString().padLeft(2, '0');
//     final minute = now.minute.toString().padLeft(2, '0');
//     final second = now.second.toString().padLeft(2, '0');
//     final ms = now.millisecond.toString().padLeft(3, '0');
//     final formattedTime = '$hour:$minute:$second.$ms';
//
//     // Build meta line with padding
//     const metaWidth = 60;
//     final justText = '$formattedTime $classLabel';
//     final remaining = metaWidth - justText.length;
//     final meta = '$formattedTime ${"".padRight(remaining, '=')} $classLabel';
//
//     // Split message into lines
//     final messageStr = message.toString();
//     final messageLines = messageStr.split('\n');
//
//     // Build exception/stack trace lines
//     final buffer = StringBuffer();
//     if (e != null) {
//       buffer.write('\n$e');
//     }
//     if (stack != null) {
//       buffer.write('\n$stack');
//     }
//     final extraLines = buffer.toString();
//
//     // Format output with color
//     final coloredExtraLines = extraLines.isNotEmpty ? extraLines.split('\n').map((line) => pen(line)).join('\n') : '';
//
//     // Build final output
//     final output = StringBuffer();
//     if (messageLines.length <= 1) {
//       output.write(pen('$meta │ $messageStr'));
//       if (coloredExtraLines.isNotEmpty) {
//         output.write(coloredExtraLines);
//       }
//     } else {
//       output.write(pen(meta));
//       output.write(' │ \n');
//       output.write(messageLines.map((line) => pen(line)).join('\n'));
//       if (coloredExtraLines.isNotEmpty) {
//         output.write(coloredExtraLines);
//       }
//     }
//
//     // Print to console with single call
//     // ignore: avoid_print
//     print(output);
//   }
// }
//
// /// Converts HSL color to RGB.
// ///
// /// All values are in range 0.0 to 1.0.
// /// Returns (r, g, b) tuple.
// (double, double, double) _hslToRgb(double h, double s, double l) {
//   if (s == 0.0) {
//     // Achromatic (gray)
//     return (l, l, l);
//   }
//
//   double hue2rgb(double p, double q, double t) {
//     var t2 = t;
//     if (t2 < 0) t2 += 1;
//     if (t2 > 1) t2 -= 1;
//     if (t2 < 1 / 6) return p + (q - p) * 6 * t2;
//     if (t2 < 1 / 2) return q;
//     if (t2 < 2 / 3) return p + (q - p) * (2 / 3 - t2) * 6;
//     return p;
//   }
//
//   final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
//   final p = 2 * l - q;
//
//   final r = hue2rgb(p, q, h + 1 / 3);
//   final g = hue2rgb(p, q, h);
//   final b = hue2rgb(p, q, h - 1 / 3);
//
//   return (r, g, b);
// }
