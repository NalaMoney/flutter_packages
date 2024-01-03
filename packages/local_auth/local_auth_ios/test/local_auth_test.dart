// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalAuth', () {
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/local_auth_ios',
    );

    final List<MethodCall> log = <MethodCall>[];
    late LocalAuthIOS localAuthentication;

    setUp(() {
      _ambiguate(TestDefaultBinaryMessengerBinding.instance)!
          .defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getEnrolledBiometrics':
            return Future<List<String>>.value(
                <String>['face', 'fingerprint', 'iris', 'undefined']);
          default:
            return Future<dynamic>.value(true);
        }
      });
      localAuthentication = LocalAuthIOS();
      log.clear();
    });

    test('deviceSupportsBiometrics calls platform', () async {
      final bool result = await localAuthentication.deviceSupportsBiometrics();

      expect(
        log,
        <Matcher>[
          isMethodCall('deviceSupportsBiometrics', arguments: null),
        ],
      );
      expect(result, true);
    });

    test('getEnrolledBiometrics calls platform', () async {
      final List<BiometricType> result =
          await localAuthentication.getEnrolledBiometrics();

      expect(
        log,
        <Matcher>[
          isMethodCall('getEnrolledBiometrics', arguments: null),
        ],
      );
      expect(result, <BiometricType>[
        BiometricType.face,
        BiometricType.fingerprint,
        BiometricType.iris
      ]);
    });

    group('isDeviceSupported with device auth fail over', () {
      test('isDeviceSupported with no args', () async {
        await localAuthentication.isDeviceSupported();

        expect(
          log,
          <Matcher>[
            isMethodCall(
              'isDeviceSupported',
              arguments: arguments: <String, dynamic>{
                'biometricOnly': false,
              },
            ),
          ],
        );
      });

      test('isDeviceSupported with args of biometricOnly true', () async {
        await localAuthentication.isDeviceSupported(
          options: const AuthenticationOptions(biometricOnly: true),
        );
        expect(
          log,
          <Matcher>[
            isMethodCall(
              'isDeviceSupported',
              arguments: arguments: <String, dynamic>{
                'biometricOnly': true,
              },
            ),
          ],
        );
      });

      test('isDeviceSupported with args of biometricOnly false', () async {
        await localAuthentication.isDeviceSupported(
          options: const AuthenticationOptions(biometricOnly: false),
        );
        expect(
          log,
          <Matcher>[
            isMethodCall(
              'isDeviceSupported',
              arguments: arguments: <String, dynamic>{
                'biometricOnly': false,
              },
            ),
          ],
        );
      });
    });

    test('stopAuthentication returns false', () async {
      final bool result = await localAuthentication.stopAuthentication();
      expect(result, false);
    });

    group('With device auth fail over', () {
      test('authenticate with no args.', () async {
        await localAuthentication.authenticate(
          authMessages: <AuthMessages>[const IOSAuthMessages()],
          localizedReason: 'Needs secure',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        expect(
          log,
          <Matcher>[
            isMethodCall('authenticate',
                arguments: <String, dynamic>{
                  'localizedReason': 'Needs secure',
                  'useErrorDialogs': true,
                  'stickyAuth': false,
                  'sensitiveTransaction': true,
                  'biometricOnly': true,
                }..addAll(const IOSAuthMessages().args)),
          ],
        );
      });

      test('authenticate with no localizedReason.', () async {
        await expectLater(
          localAuthentication.authenticate(
            authMessages: <AuthMessages>[const IOSAuthMessages()],
            localizedReason: '',
            options: const AuthenticationOptions(biometricOnly: true),
          ),
          throwsAssertionError,
        );
      });
    });

    group('With biometrics only', () {
      test('authenticate with no args.', () async {
        await localAuthentication.authenticate(
          authMessages: <AuthMessages>[const IOSAuthMessages()],
          localizedReason: 'Needs secure',
        );
        expect(
          log,
          <Matcher>[
            isMethodCall('authenticate',
                arguments: <String, dynamic>{
                  'localizedReason': 'Needs secure',
                  'useErrorDialogs': true,
                  'stickyAuth': false,
                  'sensitiveTransaction': true,
                  'biometricOnly': false,
                }..addAll(const IOSAuthMessages().args)),
          ],
        );
      });

      test('authenticate with `localizedFallbackTitle`', () async {
        await localAuthentication.authenticate(
          authMessages: <AuthMessages>[
            const IOSAuthMessages(localizedFallbackTitle: 'Enter PIN'),
          ],
          localizedReason: 'Needs secure',
        );
        expect(
          log,
          <Matcher>[
            isMethodCall('authenticate',
                arguments: <String, dynamic>{
                  'localizedReason': 'Needs secure',
                  'useErrorDialogs': true,
                  'stickyAuth': false,
                  'sensitiveTransaction': true,
                  'biometricOnly': false,
                  'localizedFallbackTitle': 'Enter PIN',
                }..addAll(const IOSAuthMessages().args)),
          ],
        );
      });

      test('authenticate with no sensitive transaction.', () async {
        await localAuthentication.authenticate(
          authMessages: <AuthMessages>[const IOSAuthMessages()],
          localizedReason: 'Insecure',
          options: const AuthenticationOptions(
            sensitiveTransaction: false,
            useErrorDialogs: false,
          ),
        );
        expect(
          log,
          <Matcher>[
            isMethodCall('authenticate',
                arguments: <String, dynamic>{
                  'localizedReason': 'Insecure',
                  'useErrorDialogs': false,
                  'stickyAuth': false,
                  'sensitiveTransaction': false,
                  'biometricOnly': false,
                }..addAll(const IOSAuthMessages().args)),
          ],
        );
      });
    });
  });
}

/// This allows a value of type T or T? to be treated as a value of type T?.
///
/// We use this so that APIs that have become non-nullable can still be used
/// with `!` and `?` on the stable branch.
T? _ambiguate<T>(T? value) => value;