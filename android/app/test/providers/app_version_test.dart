import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/providers/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('formats version + build number from PackageInfo', () async {
    PackageInfo.setMockInitialValues(
      appName: 'heerr',
      packageName: 'com.aashish.heerr',
      version: '4.1.0',
      buildNumber: '9',
      buildSignature: '',
    );
    expect(await container().read(appVersionProvider.future), 'v4.1.0+9');
  });

  test('omits build suffix when buildNumber is empty', () async {
    PackageInfo.setMockInitialValues(
      appName: 'heerr',
      packageName: 'com.aashish.heerr',
      version: '4.1.0',
      buildNumber: '',
      buildSignature: '',
    );
    expect(await container().read(appVersionProvider.future), 'v4.1.0');
  });
}
