import 'package:flutter/material.dart';

import '../shared/chat.dart';

/// Port of `LandlordMessages.swift`.
class LandlordMessages extends StatelessWidget {
  const LandlordMessages({super.key});

  @override
  Widget build(BuildContext context) =>
      const ConversationListScreen(isLandlord: true);
}
