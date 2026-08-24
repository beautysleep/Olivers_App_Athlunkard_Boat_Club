import 'package:flutter/material.dart';

import '../models/session.dart';

class ConditionStyle {
  const ConditionStyle(this.color, this.label, this.shortLabel);
  final Color color;
  final String label;
  final String shortLabel;
}

ConditionStyle conditionStyle(Conditions c) => switch (c) {
  Conditions.green => const ConditionStyle(
    Color(0xFF2E7D32),
    'Good — any boat can go',
    'Good',
  ),
  Conditions.amber => const ConditionStyle(
    Color(0xFFEF6C00),
    'Marginal — larger boats only',
    'Marginal',
  ),
  Conditions.red => const ConditionStyle(
    Color(0xFFC62828),
    'Not rowable',
    'No row',
  ),
};
