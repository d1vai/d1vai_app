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
}
