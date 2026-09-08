/// Terminal interaction and styled logging backed by Chirp.
// ignore_for_file: experimental_member_use
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';

export 'package:chirp/chirp.dart';
export 'package:chirp/chirp_spans.dart';

part 'src/backend.dart';
part 'src/keys.dart';
part 'src/formatter.dart';
part 'src/progress.dart';
part 'src/prompts.dart';
part 'src/terminal.dart';
part 'src/text.dart';
