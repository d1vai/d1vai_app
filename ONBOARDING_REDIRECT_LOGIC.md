# Onboarding 重定向逻辑实现完成

## 📋 功能描述

根据用户模型中的 `is_onboarded` 字段（对应 Dart 模型中的 `isOnboarded`），系统现在会自动判断并重定向用户到 Onboarding 页面，引导用户完成初始设置。

## ✅ 已完成的工作

### 1. 创建了 OnboardingScreen 页面
**文件**：`lib/screens/onboarding_screen.dart`

- 使用 `OnboardingWizard` 组件作为主要内容
- Onboarding 完成后的回调处理
- 自动跳转到 dashboard 或登录页

**核心代码**：
```dart
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: OnboardingWizard(
        onCompleted: () {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );

          if (authProvider.user != null) {
            context.go('/dashboard');
          } else {
            context.go('/login');
          }
        },
      ),
    ),
  );
}
```

### 2. 更新了路由配置
**文件**：`lib/router/app_router.dart`

#### a) 添加了 OnboardingScreen 导入
```dart
import '../screens/onboarding_screen.dart';
```

#### b) 添加了 `/onboarding` 路由
```dart
GoRoute(
  path: '/onboarding',
  pageBuilder: (context, state) => _buildPageWithTransition(
    context,
    state,
    const OnboardingScreen(),
  ),
),
```

#### c) 更新了重定向逻辑

**新增检查项目**：
- `needsOnboarding` - 检查用户是否需要完成 onboarding
- `isOnboardingPage` - 检查当前是否在 onboarding 页面

**重定向规则**：

1. **未登录用户**
   - 未登录且不在登录页 → 重定向到 `/login`

2. **已登录但需要 onboarding 的用户**
   - 已登录 + 需要 onboarding + 不在 onboarding 页面 → 重定向到 `/onboarding`
   - 已登录 + 已在 onboarding 页面 → 保持在 `/onboarding`

3. **已登录且已完成 onboarding 的用户**
   - 已登录 + 已完成 onboarding + 在 onboarding 页面 → 重定向到 `/dashboard`
   - 已登录 + 在登录页 → 重定向到 `/dashboard`

4. **loading 状态**
   - 正在加载中 → 保持在当前页面（除 splash 页面外）

**完整重定向逻辑**：
```dart
redirect: (BuildContext context, GoRouterState state) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final isAuthenticated = authProvider.isAuthenticated;
  final isLoading = authProvider.isLoading;
  final needsOnboarding = authProvider.needsOnboarding;

  final isLoginPage = state.matchedLocation == '/login';
  final isSplashPage = state.matchedLocation == '/';
  final isOnboardingPage = state.matchedLocation == '/onboarding';

  // 1. 如果正在加载，保持在当前页面
  if (isLoading && !isSplashPage) {
    return null;
  }

  // 2. 如果未登录且不在登录页，重定向到登录页
  if (!isAuthenticated && !isLoginPage && !isSplashPage) {
    return '/login';
  }

  // 3. 如果已登录且需要完成 onboarding，且不在 onboarding 页面，重定向到 onboarding
  if (isAuthenticated && needsOnboarding && !isOnboardingPage) {
    return '/onboarding';
  }

  // 4. 如果已登录且已完成 onboarding，且在 onboarding 页面，重定向到 dashboard
  if (isAuthenticated && !needsOnboarding && isOnboardingPage) {
    return '/dashboard';
  }

  // 5. 如果已登录且在登录页，重定向到 dashboard
  if (isAuthenticated && isLoginPage) {
    return '/dashboard';
  }

  return null;
}
```

## 🎯 业务流程

### Onboarding 流程包含 4 个步骤：

1. **邀请码步骤**
   - 输入邀请码
   - 调用 `authProvider.acceptInvitation(code)`

2. **公司信息步骤**
   - 填写公司名称、网站、所属行业
   - 调用 `authProvider.saveCompanyInfo(name, website, industry)`

