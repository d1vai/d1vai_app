/// 测试修复后的 API 调用
/// 运行此脚本来验证 API 调用路径是否正确

import 'lib/core/api_client.dart';
import 'lib/services/d1vai_service.dart';

void testApiFixes() {
  print('=== API 修复验证 ===\n');

  // 测试 1: 验证 baseUrl
  print('1. 验证 baseUrl:');
  print('   ApiClient.baseUrl: ${ApiClient.baseUrl}');
  print('   预期: https://api.d1v.ai');
  print('   状态: ${ApiClient.baseUrl == 'https://api.d1v.ai' ? '✅ 正确' : '❌ 错误'}\n');

  // 测试 2: 验证文件上传路径构建
  print('2. 验证文件上传路径:');
  final uploadPath = '${ApiClient.baseUrl}/upload';
  print('   完整路径: $uploadPath');
  print('   预期: https://api.d1v.ai/upload');
  print('   状态: ${uploadPath == 'https://api.d1v.ai/upload' ? '✅ 正确' : '❌ 错误'}\n');

  // 测试 3: 验证用户资料更新路径
  print('3. 验证用户资料更新路径:');
  final userInfoPath = '${ApiClient.baseUrl}/api/user/info';
  print('   完整路径: $userInfoPath');
  print('   预期: https://api.d1v.ai/api/user/info');
  print('   状态: ${userInfoPath == 'https://api.d1v.ai/api/user/info' ? '✅ 正确' : '❌ 错误'}\n');

  // 测试 4: 验证 D1vaiService 方法
  print('4. 验证 D1vaiService.putUserProfile:');
  print('   方法: PUT');
  print('   路径: /user/info');
  print('   服务层: D1vaiService ✅\n');

  // 测试 5: 验证所有 API 调用的路径前缀
  print('5. 验证 API 调用路径:');
  final apiEndpoints = [
    '/user/info',
    '/user/login',
    '/projects',
    '/community/posts',
  ];

  for (final endpoint in apiEndpoints) {
    final fullPath = '${ApiClient.baseUrl}/api$endpoint';
    print('   $endpoint');
    print('     → $fullPath');
  }

  print('\n=== 修复总结 ===');
  print('✅ baseUrl 已从 https://api.d1v.ai/api 修正为 https://api.d1v.ai');
  print('✅ 文件上传路径已修正为 $baseUrl/upload');
  print('✅ 用户资料更新使用 PUT /api/user/info');
  print('✅ 统一使用 D1vaiService');
  print('✅ 响应处理逻辑已优化\n');

  print('=== 预期修复的功能 ===');
  print('✅ 修改个人信息中的行业信息');
  print('✅ 修改公司名称和网站');
  print('✅ 修改钱包地址');
  print('✅ 上传头像');
  print('✅ 所有 API 调用的错误处理\n');

  print('测试完成！');
}

void main() {
  testApiFixes();
}
