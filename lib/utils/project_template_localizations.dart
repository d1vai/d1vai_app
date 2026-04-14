import 'package:flutter/material.dart';

import '../models/project.dart';

class LocalizedProjectTemplateView {
  final String name;
  final String description;
  final String category;
  final String featuredLabel;

  const LocalizedProjectTemplateView({
    required this.name,
    required this.description,
    required this.category,
    required this.featuredLabel,
  });
}

typedef _LocalizedText = Map<String, String>;

String _localeKeyFromLocale(Locale locale) {
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

String _resolveLocalizedText(
  String base,
  String localeKey,
  _LocalizedText? localized,
) {
  if (localized == null) return base;
  return localized[localeKey] ?? localized['en'] ?? base;
}

const Map<String, _LocalizedText> _categoryLabels = {
  'system': {
    'en': 'Smart',
    'zh': '智能',
    'zh_Hant': '智慧',
    'ja': 'スマート',
    'fr': 'Intelligent',
    'ru': 'Умный',
    'es': 'Inteligente',
    'ar': 'ذكي',
  },
  'foundation': {
    'en': 'Foundation',
    'zh': '基础',
    'zh_Hant': '基礎',
    'ja': '基盤',
    'fr': 'Fondation',
    'ru': 'База',
    'es': 'Base',
    'ar': 'أساسي',
  },
  'ai-tools': {
    'en': 'AI Tools',
    'zh': 'AI 工具',
    'zh_Hant': 'AI 工具',
    'ja': 'AI ツール',
    'fr': "Outils d'IA",
    'ru': 'AI-инструменты',
    'es': 'Herramientas de IA',
    'ar': 'أدوات الذكاء الاصطناعي',
  },
  'business': {
    'en': 'Business',
    'zh': '商业',
    'zh_Hant': '商務',
    'ja': 'ビジネス',
    'fr': 'Business',
    'ru': 'Бизнес',
    'es': 'Negocio',
    'ar': 'الأعمال',
  },
  'commerce': {
    'en': 'Commerce',
    'zh': '电商',
    'zh_Hant': '電商',
    'ja': 'コマース',
    'fr': 'Commerce',
    'ru': 'Коммерция',
    'es': 'Comercio',
    'ar': 'التجارة',
  },
  'education': {
    'en': 'Education',
    'zh': '教育',
    'zh_Hant': '教育',
    'ja': '教育',
    'fr': 'Éducation',
    'ru': 'Образование',
    'es': 'Educación',
    'ar': 'التعليم',
  },
  'local': {
    'en': 'Local Services',
    'zh': '本地服务',
    'zh_Hant': '本地服務',
    'ja': 'ローカルサービス',
    'fr': 'Services locaux',
    'ru': 'Локальные сервисы',
    'es': 'Servicios locales',
    'ar': 'خدمات محلية',
  },
  'creator': {
    'en': 'Creator',
    'zh': '创作者',
    'zh_Hant': '創作者',
    'ja': 'クリエイター',
    'fr': 'Créateur',
    'ru': 'Креатор',
    'es': 'Creador',
    'ar': 'صنّاع المحتوى',
  },
};

const _LocalizedText _featuredLabels = {
  'en': 'Featured',
  'zh': '推荐',
  'zh_Hant': '推薦',
  'ja': 'おすすめ',
  'fr': 'À la une',
  'ru': 'Рекомендуем',
  'es': 'Destacado',
  'ar': 'مميز',
};

const Map<String, _LocalizedText> _templateNames = {
  'auto': {
    'en': 'Auto',
    'zh': '自动',
    'zh_Hant': '自動',
    'ja': '自動',
    'fr': 'Auto',
    'ru': 'Авто',
    'es': 'Automático',
    'ar': 'تلقائي',
  },
  'd1v-community/remix-neon-auth-pay': {
    'en': 'Pay Demo',
    'zh': '支付演示',
    'zh_Hant': '支付示範',
    'ja': '決済デモ',
    'fr': 'Démo de paiement',
    'ru': 'Демо платежей',
    'es': 'Demo de pagos',
    'ar': 'عرض توضيحي للدفع',
  },
  'd1v-community/assistant-saas-template': {
    'en': 'AI Assistant SaaS',
    'zh': 'AI 助手 SaaS',
    'zh_Hant': 'AI 助手 SaaS',
    'ja': 'AI アシスタント SaaS',
    'fr': "SaaS d'assistant IA",
    'ru': 'SaaS AI-ассистента',
    'es': 'SaaS de asistente de IA',
    'ar': 'SaaS لمساعد الذكاء الاصطناعي',
  },
  'd1v-community/client-portal-template': {
    'en': 'Client Portal',
    'zh': '客户门户',
    'zh_Hant': '客戶入口',
    'ja': 'クライアントポータル',
    'fr': 'Portail client',
    'ru': 'Клиентский портал',
    'es': 'Portal del cliente',
    'ar': 'بوابة العملاء',
  },
  'd1v-community/internal-dashboard-template': {
    'en': 'Internal Dashboard',
    'zh': '内部仪表盘',
    'zh_Hant': '內部儀表板',
    'ja': '内部ダッシュボード',
    'fr': 'Tableau de bord interne',
    'ru': 'Внутренняя панель',
    'es': 'Panel interno',
    'ar': 'لوحة تحكم داخلية',
  },
  'd1v-community/digital-downloads-template': {
    'en': 'Digital Downloads',
    'zh': '数字下载',
    'zh_Hant': '數位下載',
    'ja': 'デジタルダウンロード',
    'fr': 'Téléchargements numériques',
    'ru': 'Цифровые загрузки',
    'es': 'Descargas digitales',
    'ar': 'تنزيلات رقمية',
  },
  'd1v-community/online-course-membership-template': {
    'en': 'Online Course Membership',
    'zh': '在线课程会员',
    'zh_Hant': '線上課程會員',
    'ja': 'オンライン講座メンバーシップ',
    'fr': 'Abonnement cours en ligne',
    'ru': 'Подписка на онлайн-курс',
    'es': 'Membresía de curso en línea',
    'ar': 'عضوية دورة عبر الإنترنت',
  },
  'd1v-community/clinic-booking-template': {
    'en': 'Clinic Booking',
    'zh': '诊所预约',
    'zh_Hant': '診所預約',
    'ja': 'クリニック予約',
    'fr': 'Réservation clinique',
    'ru': 'Запись в клинику',
    'es': 'Reserva de clínica',
    'ar': 'حجز العيادة',
  },
  'd1v-community/prompt-library-membership-template': {
    'en': 'Prompt Library Membership',
    'zh': '提示词库会员',
    'zh_Hant': '提示詞庫會員',
    'ja': 'プロンプトライブラリ会員',
    'fr': 'Abonnement bibliothèque de prompts',
    'ru': 'Подписка на библиотеку промптов',
    'es': 'Membresía de biblioteca de prompts',
    'ar': 'عضوية مكتبة البرومبت',
  },
  'd1v-community/community-membership-template': {
    'en': 'Creator Community Membership',
    'zh': '创作者社群会员',
    'zh_Hant': '創作者社群會員',
    'ja': 'クリエイターコミュニティ会員',
    'fr': 'Abonnement communauté créateur',
    'ru': 'Подписка сообщества креаторов',
    'es': 'Membresía de comunidad de creadores',
    'ar': 'عضوية مجتمع المبدعين',
  },
  'd1v-community/paid-newsletter-template': {
    'en': 'Paid Newsletter',
    'zh': '付费通讯',
    'zh_Hant': '付費電子報',
    'ja': '有料ニュースレター',
    'fr': 'Newsletter payante',
    'ru': 'Платная рассылка',
    'es': 'Newsletter de pago',
    'ar': 'نشرة مدفوعة',
  },
  'd1v-community/cohort-course-template': {
    'en': 'Cohort Course',
    'zh': '分组课程',
    'zh_Hant': '分組課程',
    'ja': 'コホート講座',
    'fr': 'Cours en cohorte',
    'ru': 'Когортный курс',
    'es': 'Curso por cohortes',
    'ar': 'دورة جماعية',
  },
  'd1v-community/preorder-launch-template': {
    'en': 'Preorder Launch',
    'zh': '预售发布',
    'zh_Hant': '預購上線',
    'ja': '先行予約ローンチ',
    'fr': 'Lancement en précommande',
    'ru': 'Запуск предзаказа',
    'es': 'Lanzamiento de preventa',
    'ar': 'إطلاق الطلب المسبق',
  },
  'd1v-community/gym-membership-template': {
    'en': 'Gym Membership',
    'zh': '健身会员',
    'zh_Hant': '健身會員',
    'ja': 'ジム会員',
    'fr': 'Abonnement salle de sport',
    'ru': 'Абонемент в зал',
    'es': 'Membresía de gimnasio',
    'ar': 'عضوية نادي رياضي',
  },
  'd1v-community/remix-neon-auth-template': {
    'en': 'Remix Neon Auth',
    'zh': 'Remix Neon 认证',
    'zh_Hant': 'Remix Neon 驗證',
    'ja': 'Remix Neon 認証',
    'fr': 'Remix Neon Auth',
    'ru': 'Remix Neon Auth',
    'es': 'Remix Neon Auth',
    'ar': 'توثيق Remix Neon',
  },
  'd1v-community/sui-nextjs-auth-template': {
    'en': 'Sui Next.js Auth',
    'zh': 'Sui Next.js 认证',
    'zh_Hant': 'Sui Next.js 驗證',
    'ja': 'Sui Next.js 認証',
    'fr': 'Sui Next.js Auth',
    'ru': 'Sui Next.js Auth',
    'es': 'Sui Next.js Auth',
    'ar': 'توثيق Sui Next.js',
  },
  'd1v-community/html-template': {
    'en': 'HTML Template',
    'zh': 'HTML 模板',
    'zh_Hant': 'HTML 範本',
    'ja': 'HTML テンプレート',
    'fr': 'Modèle HTML',
    'ru': 'HTML-шаблон',
    'es': 'Plantilla HTML',
    'ar': 'قالب HTML',
  },
};

const Map<String, _LocalizedText> _templateDescriptions = {
  'auto': {
    'en': 'Let D1V choose the best template based on your prompt.',
    'zh': '让 D1V 根据你的需求自动选择最合适的模板。',
    'zh_Hant': '讓 D1V 根據你的需求自動選擇最合適的模板。',
    'ja': 'D1V がプロンプトに応じて最適なテンプレートを自動で選びます。',
    'fr': 'Laissez D1V choisir le meilleur modèle selon votre prompt.',
    'ru': 'D1V автоматически выберет лучший шаблон по вашему запросу.',
    'es': 'Deja que D1V elija la mejor plantilla según tu prompt.',
    'ar': 'دع D1V يختار أفضل قالب بناءً على طلبك.',
  },
};

LocalizedProjectTemplateView localizeProjectTemplate(
  ProjectTemplateInfo template,
  Locale locale,
) {
  final localeKey = _localeKeyFromLocale(locale);
  return LocalizedProjectTemplateView(
    name: _resolveLocalizedText(
      template.name,
      localeKey,
      _templateNames[template.templateRepo],
    ),
    description: _resolveLocalizedText(
      template.description,
      localeKey,
      _templateDescriptions[template.templateRepo],
    ),
    category: _resolveLocalizedText(
      template.category,
      localeKey,
      _categoryLabels[template.category],
    ),
    featuredLabel: _resolveLocalizedText(
      'Featured',
      localeKey,
      _featuredLabels,
    ),
  );
}
