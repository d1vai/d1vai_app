import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Auth - Basic
      'login': 'Login',
      'logout': 'Logout',
      'email': 'Email',
      'password': 'Password',
      'verify_code': 'Verification Code',
      'send_code': 'Send Code',
      'resend_code': 'Resend Code',
      'login_with_password': 'Login with Password',
      'login_with_code': 'Login with Code',
      'verify_login': 'Verify Login',
      'sending': 'Sending...',
      'verifying': 'Verifying...',
      'resetting': 'Resetting...',

      // Auth - Input fields
      'email_address': 'Email Address',
      'enter_email': 'Enter your email',
      'enter_password': 'Enter password',
      'enter_verify_code': 'Enter verification code',
      'email_required': 'Please enter email address',
      'password_required': 'Please enter password',
      'verify_code_required': 'Please enter verification code',
      'email_invalid': 'Please enter a valid email address',
      'verify_code_complete': 'Please enter complete verification code',
      'new_password': 'New Password',
      'confirm_password': 'Confirm Password',
      'enter_new_password': 'Enter new password',
      're_enter_new_password': 'Re-enter new password',
      'passwords_do_not_match': 'Passwords do not match',
      'password_length_error': 'Password must be at least 6 characters',

      // Auth - Messages
      'login_success': 'Login successful',
      'login_failed': 'Login failed',
      'code_sent_success': 'Verification code sent successfully',
      'code_sent_to': 'Verification code sent to',
      'agree_terms':
          'By logging in, you agree to our Terms of Service and Privacy Policy',
      'email_bound_success': 'Email bound successfully',
      'password_reset_success': 'Password reset successfully',
      'failed_to_verify': 'Failed to verify code',
      'failed_to_reset_password': 'Failed to reset password',
      'failed_to_send_code': 'Failed to send verification code',

      // Auth - Countdown
      'resend_after': 'Resend after',

      // Navigation
      'dashboard': 'Dashboard',
      'community': 'Community',
      'docs': 'Docs',
      'settings': 'Settings',
      'profile': 'Profile',
      'pricing': 'Pricing',
      'github': 'GitHub',
      'invites': 'Invites',

      // Dashboard
      'welcome': 'Welcome',
      'recent_projects': 'Recent Projects',
      'activity': 'Activity',
      'create_project': 'Create Project',

      // Community
      'no_posts_yet': 'No posts yet',
      'be_first_to_share': 'Be the first to share something!',
      'failed_to_load_posts': 'Failed to load posts',
      'retry': 'Retry',
      'just_now': 'Just now',

      // Profile
      'edit_profile': 'Edit Profile',
      'save_changes': 'Save Changes',
      'cancel': 'Cancel',
      'company_name': 'Company Name',
      'company_website': 'Company Website',
      'industry': 'Industry',
      'basic_information': 'Basic Information',
      'wallet_addresses': 'Wallet Addresses',
      'other': 'Other',

      // Settings
      'language': 'Language',
      'appearance': 'Appearance',
      'notifications': 'Notifications',
      'privacy': 'Privacy',
      'about': 'About',
      'contact_support': 'Contact Support',
      'choose_theme': 'Choose Theme',
      'light_mode': 'Light Mode',
      'dark_mode': 'Dark Mode',
      'system_mode': 'System',
      'theme_updated': 'Theme Updated',
      'theme_switched': 'Switched to',
      'about_description': 'An AI-powered app development platform.',
      'bind_email': 'Bind Email',
      'enter_email_for_code':
          'Enter your email address to receive a verification code',
      'enter_code_sent':
          'Enter the 6-digit verification code sent to your email',
      'reset_password': 'Reset Password',
      'enter_code_and_new_password':
          'Enter the verification code and your new password',

      // Common
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'edit': 'Edit',
      'save': 'Save',
      'search': 'Search',
      'filter': 'Filter',
      'sort': 'Sort',
      'refresh': 'Refresh',

      // Profile Tab
      'theme_title': 'Theme',
      'theme_subtitle': 'Light or Dark mode',
      'bind_email_subtitle': 'Bind email to your account',
      'reset_password_subtitle': 'Reset your login password',
      'help_support': 'Help & Support',
      'help_support_subtitle': 'Get help and support',
      'api_settings': 'API',
      'about_title': 'About',
      'about_subtitle': 'App version and info',
      'notifications_subtitle': 'Manage notifications',

      // GitHub Tab
      'github_integration': 'GitHub Integration',
      'github_connect_description':
          'Connect your GitHub account to import repositories',
      'connect_github': 'Connect GitHub',
      'sync_repositories': 'Sync Repositories',
      'sync_subtitle': 'Update your repository list',
      'syncing': 'Syncing',
      'syncing_message': 'Syncing repositories...',
      'sync_success': 'Repositories synced successfully',
      'import_repository': 'Import Repository',
      'import_subtitle': 'Import a public repository',
      'import_dialog_title': 'Import Public Repository',
      'import_dialog_description':
          'Enter the repository information you want to import',
      'owner_label': 'Owner',
      'owner_hint': 'username or organization',
      'repo_label': 'Repository',
      'repo_hint': 'repository-name',
      'project_name_optional': 'Project Name (Optional)',
      'project_name_hint': 'Leave empty to use repository name',
      'importing': 'Importing...',
      'import_action': 'Import',
      'input_error_owner_repo': 'Please enter owner and repository name',
      'import_success': 'Repository imported successfully',
      'import_failed': 'Failed to import repository',
      'sync_failed': 'Failed to sync repositories',

      // Invites Tab
      'invite_friends': 'Invite Friends',
      'invite_description': 'Invite friends to join d1v.ai and get rewards',
      'your_invite_code': 'Your Invite Code',
      'copied': 'Copied',
      'invite_code_copied': 'Invite code copied to clipboard',
      'share_invite_code': 'Share Invite Code',
      'my_invites': 'My Invites',
      'my_invites_subtitle': 'View your invitation history',
      'friends_referred': 'Friends Referred',
      'friends_count': 'friends',
      'login_first': 'Please login first',
      'invite_code_unavailable': 'Invite code not available',
      'share_message_subject': 'Join me on d1v.ai',
      'share_success': 'Invite code shared successfully',
      'share_failed': 'Failed to share',
      'failed_to_load': 'Failed to load',
    },
    'zh': {
      // Auth - Basic
      'login': '登录',
      'logout': '退出登录',
      'email': '邮箱',
      'password': '密码',
      'verify_code': '验证码',
      'send_code': '发送验证码',
      'resend_code': '重新发送验证码',
      'login_with_password': '密码登录',
      'login_with_code': '验证码登录',
      'verify_login': '验证登录',
      'sending': '发送中...',
      'verifying': '验证中...',
      'resetting': '重置中...',

      // Auth - Input fields
      'email_address': '邮箱地址',
      'enter_email': '请输入您的邮箱',
      'enter_password': '请输入密码',
      'enter_verify_code': '请输入验证码',
      'email_required': '请输入邮箱地址',
      'password_required': '请输入密码',
      'verify_code_required': '请输入验证码',
      'email_invalid': '请输入有效的邮箱地址',
      'verify_code_complete': '请输入完整的验证码',
      'new_password': '新密码',
      'confirm_password': '确认密码',
      'enter_new_password': '请输入新密码',
      're_enter_new_password': '请再次输入新密码',
      'passwords_do_not_match': '两次输入的密码不一致',
      'password_length_error': '密码长度至少为6个字符',

      // Auth - Messages
      'login_success': '登录成功',
      'login_failed': '登录失败',
      'code_sent_success': '验证码已发送，请查收邮件',
      'code_sent_to': '验证码已发送至',
      'agree_terms': '登录即表示您同意我们的服务条款和隐私政策',
      'email_bound_success': '邮箱绑定成功',
      'password_reset_success': '密码重置成功',
      'failed_to_verify': '验证失败',
      'failed_to_reset_password': '重置密码失败',
      'failed_to_send_code': '发送验证码失败',

      // Auth - Countdown
      'resend_after': '秒后重发',

      // Navigation
      'dashboard': '工作台',
      'community': '社区',
      'docs': '文档',
      'settings': '设置',
      'profile': '个人中心',
      'pricing': '价格方案',
      'github': 'GitHub',
      'invites': '邀请',

      // Dashboard
      'welcome': '欢迎',
      'recent_projects': '近期项目',
      'activity': '动态',
      'create_project': '新建项目',

      // Community
      'no_posts_yet': '暂无内容',
      'be_first_to_share': '抢先发布第一条动态',
      'failed_to_load_posts': '内容加载失败',
      'retry': '重试',
      'just_now': '刚刚',

      // Profile
      'edit_profile': '编辑资料',
      'save_changes': '保存更改',
      'cancel': '取消',
      'company_name': '公司名称',
      'company_website': '公司网站',
      'industry': '行业',
      'basic_information': '基本信息',
      'wallet_addresses': '钱包地址',
      'other': '其他',

      // Settings
      'language': '语言',
      'appearance': '外观',
      'notifications': '通知',
      'privacy': '隐私',
      'about': '关于',
      'contact_support': '联系支持',
      'choose_theme': '选择主题',
      'light_mode': '浅色模式',
      'dark_mode': '深色模式',
      'system_mode': '跟随系统',
      'theme_updated': '主题已更新',
      'theme_switched': '已切换至',
      'about_description': '一个 AI 驱动的应用开发平台。',
      'bind_email': '绑定邮箱',
      'enter_email_for_code': '输入邮箱地址以接收验证码',
      'enter_code_sent': '输入发送到您邮箱的6位验证码',
      'reset_password': '重置密码',
      'enter_code_and_new_password': '输入验证码和新密码',

      // Common
      'loading': '加载中...',
      'error': '错误',
      'success': '成功',
      'confirm': '确认',
      'delete': '删除',
      'edit': '编辑',
      'save': '保存',
      'search': '搜索',
      'filter': '筛选',
      'sort': '排序',
      'refresh': '刷新',

      // Profile Tab
      'theme_title': '主题',
      'theme_subtitle': '明亮或深色模式',
      'bind_email_subtitle': '绑定邮箱到您的账户',
      'reset_password_subtitle': '重置您的登录密码',
      'help_support': '帮助与支持',
      'help_support_subtitle': '获取帮助与支持',
      'api_settings': 'API',
      'about_title': '关于',
      'about_subtitle': '应用版本和信息',
      'notifications_subtitle': '管理通知',

      // GitHub Tab
      'github_integration': 'GitHub 集成',
      'github_connect_description': '连接您的 GitHub 账户以导入仓库',
      'connect_github': '连接 GitHub',
      'sync_repositories': '同步仓库',
      'sync_subtitle': '更新您的仓库列表',
      'syncing': '同步中',
      'syncing_message': '正在同步仓库...',
      'sync_success': '仓库同步成功',
      'import_repository': '导入仓库',
      'import_subtitle': '导入公共仓库',
      'import_dialog_title': '导入公共仓库',
      'import_dialog_description': '输入您要导入的仓库信息',
      'owner_label': '拥有者',
      'owner_hint': '用户名或组织名',
      'repo_label': '仓库',
      'repo_hint': '仓库名称',
      'project_name_optional': '项目名称 (可选)',
      'project_name_hint': '留空使用仓库名称',
      'importing': '导入中...',
      'import_action': '导入',
      'input_error_owner_repo': '请输入拥有者和仓库名称',
      'import_success': '仓库导入成功',
      'import_failed': '导入仓库失败',
      'sync_failed': '同步仓库失败',

      // Invites Tab
      'invite_friends': '邀请好友',
      'invite_description': '邀请好友加入 d1v.ai 并获得奖励',
      'your_invite_code': '您的邀请码',
      'copied': '已复制',
      'invite_code_copied': '邀请码已复制到剪贴板',
      'share_invite_code': '分享邀请码',
      'my_invites': '我的邀请',
      'my_invites_subtitle': '查看您的邀请历史',
      'friends_referred': '推荐的好友',
      'friends_count': '位好友',
      'login_first': '请先登录',
      'invite_code_unavailable': '邀请码不可用',
      'share_message_subject': '加入 d1v.ai',
      'share_success': '邀请码分享成功',
      'share_failed': '分享失败',
      'failed_to_load': '加载失败',
    },
    'zh_Hant': {
      // Auth - Basic
      'login': '登入',
      'logout': '登出',
      'email': '電子郵件',
      'password': '密碼',
      'verify_code': '驗證碼',
      'send_code': '發送驗證碼',
      'resend_code': '重新發送驗證碼',
      'login_with_password': '使用密碼登入',
      'login_with_code': '使用驗證碼登入',
      'verify_login': '驗證登入',
      'sending': '發送中...',
      'verifying': '驗證中...',
      'resetting': '重置中...',

      // Auth - Input fields
      'email_address': '電子郵件地址',
      'enter_email': '請輸入您的電子郵件',
      'enter_password': '請輸入密碼',
      'enter_verify_code': '請輸入驗證碼',
      'email_required': '請輸入電子郵件地址',
      'password_required': '請輸入密碼',
      'verify_code_required': '請輸入驗證碼',
      'email_invalid': '請輸入有效的電子郵件地址',
      'verify_code_complete': '請輸入完整的驗證碼',
      'new_password': '新密碼',
      'confirm_password': '確認密碼',
      'enter_new_password': '請輸入新密碼',
      're_enter_new_password': '請再次輸入新密碼',
      'passwords_do_not_match': '兩次輸入的密碼不一致',
      'password_length_error': '密碼長度至少為6個字元',

      // Auth - Messages
      'login_success': '登入成功',
      'login_failed': '登入失敗',
      'code_sent_success': '驗證碼已發送，請查收郵件',
      'code_sent_to': '驗證碼已發送至',
      'agree_terms': '登入即表示您同意我們的服務條款和隱私政策',
      'email_bound_success': '電子郵件綁定成功',
      'password_reset_success': '密碼重置成功',
      'failed_to_verify': '驗證失敗',
      'failed_to_reset_password': '重置密碼失敗',
      'failed_to_send_code': '發送驗證碼失敗',

      // Auth - Countdown
      'resend_after': '秒後重發',

      // Navigation
      'dashboard': '工作台',
      'community': '社群',
      'docs': '文件',
      'settings': '設定',
      'profile': '個人中心',
      'pricing': '方案價格',
      'github': 'GitHub',
      'invites': '邀請',

      // Dashboard
      'welcome': '歡迎',
      'recent_projects': '近期專案',
      'activity': '動態',
      'create_project': '建立專案',

      // Community
      'no_posts_yet': '暫無內容',
      'be_first_to_share': '搶先發佈第一則動態',
      'failed_to_load_posts': '內容載入失敗',
      'retry': '重試',
      'just_now': '剛剛',

      // Profile
      'edit_profile': '編輯資料',
      'save_changes': '儲存變更',
      'cancel': '取消',
      'company_name': '公司名稱',
      'company_website': '公司網站',
      'industry': '產業',
      'basic_information': '基本資訊',
      'wallet_addresses': '錢包地址',
      'other': '其他',

      // Settings
      'language': '語言',
      'appearance': '外觀',
      'notifications': '通知',
      'privacy': '隱私',
      'about': '關於',
      'contact_support': '聯絡客服',
      'choose_theme': '選擇主題',
      'light_mode': '淺色模式',
      'dark_mode': '深色模式',
      'system_mode': '跟隨系統',
      'theme_updated': '主題已更新',
      'theme_switched': '已切換至',
      'about_description': '一個 AI 驅動的應用程式開發平台。',
      'bind_email': '綁定電子郵件',
      'enter_email_for_code': '輸入電子郵件地址以接收驗證碼',
      'enter_code_sent': '輸入發送到您電子郵件的6位驗證碼',
      'reset_password': '重置密碼',
      'enter_code_and_new_password': '輸入驗證碼和新密碼',

      // Common
      'loading': '載入中...',
      'error': '錯誤',
      'success': '成功',
      'confirm': '確認',
      'delete': '刪除',
      'edit': '編輯',
      'save': '儲存',
      'search': '搜尋',
      'filter': '篩選',
      'sort': '排序',
      'refresh': '重新整理',

      // Profile Tab
      'theme_title': '主題',
      'theme_subtitle': '明亮或深色模式',
      'bind_email_subtitle': '綁定電子郵件到您的帳戶',
      'reset_password_subtitle': '重置您的登入密碼',
      'help_support': '幫助與支援',
      'help_support_subtitle': '獲取幫助與支援',
      'api_settings': 'API',
      'about_title': '關於',
      'about_subtitle': '應用版本和資訊',
      'notifications_subtitle': '管理通知',

      // GitHub Tab
      'github_integration': 'GitHub 整合',
      'github_connect_description': '連接您的 GitHub 帳戶以匯入儲存庫',
      'connect_github': '連接 GitHub',
      'sync_repositories': '同步儲存庫',
      'sync_subtitle': '更新您的儲存庫列表',
      'syncing': '同步中',
      'syncing_message': '正在同步儲存庫...',
      'sync_success': '儲存庫同步成功',
      'import_repository': '匯入儲存庫',
      'import_subtitle': '匯入公共儲存庫',
      'import_dialog_title': '匯入公共儲存庫',
      'import_dialog_description': '輸入您要匯入的儲存庫資訊',
      'owner_label': '擁有者',
      'owner_hint': '使用者名稱或組織',
      'repo_label': '儲存庫',
      'repo_hint': '儲存庫名稱',
      'project_name_optional': '專案名稱 (可選)',
      'project_name_hint': '留空使用儲存庫名稱',
      'importing': '匯入中...',
      'import_action': '匯入',
      'input_error_owner_repo': '請輸入擁有者和儲存庫名稱',
      'import_success': '儲存庫匯入成功',
      'import_failed': '匯入儲存庫失敗',
      'sync_failed': '同步儲存庫失敗',

      // Invites Tab
      'invite_friends': '邀請好友',
      'invite_description': '邀請好友加入 d1v.ai 並獲得獎勵',
      'your_invite_code': '您的邀請碼',
      'copied': '已複製',
      'invite_code_copied': '邀請碼已複製到剪貼簿',
      'share_invite_code': '分享邀請碼',
      'my_invites': '我的邀請',
      'my_invites_subtitle': '查看您的邀請記錄',
      'friends_referred': '推薦的好友',
      'friends_count': '位好友',
      'login_first': '請先登入',
      'invite_code_unavailable': '邀請碼不可用',
      'share_message_subject': '加入 d1v.ai',
      'share_success': '邀請碼分享成功',
      'share_failed': '分享失敗',
      'failed_to_load': '載入失敗',
    },
    'es': {
      // Auth - Basic
      'login': 'Iniciar sesión',
      'logout': 'Cerrar sesión',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'verify_code': 'Código de verificación',
      'send_code': 'Enviar código',
      'resend_code': 'Reenviar código',
      'login_with_password': 'Iniciar sesión con contraseña',
      'login_with_code': 'Iniciar sesión con código',
      'verify_login': 'Verificar inicio de sesión',
      'sending': 'Enviando...',
      'verifying': 'Verificando...',
      'resetting': 'Restableciendo...',

      // Auth - Input fields
      'email_address': 'Dirección de correo',
      'enter_email': 'Ingrese su correo electrónico',
      'enter_password': 'Ingrese la contraseña',
      'enter_verify_code': 'Ingrese el código de verificación',
      'email_required': 'Por favor ingrese su correo electrónico',
      'password_required': 'Por favor ingrese la contraseña',
      'verify_code_required': 'Por favor ingrese el código de verificación',
      'email_invalid': 'Por favor ingrese un correo electrónico válido',
      'verify_code_complete':
          'Por favor ingrese el código de verificación completo',
      'new_password': 'Nueva contraseña',
      'confirm_password': 'Confirmar contraseña',
      'enter_new_password': 'Ingrese la nueva contraseña',
      're_enter_new_password': 'Reingrese la nueva contraseña',
      'passwords_do_not_match': 'Las contraseñas no coinciden',
      'password_length_error': 'La contraseña debe tener al menos 6 caracteres',

      // Auth - Messages
      'login_success': 'Inicio de sesión exitoso',
      'login_failed': 'Error al iniciar sesión',
      'code_sent_success': 'Código enviado exitosamente',
      'code_sent_to': 'Código enviado a',
      'agree_terms':
          'Al iniciar sesión, acepta nuestros Términos de Servicio y Política de Privacidad',
      'email_bound_success': 'Correo electrónico vinculado exitosamente',
      'password_reset_success': 'Contraseña restablecida exitosamente',
      'failed_to_verify': 'Error al verificar',
      'failed_to_reset_password': 'Error al restablecer contraseña',
      'failed_to_send_code': 'Error al enviar código',

      // Auth - Countdown
      'resend_after': 'Reenviar después de',

      // Navigation
      'dashboard': 'Panel',
      'community': 'Comunidad',
      'docs': 'Documentos',
      'settings': 'Configuración',
      'profile': 'Perfil',
      'pricing': 'Precios',
      'github': 'GitHub',
      'invites': 'Invitaciones',

      // Dashboard
      'welcome': 'Bienvenido',
      'recent_projects': 'Proyectos recientes',
      'activity': 'Actividad',
      'create_project': 'Crear proyecto',

      // Community
      'no_posts_yet': 'Aún no hay publicaciones',
      'be_first_to_share': '¡Sé el primero en compartir algo!',
      'failed_to_load_posts': 'Error al cargar publicaciones',
      'retry': 'Reintentar',
      'just_now': 'Justo ahora',

      // Profile
      'edit_profile': 'Editar perfil',
      'save_changes': 'Guardar cambios',
      'cancel': 'Cancelar',
      'company_name': 'Nombre de la empresa',
      'company_website': 'Sitio web de la empresa',
      'industry': 'Industria',
      'basic_information': 'Información básica',
      'wallet_addresses': 'Direcciones de billetera',
      'other': 'Otro',

      // Settings
      'language': 'Idioma',
      'appearance': 'Apariencia',
      'notifications': 'Notificaciones',
      'privacy': 'Privacidad',
      'about': 'Acerca de',
      'contact_support': 'Contactar soporte',
      'choose_theme': 'Elegir tema',
      'light_mode': 'Modo claro',
      'dark_mode': 'Modo oscuro',
      'system_mode': 'Sistema',
      'theme_updated': 'Tema actualizado',
      'theme_switched': 'Cambiado a',
      'about_description':
          'Una plataforma de desarrollo de aplicaciones impulsada por IA.',
      'bind_email': 'Vincular correo',
      'enter_email_for_code':
          'Ingrese su correo para recibir un código de verificación',
      'enter_code_sent': 'Ingrese el código de 6 dígitos enviado a su correo',
      'reset_password': 'Restablecer contraseña',
      'enter_code_and_new_password': 'Ingrese el código y la nueva contraseña',

      // Common
      'loading': 'Cargando...',
      'error': 'Error',
      'success': 'Éxito',
      'confirm': 'Confirmar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'save': 'Guardar',
      'search': 'Buscar',
      'filter': 'Filtrar',
      'sort': 'Ordenar',
      'refresh': 'Actualizar',

      // Profile Tab
      'theme_title': 'Tema',
      'theme_subtitle': 'Modo claro u oscuro',
      'bind_email_subtitle': 'Vincular correo a su cuenta',
      'reset_password_subtitle': 'Restablecer su contraseña',
      'help_support': 'Ayuda y soporte',
      'help_support_subtitle': 'Obtener ayuda y soporte',
      'api_settings': 'API',
      'about_title': 'Acerca de',
      'about_subtitle': 'Versión e información de la aplicación',
      'notifications_subtitle': 'Administrar notificaciones',

      // GitHub Tab
      'github_integration': 'Integración con GitHub',
      'github_connect_description':
          'Conecte su cuenta de GitHub para importar repositorios',
      'connect_github': 'Conectar GitHub',
      'sync_repositories': 'Sincronizar repositorios',
      'sync_subtitle': 'Actualizar su lista de repositorios',
      'syncing': 'Sincronizando',
      'syncing_message': 'Sincronizando repositorios...',
      'sync_success': 'Repositorios sincronizados exitosamente',
      'import_repository': 'Importar repositorio',
      'import_subtitle': 'Importar un repositorio público',
      'import_dialog_title': 'Importar Repositorio Público',
      'import_dialog_description':
          'Ingrese la información del repositorio que desea importar',
      'owner_label': 'Propietario',
      'owner_hint': 'usuario u organización',
      'repo_label': 'Repositorio',
      'repo_hint': 'nombre-del-repositorio',
      'project_name_optional': 'Nombre del proyecto (Opcional)',
      'project_name_hint': 'Dejar vacío para usar el nombre del repositorio',
      'importing': 'Importando...',
      'import_action': 'Importar',
      'input_error_owner_repo':
          'Por favor ingrese el propietario y el nombre del repositorio',
      'import_success': 'Repositorio importado exitosamente',

      // Invites Tab
      'invite_friends': 'Invitar amigos',
      'invite_description':
          'Invite a amigos a unirse a d1v.ai y obtenga recompensas',
      'your_invite_code': 'Su código de invitación',
      'copied': 'Copiado',
      'invite_code_copied': 'Código de invitación copiado al portapapeles',
      'share_invite_code': 'Compartir código de invitación',
      'my_invites': 'Mis invitaciones',
      'my_invites_subtitle': 'Ver su historial de invitaciones',
      'friends_referred': 'Amigos referidos',
      'friends_count': 'amigos',
      'login_first': 'Por favor inicie sesión primero',
      'invite_code_unavailable': 'Código de invitación no disponible',
      'share_message_subject': 'Únete a mí en d1v.ai',
      'share_success': 'Código de invitación compartido exitosamente',
      'share_failed': 'Error al compartir',
      'failed_to_load': 'Error al cargar',
      'import_failed': 'Error al importar repositorio',
      'sync_failed': 'Error al sincronizar repositorios',
    },
    'ar': {
      // Auth - Basic
      'login': 'تسجيل الدخول',
      'logout': 'تسجيل الخروج',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'verify_code': 'رمز التحقق',
      'send_code': 'إرسال الرمز',
      'resend_code': 'إعادة إرسال الرمز',
      'login_with_password': 'تسجيل الدخول بكلمة المرور',
      'login_with_code': 'تسجيل الدخول بالرمز',
      'verify_login': 'التحقق وتسجيل الدخول',
      'sending': 'جاري الإرسال...',
      'verifying': 'جاري التحقق...',
      'resetting': 'جاري إعادة التعيين...',

      // Auth - Input fields
      'email_address': 'عنوان البريد الإلكتروني',
      'enter_email': 'أدخل بريدك الإلكتروني',
      'enter_password': 'أدخل كلمة المرور',
      'enter_verify_code': 'أدخل رمز التحقق',
      'email_required': 'يرجى إدخال عنوان البريد الإلكتروني',
      'password_required': 'يرجى إدخال كلمة المرور',
      'verify_code_required': 'يرجى إدخال رمز التحقق',
      'email_invalid': 'يرجى إدخال عنوان بريد إلكتروني صالح',
      'verify_code_complete': 'يرجى إدخال رمز التحقق كاملاً',
      'new_password': 'كلمة المرور الجديدة',
      'confirm_password': 'تأكيد كلمة المرور',
      'enter_new_password': 'أدخل كلمة المرور الجديدة',
      're_enter_new_password': 'أعد إدخال كلمة المرور الجديدة',
      'passwords_do_not_match': 'كلمات المرور غير متطابقة',
      'password_length_error': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',

      // Auth - Messages
      'login_success': 'تم تسجيل الدخول بنجاح',
      'login_failed': 'فشل في تسجيل الدخول',
      'code_sent_success': 'تم إرسال الرمز بنجاح',
      'code_sent_to': 'تم الإرسال إلى',
      'agree_terms':
          'بتسجيل الدخول، فإنك توافق على شروط الخدمة وسياسة الخصوصية',
      'email_bound_success': 'تم ربط البريد الإلكتروني بنجاح',
      'password_reset_success': 'تم إعادة تعيين كلمة المرور بنجاح',
      'failed_to_verify': 'فشل التحقق',
      'failed_to_reset_password': 'فشل إعادة تعيين كلمة المرور',
      'failed_to_send_code': 'فشل إرسال الرمز',

      // Auth - Countdown
      'resend_after': 'إعادة الإرسال بعد',

      // Navigation
      'dashboard': 'لوحة التحكم',
      'community': 'المجتمع',
      'docs': 'المستندات',
      'settings': 'الإعدادات',
      'profile': 'الملف الشخصي',
      'pricing': 'التسعير',
      'github': 'GitHub',
      'invites': 'الدعوات',

      // Dashboard
      'welcome': 'مرحباً',
      'recent_projects': 'المشاريع الأخيرة',
      'activity': 'النشاط',
      'create_project': 'إنشاء مشروع',

      // Community
      'no_posts_yet': 'لا توجد منشورات بعد',
      'be_first_to_share': 'كن أول من يشارك شيئاً!',
      'failed_to_load_posts': 'فشل تحميل المنشورات',
      'retry': 'إعادة المحاولة',
      'just_now': 'الآن',

      // Profile
      'edit_profile': 'تعديل الملف الشخصي',
      'save_changes': 'حفظ التغييرات',
      'cancel': 'إلغاء',
      'company_name': 'اسم الشركة',
      'company_website': 'موقع الشركة',
      'industry': 'الصناعة',
      'basic_information': 'المعلومات الأساسية',
      'wallet_addresses': 'عناوين المحفظة',
      'other': 'أخرى',

      // Settings
      'language': 'اللغة',
      'appearance': 'المظهر',
      'notifications': 'الإشعارات',
      'privacy': 'الخصوصية',
      'about': 'حول',
      'contact_support': 'اتصل بالدعم',
      'choose_theme': 'اختر المظهر',
      'light_mode': 'الوضع الفاتح',
      'dark_mode': 'الوضع الداكن',
      'system_mode': 'النظام',
      'theme_updated': 'تم تحديث المظهر',
      'theme_switched': 'تم التبديل إلى',
      'about_description': 'منصة تطوير تطبيقات تعمل بالذكاء الاصطناعي.',
      'bind_email': 'ربط البريد الإلكتروني',
      'enter_email_for_code': 'أدخل بريدك الإلكتروني لاستلام رمز التحقق',
      'enter_code_sent': 'أدخل الرمز المكون من 6 أرقام المرسل إلى بريدك',
      'reset_password': 'إعادة تعيين كلمة المرور',
      'enter_code_and_new_password': 'أدخل الرمز وكلمة المرور الجديدة',

      // Common
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجاح',
      'confirm': 'تأكيد',
      'delete': 'حذف',
      'edit': 'تعديل',
      'save': 'حفظ',
      'search': 'بحث',
      'filter': 'تصفية',
      'sort': 'ترتيب',
      'refresh': 'تحديث',

      // Profile Tab
      'theme_title': 'المظهر',
      'theme_subtitle': 'الوضع الفاتح أو الداكن',
      'bind_email_subtitle': 'ربط البريد الإلكتروني بحسابك',
      'reset_password_subtitle': 'إعادة تعيين كلمة مرور تسجيل الدخول',
      'help_support': 'المساعدة والدعم',
      'help_support_subtitle': 'احصل على المساعدة والدعم',
      'api_settings': 'واجهة برمجة التطبيقات (API)',
      'about_title': 'حول',
      'about_subtitle': 'إصدار التطبيق والمعلومات',
      'notifications_subtitle': 'إدارة الإشعارات',

      // GitHub Tab
      'github_integration': 'تكامل GitHub',
      'github_connect_description':
          'قم بتوصيل حساب GitHub الخاص بك لاستيراد المستودعات',
      'connect_github': 'اتصال GitHub',
      'sync_repositories': 'مزامنة المستودعات',
      'sync_subtitle': 'تحديث قائمة المستودعات الخاصة بك',
      'syncing': 'جاري المزامنة',
      'syncing_message': 'جاري مزامنة المستودعات...',
      'sync_success': 'تمت مزامنة المستودعات بنجاح',
      'import_repository': 'استيراد مستودع',
      'import_subtitle': 'استيراد مستودع عام',
      'import_dialog_title': 'استيراد مستودع عام',
      'import_dialog_description': 'أدخل معلومات المستودع الذي تريد استيراده',
      'owner_label': 'المالك',
      'owner_hint': 'اسم المستخدم أو المنظمة',
      'repo_label': 'المستودع',
      'repo_hint': 'اسم-المستودع',
      'project_name_optional': 'اسم المشروع (اختياري)',
      'project_name_hint': 'اتركه فارغًا لاستخدام اسم المستودع',
      'importing': 'جاري الاستيراد...',
      'import_action': 'استيراد',
      'input_error_owner_repo': 'يرجى إدخال اسم المالك والمستودع',
      'import_success': 'تم استيراد المستودع بنجاح',
      'import_failed': 'فشل استيراد المستودع',
      'sync_failed': 'فشل مزامنة المستودعات',

      // Invites Tab
      'invite_friends': 'دعوة الأصدقاء',
      'invite_description':
          'قم بدعوة الأصدقاء للانضمام إلى d1v.ai واحصل على مكافآت',
      'your_invite_code': 'رمز الدعوة الخاص بك',
      'copied': 'تم النسخ',
      'invite_code_copied': 'تم نسخ رمز الدعوة إلى الحافظة',
      'share_invite_code': 'مشاركة رمز الدعوة',
      'my_invites': 'دعواتي',
      'my_invites_subtitle': 'عرض سجل الدعوات الخاص بك',
      'friends_referred': 'الأصدقاء المدعوون',
      'friends_count': 'أصدقاء',
      'login_first': 'يرجى تسجيل الدخول أولاً',
      'invite_code_unavailable': 'رمز الدعوة غير متاح',
      'share_message_subject': 'انضم إلي في d1v.ai',
      'share_success': 'تم مشاركة رمز الدعوة بنجاح',
      'share_failed': 'فشل المشاركة',
      'failed_to_load': 'فشل التحميل',
    },
    'ja': {
      // Auth - Basic
      'login': 'ログイン',
      'logout': 'ログアウト',
      'email': 'メールアドレス',
      'password': 'パスワード',
      'verify_code': '認証コード',
      'send_code': 'コードを送信',
      'resend_code': 'コードを再送信',
      'login_with_password': 'パスワードでログイン',
      'login_with_code': 'コードでログイン',
      'verify_login': 'ログインを認証',
      'sending': '送信中...',
      'verifying': '認証中...',
      'resetting': 'リセット中...',

      // Auth - Input fields
      'email_address': 'メールアドレス',
      'enter_email': 'メールアドレスを入力してください',
      'enter_password': 'パスワードを入力してください',
      'enter_verify_code': '認証コードを入力してください',
      'email_required': 'メールアドレスを入力してください',
      'password_required': 'パスワードを入力してください',
      'verify_code_required': '認証コードを入力してください',
      'email_invalid': '有効なメールアドレスを入力してください',
      'verify_code_complete': '完全な認証コードを入力してください',
      'new_password': '新しいパスワード',
      'confirm_password': 'パスワードの確認',
      'enter_new_password': '新しいパスワードを入力してください',
      're_enter_new_password': '新しいパスワードを再入力してください',
      'passwords_do_not_match': 'パスワードが一致しません',
      'password_length_error': 'パスワードは6文字以上である必要があります',

      // Auth - Messages
      'login_success': 'ログインしました',
      'login_failed': 'ログインに失敗しました',
      'code_sent_success': 'コードが正常に送信されました',
      'code_sent_to': '送信先:',
      'agree_terms': 'ログインすることで、利用規約とプライバシーに同意したことになります',
      'email_bound_success': 'メールアドレスのバインドに成功しました',
      'password_reset_success': 'パスワードのリセットに成功しました',
      'failed_to_verify': '認証に失敗しました',
      'failed_to_reset_password': 'パスワードのリセットに失敗しました',
      'failed_to_send_code': 'コードの送信に失敗しました',

      // Auth - Countdown
      'resend_after': '再送信まで',

      // Navigation
      'dashboard': 'ダッシュボード',
      'community': 'コミュニティ',
      'docs': 'ドキュメント',
      'settings': '設定',
      'profile': 'プロフィール',
      'pricing': '料金',
      'github': 'GitHub',
      'invites': '招待',

      // Dashboard
      'welcome': 'ようこそ',
      'recent_projects': '最近のプロジェクト',
      'activity': 'アクティビティ',
      'create_project': 'プロジェクトを作成',

      // Community
      'no_posts_yet': 'まだ投稿がありません',
      'be_first_to_share': '最初の投稿者になりましょう！',
      'failed_to_load_posts': '投稿の読み込みに失敗しました',
      'retry': '再試行',
      'just_now': 'たった今',

      // Profile
      'edit_profile': 'プロフィールを編集',
      'save_changes': '変更を保存',
      'cancel': 'キャンセル',
      'company_name': '会社名',
      'company_website': '会社のウェブサイト',
      'industry': '業種',
      'basic_information': '基本情報',
      'wallet_addresses': 'ウォレットアドレス',
      'other': 'その他',

      // Settings
      'language': '言語',
      'appearance': '外観',
      'notifications': '通知',
      'privacy': 'プライバシー',
      'about': 'このアプリについて',
      'contact_support': 'サポートに連絡',
      'choose_theme': 'テーマを選択',
      'light_mode': 'ライトモード',
      'dark_mode': 'ダークモード',
      'system_mode': 'システム',
      'theme_updated': 'テーマが更新されました',
      'theme_switched': '次へ切り替えました:',
      'about_description': 'AIを活用したアプリ開発プラットフォーム。',
      'bind_email': 'メールアドレスをバインド',
      'enter_email_for_code': '認証コードを受け取るメールアドレスを入力してください',
      'enter_code_sent': 'メールに送信された6桁の認証コードを入力してください',
      'reset_password': 'パスワードをリセット',
      'enter_code_and_new_password': '認証コードと新しいパスワードを入力してください',

      // Common
      'loading': '読み込み中...',
      'error': 'エラー',
      'success': '成功',
      'confirm': '確認',
      'delete': '削除',
      'edit': '編集',
      'save': '保存',
      'search': '検索',
      'filter': 'フィルター',
      'sort': '並べ替え',
      'refresh': '更新',

      // Profile Tab
      'theme_title': 'テーマ',
      'theme_subtitle': 'ライトモードまたはダークモード',
      'bind_email_subtitle': 'アカウントにメールアドレスをバインド',
      'reset_password_subtitle': 'ログインパスワードをリセット',
      'help_support': 'ヘルプ＆サポート',
      'help_support_subtitle': 'ヘルプとサポートを受ける',
      'api_settings': 'API',
      'about_title': 'アプリ情報',
      'about_subtitle': 'アプリのバージョンと情報',
      'notifications_subtitle': '通知を管理',

      // GitHub Tab
      'github_integration': 'GitHub 連携',
      'github_connect_description': 'GitHub アカウントを接続してリポジトリをインポート',
      'connect_github': 'GitHub に接続',
      'sync_repositories': 'リポジトリを同期',
      'sync_subtitle': 'リポジトリリストを更新',
      'syncing': '同期中',
      'syncing_message': 'リポジトリを同期中...',
      'sync_success': 'リポジトリが正常に同期されました',
      'import_repository': 'リポジトリをインポート',
      'import_subtitle': '公開リポジトリをインポート',
      'import_dialog_title': '公開リポジトリをインポート',
      'import_dialog_description': 'インポートしたいリポジトリ情報を入力してください',
      'owner_label': 'オーナー',
      'owner_hint': 'ユーザー名または組織名',
      'repo_label': 'リポジトリ',
      'repo_hint': 'リポジトリ名',
      'project_name_optional': 'プロジェクト名 (任意)',
      'project_name_hint': '空欄の場合、リポジトリ名を使用',
      'importing': 'インポート中...',
      'import_action': 'インポート',
      'input_error_owner_repo': 'オーナーとリポジトリ名を入力してください',
      'import_success': 'リポジトリが正常にインポートされました',
      'import_failed': 'リポジトリのインポートに失敗しました',
      'sync_failed': 'リポジトリの同期に失敗しました',

      // Invites Tab
      'invite_friends': '友達を招待',
      'invite_description': '友達を d1v.ai に招待して報酬を獲得',
      'your_invite_code': '招待コード',
      'copied': 'コピーしました',
      'invite_code_copied': '招待コードをクリップボードにコピーしました',
      'share_invite_code': '招待コードをシェア',
      'my_invites': '招待履歴',
      'my_invites_subtitle': '招待履歴を表示',
      'friends_referred': '招待した友達',
      'friends_count': '人の友達',
      'login_first': '先にログインしてください',
      'invite_code_unavailable': '招待コードは利用できません',
      'share_message_subject': 'd1v.ai に参加しよう',
      'share_success': '招待コードが正常にシェアされました',
      'share_failed': 'シェアに失敗しました',
      'failed_to_load': '読み込みに失敗しました',
    },
    'fr': {
      // Auth - Basic
      'login': 'Se connecter',
      'logout': 'Se déconnecter',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'verify_code': 'Code de vérification',
      'send_code': 'Envoyer le code',
      'resend_code': 'Renvoyer le code',
      'login_with_password': 'Se connecter avec mot de passe',
      'login_with_code': 'Se connecter avec code',
      'verify_login': 'Vérifier la connexion',
      'sending': 'Envoi...',
      'verifying': 'Vérification...',
      'resetting': 'Réinitialisation...',

      // Auth - Input fields
      'email_address': 'Adresse e-mail',
      'enter_email': 'Entrez votre e-mail',
      'enter_password': 'Entrez le mot de passe',
      'enter_verify_code': 'Entrez le code de vérification',
      'email_required': 'Veuillez entrer votre adresse e-mail',
      'password_required': 'Veuillez entrer le mot de passe',
      'verify_code_required': 'Veuillez entrer le code de vérification',
      'email_invalid': 'Veuillez entrer une adresse e-mail valide',
      'verify_code_complete': 'Veuillez entrer le code de vérification complet',
      'new_password': 'Nouveau mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'enter_new_password': 'Entrez le nouveau mot de passe',
      're_enter_new_password': 'Entrez à nouveau le nouveau mot de passe',
      'passwords_do_not_match': 'Les mots de passe ne correspondent pas',
      'password_length_error':
          'Le mot de passe doit comporter au moins 6 caractères',

      // Auth - Messages
      'login_success': 'Connexion réussie',
      'login_failed': 'Échec de la connexion',
      'code_sent_success': 'Code envoyé avec succès',
      'code_sent_to': 'Code envoyé à',
      'agree_terms':
          'En vous connectant, vous acceptez nos Conditions de Service et notre Politique de Confidentialité',
      'email_bound_success': 'E-mail lié avec succès',
      'password_reset_success': 'Mot de passe réinitialisé avec succès',
      'failed_to_verify': 'Échec de la vérification',
      'failed_to_reset_password':
          'Échec de la réinitialisation du mot de passe',
      'failed_to_send_code': 'Échec de l\'envoi du code',

      // Auth - Countdown
      'resend_after': 'Renvoyer après',

      // Navigation
      'dashboard': 'Tableau de bord',
      'community': 'Communauté',
      'docs': 'Documents',
      'settings': 'Paramètres',
      'profile': 'Profil',
      'pricing': 'Tarification',
      'github': 'GitHub',
      'invites': 'Invitations',

      // Dashboard
      'welcome': 'Bienvenue',
      'recent_projects': 'Projets récents',
      'activity': 'Activité',
      'create_project': 'Créer un projet',

      // Community
      'no_posts_yet': 'Pas encore de publications',
      'be_first_to_share': 'Soyez le premier à partager quelque chose!',
      'failed_to_load_posts': 'Échec du chargement des publications',
      'retry': 'Réessayer',
      'just_now': 'À l\'instant',

      // Profile
      'edit_profile': 'Modifier le profil',
      'save_changes': 'Enregistrer les modifications',
      'cancel': 'Annuler',
      'company_name': 'Nom de l\'entreprise',
      'company_website': 'Site web de l\'entreprise',
      'industry': 'Industrie',
      'basic_information': 'Informations de base',
      'wallet_addresses': 'Adresses de portefeuille',
      'other': 'Autre',

      // Settings
      'language': 'Langue',
      'appearance': 'Apparence',
      'notifications': 'Notifications',
      'privacy': 'Confidentialité',
      'about': 'À propos',
      'contact_support': 'Contacter le support',
      'choose_theme': 'Choisir le thème',
      'light_mode': 'Mode clair',
      'dark_mode': 'Mode sombre',
      'system_mode': 'Système',
      'theme_updated': 'Thème mis à jour',
      'theme_switched': 'Passé à',
      'about_description':
          'Une plateforme de développement d\'applications alimentée par l\'IA.',
      'bind_email': 'Lier l\'e-mail',
      'enter_email_for_code':
          'Entrez votre adresse e-mail pour recevoir un code de vérification',
      'enter_code_sent':
          'Entrez le code de vérification à 6 chiffres envoyé à votre e-mail',
      'reset_password': 'Réinitialiser le mot de passe',
      'enter_code_and_new_password':
          'Entrez le code de vérification et votre nouveau mot de passe',

      // Common
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'confirm': 'Confirmer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'save': 'Enregistrer',
      'search': 'Rechercher',
      'filter': 'Filtrer',
      'sort': 'Trier',
      'refresh': 'Actualiser',

      // Profile Tab
      'theme_title': 'Thème',
      'theme_subtitle': 'Mode clair ou sombre',
      'bind_email_subtitle': 'Lier l\'e-mail à votre compte',
      'reset_password_subtitle':
          'Réinitialiser votre mot de passe de connexion',
      'help_support': 'Aide et support',
      'help_support_subtitle': 'Obtenir de l\'aide et du support',
      'api_settings': 'API',
      'about_title': 'À propos',
      'about_subtitle': 'Version de l\'application et informations',
      'notifications_subtitle': 'Gérer les notifications',

      // GitHub Tab
      'github_integration': 'Intégration GitHub',
      'github_connect_description':
          'Connectez votre compte GitHub pour importer des référentiels',
      'connect_github': 'Connecter GitHub',
      'sync_repositories': 'Synchroniser les référentiels',
      'sync_subtitle': 'Mettre à jour votre liste de référentiels',
      'syncing': 'Synchronisation',
      'syncing_message': 'Synchronisation des référentiels...',
      'sync_success': 'Référentiels synchronisés avec succès',
      'import_repository': 'Importer un référentiel',
      'import_subtitle': 'Importer un référentiel public',
      'import_dialog_title': 'Importer un référentiel public',
      'import_dialog_description':
          'Entrez les informations du référentiel que vous souhaitez importer',
      'owner_label': 'Propriétaire',
      'owner_hint': 'nom d\'utilisateur ou organisation',
      'repo_label': 'Référentiel',
      'repo_hint': 'nom-du-référentiel',
      'project_name_optional': 'Nom du projet (Facultatif)',
      'project_name_hint': 'Laisser vide pour utiliser le nom du référentiel',
      'importing': 'Importation...',
      'import_action': 'Importer',
      'input_error_owner_repo':
          'Veuillez entrer le propriétaire et le nom du référentiel',
      'import_success': 'Référentiel importé avec succès',

      // Invites Tab
      'invite_friends': 'Inviter des amis',
      'invite_description':
          'Invitez des amis à rejoindre d1v.ai et obtenez des récompenses',
      'your_invite_code': 'Votre code d\'invitation',
      'copied': 'Copié',
      'invite_code_copied': 'Code d\'invitation copié dans le presse-papiers',
      'share_invite_code': 'Partager le code d\'invitation',
      'my_invites': 'Mes invitations',
      'my_invites_subtitle': 'Voir votre historique d\'invitations',
      'friends_referred': 'Amis parrainés',
      'friends_count': 'amis',
      'login_first': 'Veuillez d\'abord vous connecter',
      'invite_code_unavailable': 'Code d\'invitation non disponible',
      'share_message_subject': 'Rejoignez-moi sur d1v.ai',
      'share_success': 'Code d\'invitation partagé avec succès',
      'share_failed': 'Échec du partage',
      'failed_to_load': 'Échec du chargement',
      'import_failed': 'Échec de l\'importation du référentiel',
      'sync_failed': 'Échec de la synchronisation des référentiels',
    },
    'ru': {
      // Auth - Basic
      'login': 'Войти',
      'logout': 'Выйти',
      'email': 'Электронная почта',
      'password': 'Пароль',
      'verify_code': 'Код подтверждения',
      'send_code': 'Отправить код',
      'resend_code': 'Повторить отправку кода',
      'login_with_password': 'Войти с паролем',
      'login_with_code': 'Войти с кодом',
      'verify_login': 'Проверить вход',
      'sending': 'Отправка...',
      'verifying': 'Проверка...',
      'resetting': 'Сброс...',

      // Auth - Input fields
      'email_address': 'Адрес электронной почты',
      'enter_email': 'Введите вашу почту',
      'enter_password': 'Введите пароль',
      'enter_verify_code': 'Введите код подтверждения',
      'email_required': 'Пожалуйста, введите адрес электронной почты',
      'password_required': 'Пожалуйста, введите пароль',
      'verify_code_required': 'Пожалуйста, введите код подтверждения',
      'email_invalid':
          'Пожалуйста, введите действительный адрес электронной почты',
      'verify_code_complete': 'Пожалуйста, введите полный код подтверждения',
      'new_password': 'Новый пароль',
      'confirm_password': 'Подтвердить пароль',
      'enter_new_password': 'Введите новый пароль',
      're_enter_new_password': 'Введите новый пароль еще раз',
      'passwords_do_not_match': 'Пароли не совпадают',
      'password_length_error': 'Пароль должен содержать не менее 6 символов',

      // Auth - Messages
      'login_success': 'Успешный вход',
      'login_failed': 'Ошибка входа',
      'code_sent_success': 'Код успешно отправлен',
      'code_sent_to': 'Код отправлен на',
      'agree_terms':
          'Входя в систему, вы соглашаетесь с нашими Условиями обслуживания и Политикой конфиденциальности',
      'email_bound_success': 'Электронная почта успешно привязана',
      'password_reset_success': 'Пароль успешно сброшен',
      'failed_to_verify': 'Не удалось проверить',
      'failed_to_reset_password': 'Не удалось сбросить пароль',
      'failed_to_send_code': 'Не удалось отправить код',

      // Auth - Countdown
      'resend_after': 'Повторить через',

      // Navigation
      'dashboard': 'Панель управления',
      'community': 'Сообщество',
      'docs': 'Документы',
      'settings': 'Настройки',
      'profile': 'Профиль',
      'pricing': 'Цены',
      'github': 'GitHub',
      'invites': 'Приглашения',

      // Dashboard
      'welcome': 'Добро пожаловать',
      'recent_projects': 'Недавние проекты',
      'activity': 'Активность',
      'create_project': 'Создать проект',

      // Community
      'no_posts_yet': 'Пока нет публикаций',
      'be_first_to_share': 'Будьте первым, кто поделится чем-то!',
      'failed_to_load_posts': 'Не удалось загрузить публикации',
      'retry': 'Повторить',
      'just_now': 'Только что',

      // Profile
      'edit_profile': 'Редактировать профиль',
      'save_changes': 'Сохранить изменения',
      'cancel': 'Отмена',
      'company_name': 'Название компании',
      'company_website': 'Веб-сайт компании',
      'industry': 'Отрасль',
      'basic_information': 'Основная информация',
      'wallet_addresses': 'Адреса кошельков',
      'other': 'Другое',

      // Settings
      'language': 'Язык',
      'appearance': 'Внешний вид',
      'notifications': 'Уведомления',
      'privacy': 'Конфиденциальность',
      'about': 'О программе',
      'contact_support': 'Связаться с поддержкой',
      'choose_theme': 'Выбрать тему',
      'light_mode': 'Светлая тема',
      'dark_mode': 'Темная тема',
      'system_mode': 'Системная',
      'theme_updated': 'Тема обновлена',
      'theme_switched': 'Переключено на',
      'about_description':
          'Платформа для разработки приложений с использованием ИИ.',
      'bind_email': 'Привязать почту',
      'enter_email_for_code':
          'Введите адрес электронной почты для получения кода подтверждения',
      'enter_code_sent':
          'Введите 6-значный код подтверждения, отправленный на вашу почту',
      'reset_password': 'Сбросить пароль',
      'enter_code_and_new_password': 'Введите код подтверждения и новый пароль',

      // Common
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'success': 'Успех',
      'confirm': 'Подтвердить',
      'delete': 'Удалить',
      'edit': 'Редактировать',
      'save': 'Сохранить',
      'search': 'Поиск',
      'filter': 'Фильтр',
      'sort': 'Сортировка',
      'refresh': 'Обновить',

      // Profile Tab
      'theme_title': 'Тема',
      'theme_subtitle': 'Светлый или темный режим',
      'bind_email_subtitle': 'Привязать почту к аккаунту',
      'reset_password_subtitle': 'Сбросить пароль для входа',
      'help_support': 'Помощь и поддержка',
      'help_support_subtitle': 'Получить помощь и поддержку',
      'api_settings': 'API',
      'about_title': 'О приложении',
      'about_subtitle': 'Версия приложения и информация',
      'notifications_subtitle': 'Управление уведомлениями',

      // GitHub Tab
      'github_integration': 'Интеграция с GitHub',
      'github_connect_description':
          'Подключите свой аккаунт GitHub для импорта репозиториев',
      'connect_github': 'Подключить GitHub',
      'sync_repositories': 'Синхронизировать репозитории',
      'sync_subtitle': 'Обновить список репозиториев',
      'syncing': 'Синхронизация',
      'syncing_message': 'Синхронизация репозиториев...',
      'sync_success': 'Репозитории успешно синхронизированы',
      'import_repository': 'Импортировать репозиторий',
      'import_subtitle': 'Импортировать публичный репозиторий',
      'import_dialog_title': 'Импорт публичного репозитория',
      'import_dialog_description':
          'Введите информацию о репозитории, который хотите импортировать',
      'owner_label': 'Владелец',
      'owner_hint': 'пользователь или организация',
      'repo_label': 'Репозиторий',
      'repo_hint': 'название-репозитория',
      'project_name_optional': 'Название проекта (необязательно)',
      'project_name_hint':
          'Оставьте пустым, чтобы использовать название репозитория',
      'importing': 'Импорт...',
      'import_action': 'Импортировать',
      'input_error_owner_repo':
          'Пожалуйста, введите владельца и название репозитория',
      'import_success': 'Репозиторий успешно импортирован',

      // Invites Tab
      'invite_friends': 'Пригласить друзей',
      'invite_description':
          'Приглашайте друзей присоединиться к d1v.ai и получайте награды',
      'your_invite_code': 'Ваш код приглашения',
      'copied': 'Скопировано',
      'invite_code_copied': 'Код приглашения скопирован в буфер обмена',
      'share_invite_code': 'Поделиться кодом',
      'my_invites': 'Мои приглашения',
      'my_invites_subtitle': 'Просмотр истории приглашений',
      'friends_referred': 'Приглашенные друзья',
      'friends_count': 'друзей',
      'login_first': 'Пожалуйста, войдите сначала',
      'invite_code_unavailable': 'Код приглашения недоступен',
      'share_message_subject': 'Присоединяйся ко мне на d1v.ai',
      'share_success': 'Код приглашения успешно отправлен',
      'share_failed': 'Не удалось поделиться',
      'failed_to_load': 'Не удалось загрузить',
      'import_failed': 'Не удалось импортировать репозиторий',
      'sync_failed': 'Не удалось синхронизировать репозитории',
    },
  };

  static String _localeKeyFromLocale(Locale locale) {
    if (locale.languageCode == 'zh') {
      if (locale.scriptCode == 'Hant' ||
          locale.countryCode == 'TW' ||
          locale.countryCode == 'HK' ||
          locale.countryCode == 'MO') {
        return 'zh_Hant';
      }
      return 'zh';
    }

    return locale.languageCode;
  }

  String translate(String key) {
    final localeKey = _localeKeyFromLocale(locale);
    return _localizedValues[localeKey]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final localeKey = AppLocalizations._localeKeyFromLocale(locale);
    return [
      'en',
      'zh',
      'zh_Hant',
      'es',
      'ar',
      'ja',
      'fr',
      'ru',
    ].contains(localeKey);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
