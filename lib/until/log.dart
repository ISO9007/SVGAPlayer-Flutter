import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

void kkPrint(String? message, {int? wrapWidth}) {
  if (kReleaseMode) return;
  debugPrint(message, wrapWidth: wrapWidth);
}