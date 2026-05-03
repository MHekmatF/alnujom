// ignore_for_file: unused_import, unused_local_variable, uri_does_not_exist

import 'package:flutter/material.dart';
import 'package:alnujom/archive/luxury/foo.dart'; // L6

void violations() {
  const rawColor = Color(0xFFAA0000); // L1
  const inlineStyle = TextStyle(color: rawColor); // L2
  const rawPadding = EdgeInsetsDirectional.all(16); // L3
  final rawRadius = BorderRadius.circular(12); // L4
  const rawShadow = BoxShadow(blurRadius: 8); // L5
  final archivedFont = 'Playfair Display'; // L6
  final archivedArabicFont = 'Reem Kufi'; // L6
}
