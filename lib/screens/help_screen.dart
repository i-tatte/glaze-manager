import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ヘルプ / FAQ')),
      body: ListView(
        children: const [
          _SectionHeader(title: '検索機能について'),
          _HelpItem(
            question: '検索キーワードの使い方',
            answer:
                'スペース区切りで複数のキーワードを入力すると「AND検索」になります。\n'
                'キーワードの前に「-」をつけると、そのキーワードを含まないものを検索できます（例: 「-透明」）。',
          ),
          _HelpItem(
            question: 'タグ検索',
            answer: 'タグアイコンをタップして、登録済みのタグから絞り込みができます。',
          ),
          _HelpItem(
            question: '色検索',
            answer:
                'パレットアイコンをタップして色を選択すると、その色に近いテストピースを検索できます。'
                'スライダーで「色差許容値 (ΔE)」を調整することで、検索の厳密さを変更できます。',
          ),
          _HelpItem(
            question: '原料検索',
            answer:
                '釉薬のレシピに含まれる原料名でも検索が可能です。\n'
                '「もしかして...」として、原料名のみが一致する結果はリストの後方に表示されます。',
          ),
          Divider(),
          _SectionHeader(title: '調合計算機について'),
          _HelpItem(
            question: '使い方は？',
            answer: '釉薬詳細またはテストピース詳細画面のレシピ欄にある「調合計算へ」ボタンから起動できます。',
          ),
          _HelpItem(
            question: '計算モード',
            answer:
                '・総重量モード: 合計重量を入力すると、各原料の重量が自動計算されます。\n'
                '・原料基準モード: 特定の原料の重量を入力すると、その原料を基準に全体の重量と他の原料の重量が再計算されます。',
          ),
          Divider(),
          _SectionHeader(title: 'データ管理について'),
          _HelpItem(
            question: '焼成雰囲気タイプ',
            answer:
                '「酸化」「還元」「その他」の3タイプから選択できます。\n'
                '一覧画面では、酸化は暖色系、還元は寒色系の背景色で表示され、視認性が向上します。',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q. $question',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(answer, style: Theme.of(context).textTheme.bodyLarge),
          const Divider(),
        ],
      ),
    );
  }
}
