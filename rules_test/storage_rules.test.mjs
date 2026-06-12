// Storage セキュリティルールのテスト
// 前提: Storage Emulator が起動していること (実行方法は firestore_rules.test.mjs 参照)
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'glaze-manager-rules-test',
    storage: {
      rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

const aliceImage = (ctx) =>
  ref(ctx.storage(), 'users/alice/test_pieces/images/tp1/photo.jpg');

const bytes = new Uint8Array([1, 2, 3]);

test('本人は自分のフォルダにアップロード・ダウンロードできる', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await assertSucceeds(uploadBytes(aliceImage(alice), bytes));
  await assertSucceeds(getBytes(aliceImage(alice)));
});

test('他人のフォルダには読み書きできない', async () => {
  const mallory = testEnv.authenticatedContext('mallory');
  await assertFails(uploadBytes(aliceImage(mallory), bytes));
  await assertFails(getBytes(aliceImage(mallory)));
});

test('未認証では読み書きできない', async () => {
  const anon = testEnv.unauthenticatedContext();
  await assertFails(getBytes(aliceImage(anon)));
});

test('users 以外のパスには誰も書き込めない', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await assertFails(
    uploadBytes(ref(alice.storage(), 'public/evil.jpg'), bytes),
  );
});
