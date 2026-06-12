// Firestore セキュリティルールのテスト
// 前提: Firestore Emulator が起動していること
// 実行: リポジトリルートで
//   firebase emulators:exec --only firestore,storage "npm --prefix rules_test test"
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'glaze-manager-rules-test',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

const aliceDoc = (ctx) =>
  ctx.firestore().collection('users').doc('alice').collection('glazes').doc('g1');

test('本人は自分の users/{uid} 配下を読み書きできる', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await assertSucceeds(aliceDoc(alice).set({ name: '透明釉' }));
  await assertSucceeds(aliceDoc(alice).get());
});

test('他人の users/{uid} 配下は読み書きできない', async () => {
  const mallory = testEnv.authenticatedContext('mallory');
  await assertFails(aliceDoc(mallory).set({ name: '改ざん' }));
  await assertFails(aliceDoc(mallory).get());
});

test('未認証では読み書きできない', async () => {
  const anon = testEnv.unauthenticatedContext();
  await assertFails(aliceDoc(anon).get());
  await assertFails(aliceDoc(anon).set({ name: 'x' }));
});

test('深い階層 (サブコレクション) にもルールが適用される', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const mallory = testEnv.authenticatedContext('mallory');
  const deep = (ctx) =>
    ctx
      .firestore()
      .doc('users/alice/test_pieces/tp1');
  await assertSucceeds(deep(alice).set({ note: 'ok' }));
  await assertFails(deep(mallory).get());
});

test('users 直下以外のコレクションは誰も読み書きできない', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await assertFails(
    alice.firestore().collection('global_stuff').doc('x').set({ a: 1 }),
  );
});
