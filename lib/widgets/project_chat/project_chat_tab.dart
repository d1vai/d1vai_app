import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/message.dart';
import '../../models/model_config.dart';
import '../../models/outbox.dart';
import '../../l10n/app_localizations.dart';
import '../../services/chat_service.dart';
import '../../services/d1vai_service.dart';
import '../../services/model_config_service.dart';
import '../../services/storage_service.dart';
import '../../services/workspace_service.dart';
import '../../utils/billing_errors.dart';
import '../../utils/message_parser.dart';
import '../../utils/preview_url.dart';
import '../chat/chat_bottom_sheet.dart';
import '../chat/floating_chat_button.dart';
import '../chat/message_list.dart';
import '../chat/quick_actions.dart';
import '../insufficient_balance_dialog.dart';
import '../chat/project_chat/no_preview_available_view.dart';
import '../chat/project_chat/chat_engine_mode.dart';
import '../chat/project_chat/project_chat_code_tab.dart';
import '../chat/project_chat/project_chat_preview_header.dart';
import '../chat/project_chat/project_chat_top_bar.dart';
import '../chat/project_chat/project_chat_web_view.dart';
import '../progress_widget.dart';
import '../snackbar_helper.dart';

part '../chat/project_chat/project_chat_tab_logic.dart';
part '../chat/project_chat/project_chat_tab_state_base.dart';
part '../chat/project_chat/project_chat_tab_ui.dart';

/// 项目详情页 - Chat Tab
class ProjectChatTab extends StatefulWidget {
  final String projectId;
  final String? previewUrl;

  const ProjectChatTab({
    super.key,
    required this.projectId,
    required this.previewUrl,
  });

  @override
  ProjectChatTabState createState() => ProjectChatTabState();
}

class ProjectChatTabState extends _ProjectChatTabStateBase
    with _ProjectChatTabLogic, _ProjectChatTabUI {}
