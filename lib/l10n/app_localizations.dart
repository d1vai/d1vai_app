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
      // Auth
      'login': 'Login',
      'logout': 'Logout',
      'email': 'Email',
      'password': 'Password',
      'verify_code': 'Verification Code',
      'send_code': 'Send Code',
      'login_with_password': 'Login with Password',
      'login_with_code': 'Login with Code',
      
      // Navigation
      'dashboard': 'Dashboard',
      'community': 'Community',
      'docs': 'Docs',
      'settings': 'Settings',
      'profile': 'Profile',
      'pricing': 'Pricing',
      
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
      // Auth
      'login': '登录',
      'logout': '退出登录',
      'email': '邮箱',
      'password': '密码',
      'verify_code': '验证码',
      'send_code': '发送验证码',
      'login_with_password': '密码登录',
      'login_with_code': '验证码登录',
      
      // Navigation
      'dashboard': '仪表板',
      'community': '社区',
      'docs': '文档',
      'settings': '设置',
      'profile': '个人资料',
      'pricing': '定价',
      
      // Dashboard
      'welcome': '欢迎',
      'recent_projects': '最近项目',
      'activity': '活动',
      'create_project': '创建项目',
      
      // Community
      'no_posts_yet': '暂无帖子',
      'be_first_to_share': '成为第一个分享的人！',
      'failed_to_load_posts': '加载帖子失败',
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
    'es': {
      // Auth
      'login': 'Iniciar sesión',
      'logout': 'Cerrar sesión',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'verify_code': 'Código de verificación',
      'send_code': 'Enviar código',
      'login_with_password': 'Iniciar sesión con contraseña',
      'login_with_code': 'Iniciar sesión con código',
      
      // Navigation
      'dashboard': 'Panel',
      'community': 'Comunidad',
      'docs': 'Documentos',
      'settings': 'Configuración',
      'profile': 'Perfil',
      'pricing': 'Precios',
      
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
      // Auth
      'login': 'تسجيل الدخول',
      'logout': 'تسجيل الخروج',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'verify_code': 'رمز التحقق',
      'send_code': 'إرسال الرمز',
      'login_with_password': 'تسجيل الدخول بكلمة المرور',
      'login_with_code': 'تسجيل الدخول بالرمز',
      
      // Navigation
      'dashboard': 'لوحة التحكم',
      'community': 'المجتمع',
      'docs': 'المستندات',
      'settings': 'الإعدادات',
      'profile': 'الملف الشخصي',
      'pricing': 'التسعير',
      
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
    'fr': {
      // Auth
      'login': 'Se connecter',
      'logout': 'Se déconnecter',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'verify_code': 'Code de vérification',
      'send_code': 'Envoyer le code',
      'login_with_password': 'Se connecter avec mot de passe',
      'login_with_code': 'Se connecter avec code',
      
      // Navigation
      'dashboard': 'Tableau de bord',
      'community': 'Communauté',
      'docs': 'Documents',
      'settings': 'Paramètres',
      'profile': 'Profil',
      'pricing': 'Tarification',
      
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
      // Auth
      'login': 'Войти',
      'logout': 'Выйти',
      'email': 'Электронная почта',
      'password': 'Пароль',
      'verify_code': 'Код подтверждения',
      'send_code': 'Отправить код',
      'login_with_password': 'Войти с паролем',
      'login_with_code': 'Войти с кодом',
      
      // Navigation
      'dashboard': 'Панель управления',
      'community': 'Сообщество',
      'docs': 'Документы',
      'settings': 'Настройки',
      'profile': 'Профиль',
      'pricing': 'Цены',
      
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

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'es', 'ar', 'fr', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
