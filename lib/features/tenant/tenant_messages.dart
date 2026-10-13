import 'package:flutter/material.dart';

import '../shared/chat.dart';

/// Port of `TenantMessages.swift`.
class TenantMessages extends StatelessWidget {
  const TenantMessages({super.key});

  @override
  Widget build(BuildContext context) =>
      const ConversationListScreen(isLandlord: false);
}
