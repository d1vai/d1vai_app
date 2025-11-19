class User {
  final int id;
  final String? slug;
  final bool isAgent;
  final String picture;
  final bool isOnboarded;
  final bool isAdmin;
  final bool isSuperAdmin;
  final bool isCompany;
  final String companyName;
  final String companyWebsite;
  final String industry;
  final String inviteCode;
  final String referralCode;
  final String solWallet;
  final String suiWallet;
  final String evmWallet;
  final String sub;
  final String? email;
  final String? lastLoginType;
  final String? stripeCustomerId;
  final String? bearerToken;

  User({
    required this.id,
    this.slug,
    required this.isAgent,
    required this.picture,
    required this.isOnboarded,
    required this.isAdmin,
    required this.isSuperAdmin,
    required this.isCompany,
    required this.companyName,
    required this.companyWebsite,
    required this.industry,
    required this.inviteCode,
    required this.referralCode,
    required this.solWallet,
    required this.suiWallet,
    required this.evmWallet,
    required this.sub,
    this.email,
    this.lastLoginType,
    this.stripeCustomerId,
    this.bearerToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      slug: json['slug'],
      isAgent: json['is_agent'] ?? false,
      picture: json['picture'] ?? '',
      isOnboarded: json['is_onboarded'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      isSuperAdmin: json['is_super_admin'] ?? false,
      isCompany: json['is_company'] ?? false,
      companyName: json['company_name'] ?? '',
      companyWebsite: json['company_website'] ?? '',
      industry: json['industry'] ?? '',
      inviteCode: json['invite_code'] ?? '',
      referralCode: json['referral_code'] ?? '',
      solWallet: json['sol_wallet'] ?? '',
      suiWallet: json['sui_wallet'] ?? '',
      evmWallet: json['evm_wallet'] ?? '',
      sub: json['sub'] ?? '',
      email: json['email'],
      lastLoginType: json['last_login_type'],
      stripeCustomerId: json['stripe_customer_id'],
      bearerToken: json['bearerToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'is_agent': isAgent,
      'picture': picture,
      'is_onboarded': isOnboarded,
      'is_admin': isAdmin,
      'is_super_admin': isSuperAdmin,
      'is_company': isCompany,
      'company_name': companyName,
      'company_website': companyWebsite,
      'industry': industry,
      'invite_code': inviteCode,
      'referral_code': referralCode,
      'sol_wallet': solWallet,
      'sui_wallet': suiWallet,
      'evm_wallet': evmWallet,
      'sub': sub,
      'email': email,
      'last_login_type': lastLoginType,
      'stripe_customer_id': stripeCustomerId,
      'bearerToken': bearerToken,
    };
  }

  /// 复制对象并更新字段
  User copyWith({
    int? id,
    String? slug,
    bool? isAgent,
    String? picture,
    bool? isOnboarded,
    bool? isAdmin,
    bool? isSuperAdmin,
    bool? isCompany,
    String? companyName,
    String? companyWebsite,
    String? industry,
    String? inviteCode,
    String? referralCode,
    String? solWallet,
    String? suiWallet,
    String? evmWallet,
    String? sub,
    String? email,
    String? lastLoginType,
    String? stripeCustomerId,
    String? bearerToken,
  }) {
    return User(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      isAgent: isAgent ?? this.isAgent,
      picture: picture ?? this.picture,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isAdmin: isAdmin ?? this.isAdmin,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      isCompany: isCompany ?? this.isCompany,
      companyName: companyName ?? this.companyName,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      industry: industry ?? this.industry,
      inviteCode: inviteCode ?? this.inviteCode,
      referralCode: referralCode ?? this.referralCode,
      solWallet: solWallet ?? this.solWallet,
      suiWallet: suiWallet ?? this.suiWallet,
      evmWallet: evmWallet ?? this.evmWallet,
      sub: sub ?? this.sub,
      email: email ?? this.email,
      lastLoginType: lastLoginType ?? this.lastLoginType,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      bearerToken: bearerToken ?? this.bearerToken,
    );
  }
}