3. **头像步骤**
   - 从相册上传或选择 AI 生成的头像
   - 调用 `authProvider.updateAvatar(url)`

4. **完成步骤**
   - 调用 `authProvider.completeOnboarding()`
   - 更新服务器上的 `is_onboarded` 字段为 `true`
   - 自动跳转到 dashboard

## 🔄 数据流

### 登录流程中的数据处理：

1. **登录成功** → 获取用户信息
2. **检查 `isOnboarded` 字段**
   - 如果为 `false` → 创建 `OnboardingData` 并保存到本地存储
   - 如果为 `true` → 清理本地 onboarding 数据

3. **路由重定向**
   - 如果 `needsOnboarding` 为 `true` → 跳转到 `/onboarding`
   - 如果 `needsOnboarding` 为 `false` → 跳转到 `/dashboard`

### Onboarding 完成后的数据更新：

1. **每步操作** → 更新服务器上的用户信息
2. **完成操作** → 调用 `postUserOnboardedSet(true)`
3. **获取最新用户信息** → `isOnboarded` 字段更新为 `true`
4. **清理本地数据** → 删除 onboarding 相关存储
5. **自动跳转到 dashboard**

## 📊 关键属性和方法

### AuthProvider 相关

**属性**：
- `user` - 当前用户信息（含 `isOnboarded` 字段）
- `needsOnboarding` - 检查是否需要完成 onboarding
- `onboardingData` - 本地 onboarding 数据

**方法**：
- `acceptInvitation(String code)` - 接受邀请码
- `saveCompanyInfo(String name, String? website, String? industry)` - 保存公司信息
- `updateAvatar(String avatarUrl)` - 更新头像
- `completeOnboarding()` - 完成 onboarding
- `fetchUser()` - 重新获取用户信息

### User 模型

```dart
class User {
  // ...
  final bool isOnboarded;  // 是否已完成 onboarding
  // ...
}
```

## 🧪 测试场景

### 场景 1：新用户登录
```
操作：未完成 onboarding 的用户登录
预期：
  ✅ 自动跳转到 /onboarding
  ✅ 显示 OnboardingWizard
```

### 场景 2：已完成 onboarding 的用户登录
```
操作：已完成 onboarding 的用户登录
预期：
  ✅ 自动跳转到 /dashboard
  ✅ 不显示 OnboardingWizard
```

### 场景 3：在 onboarding 页面尝试访问 dashboard
```
操作：在 /onboarding 页面手动输入 /dashboard URL
预期：
  ✅ 自动重定向回 /onboarding
  ✅ 无法绕过 onboarding
```

### 场景 4：完成 onboarding
```
操作：在 onboarding 页面点击"完成"按钮
预期：
  ✅ 服务器更新 is_onboarded = true
  ✅ 自动跳转到 /dashboard
  ✅ 本地 onboarding 数据被清理
```

## 🔐 安全性

- **路由保护**：已完成 onboarding 的用户无法绕过流程访问 onboarding 页面
- **数据一致性**：服务器端是 `is_onboarded` 字段的唯一权威
- **状态同步**：每次操作后都会同步服务器和本地状态

## 📝 注意事项

1. **向后兼容**：已完成 onboarding 的用户不会受到影响
2. **错误处理**：所有 onboarding 相关操作都有完整的错误处理
3. **本地存储**：onboarding 数据保存在本地，支持中断后继续
4. **自动清理**：完成 onboarding 后会自动清理本地数据

## 🎉 总结

现在系统能够：
- ✅ 自动检测用户是否需要完成 onboarding
- ✅ 自动重定向到相应的页面
- ✅ 引导用户完成邀请码、公司信息、头像等初始设置
- ✅ 完成设置后自动进入应用
- ✅ 确保已完成的用户无法再次访问 onboarding 流程

用户现在可以流畅地完成初始设置，系统会根据 `is_onboarded` 字段自动管理用户的引导流程！🚀
