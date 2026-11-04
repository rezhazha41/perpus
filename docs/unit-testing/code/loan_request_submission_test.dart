import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/server/loan_request_submission.dart';

void main() {
  test(
    'uploads evidence before RPC and reuses key/path after ambiguous failure',
    () async {
      var nextKey = 0;
      final submission = LoanRequestSubmission(() => 'request-${++nextKey}');
      final events = <String>[];
      var rpcCalls = 0;

      Future<void> send() => submission.submit(
        memberId: 'member-a',
        extension: 'jpg',
        uploadEvidence: (path) async => events.add('upload:$path'),
        createRequest: (key, path, _) async {
          events.add('rpc:$key:$path');
          if (++rpcCalls == 1) throw TimeoutException('response unknown');
        },
      );

      await expectLater(send(), throwsA(isA<TimeoutException>()));
      expect(submission.evidenceUploaded, isTrue);
      expect(submission.requestAttempted, isTrue);
      await send();

      expect(events, [
        'upload:member-a/request-1.jpg',
        'rpc:request-1:member-a/request-1.jpg',
        'rpc:request-1:member-a/request-1.jpg',
      ]);
      expect(nextKey, 1);
    },
  );

  test('does not call the RPC when evidence upload fails', () async {
    final submission = LoanRequestSubmission(() => 'request-1');
    var rpcCalls = 0;

    await expectLater(
      submission.submit(
        memberId: 'member-a',
        extension: 'jpg',
        uploadEvidence: (_) async => throw StateError('offline'),
        createRequest: (_, _, _) async => rpcCalls++,
      ),
      throwsA(isA<StateError>()),
    );

    expect(rpcCalls, 0);
    expect(submission.evidenceUploaded, isFalse);
  });

  test('new evidence resets the idempotency identity', () async {
    var nextKey = 0;
    final submission = LoanRequestSubmission(() => 'request-${++nextKey}');
    final requestKeys = <String>[];

    Future<void> send() => submission.submit(
      memberId: 'member-a',
      extension: 'jpg',
      uploadEvidence: (_) async {},
      createRequest: (key, _, _) async => requestKeys.add(key),
    );

    await send();
    submission.reset();
    expect(submission.requestAttempted, isFalse);
    await send();

    expect(requestKeys, ['request-1', 'request-2']);
  });

  test('uploads optional attachment before RPC and reuses its path on retry', () async {
    final submission = LoanRequestSubmission(() => 'request-1');
    final events = <String>[];
    var rpcCalls = 0;

    Future<void> send() => submission.submit(
      memberId: 'member-a',
      extension: 'jpg',
      uploadEvidence: (path) async => events.add('evidence:$path'),
      attachmentExtension: 'pdf',
      uploadAttachment: (path) async => events.add('attachment:$path'),
      createRequest: (key, evidencePath, attachmentPath) async {
        events.add('rpc:$key:$evidencePath:$attachmentPath');
        if (++rpcCalls == 1) throw TimeoutException('response unknown');
      },
    );

    await expectLater(send(), throwsA(isA<TimeoutException>()));
    await send();

    expect(events, [
      'evidence:member-a/request-1.jpg',
      'attachment:member-a/request-1-attachment.pdf',
      'rpc:request-1:member-a/request-1.jpg:member-a/request-1-attachment.pdf',
      'rpc:request-1:member-a/request-1.jpg:member-a/request-1-attachment.pdf',
    ]);
  });

  test('attachment upload failure does not call the RPC', () async {
    final submission = LoanRequestSubmission(() => 'request-1');
    var rpcCalls = 0;

    await expectLater(
      submission.submit(
        memberId: 'member-a',
        extension: 'jpg',
        uploadEvidence: (_) async {},
        attachmentExtension: 'pdf',
        uploadAttachment: (_) async => throw StateError('offline'),
        createRequest: (_, _, _) async => rpcCalls++,
      ),
      throwsA(isA<StateError>()),
    );

    expect(rpcCalls, 0);
  });
}
