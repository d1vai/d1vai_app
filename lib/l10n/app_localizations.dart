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
