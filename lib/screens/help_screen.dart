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
                '釉薬の調合に含まれる原料名でも検索が可能です。\n'
                '「もしかして...」として、原料名のみが一致する結果はリストの後方に表示されます。',
          ),
          _HelpItem(
            question: '評価・番号・焼成回での検索',
            answer:
                '星のアイコンから「★3 以上」のように評価で絞り込めます。\n'
                'テストピースの番号、窯の名前、焼成日（例: 2026/11/8）もキーワードで検索できます。',
          ),
          Divider(),
          _SectionHeader(title: '調合計算機について'),
          _HelpItem(
            question: '使い方は？',
            answer: '釉薬詳細またはテストピース詳細画面の調合の欄にある「調合計算へ」ボタンから起動できます。',
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
          _HelpItem(
            question: 'データの書き出し',
            answer:
                '設定の「データの書き出し」で、釉薬・テストピース・写真を 1 つの ZIP ファイルに保存できます。\n'
                '中には、表計算ソフトで開ける Excel ファイル、全データの JSON、テストピースの写真が入ります。'
                '通信できずに取得できなかった写真があれば、枚数をお知らせします。',
          ),
          Divider(),
          _SectionHeader(title: 'テストピースの記録について'),
          _HelpItem(
            question: '調合の記録',
            answer:
                'テストピースは、登録したときの釉薬の調合を自分の記録として持ちます。'
                'あとで釉薬の調合を変えたり、釉薬を削除したりしても、テストピースに表示される調合は変わりません。\n'
                '釉薬の現在の調合と違う場合は、詳細画面にその旨が表示されます。'
                '調合を改良するときは、釉薬の詳細画面の「複製して新規作成」を使うと、元の釉薬との関係と変更点が残ります。',
          ),
          _HelpItem(
            question: '焼成回',
            answer:
                '同じ窯で一緒に焼いたテストピースをまとめる単位です。'
                '焼成日・窯・焼成雰囲気・焼成プロファイル・最高温度・コーン・所感を一度入力すれば、その焼成回を選んだテストピースすべてに反映されます。\n'
                'テストピースタブ右上の炎のアイコンから一覧を開けます。窯入れの前に写真なしで登録しておき、焼成後に写真を付けることもできます。',
          ),
          _HelpItem(
            question: '評価と番号',
            answer:
                '評価は星 1〜5 で付けます。同じ星をもう一度タップすると取り消せます。\n'
                '番号には、実物のテストピースに書いた番号を入れておくと、実物と記録を照らし合わせられます。',
          ),
          _HelpItem(
            question: '続けて登録する',
            answer:
                '新規登録の画面の「保存して次を登録」を押すと、釉薬・素地土・焼成回を引き継いだまま次の 1 枚に進みます。番号は末尾の数字が 1 つ進みます。\n'
                '「複数の写真を選んで連続登録」で写真をまとめて選ぶと、1 枚ずつ切り抜きながら続けて登録できます。',
          ),
          _HelpItem(
            question: '比較',
            answer:
                '一覧でテストピースを長押しすると選択できます。2〜4 枚を選んで右上の比較ボタンを押すと、写真と条件を横に並べて見られます。\n'
                '値が違う項目と、割合が違う原料に色が付きます。記録のない項目は「—」と表示されます。',
          ),
          _HelpItem(
            question: 'オフラインで選んだ写真',
            answer:
                '通信できないときに選んだ写真は端末に保存され、通信が戻ると自動でアップロードされます。アプリを閉じても失われません。\n'
                'アップロードが済むまで、写真の左上に雲の印が付きます。',
          ),
          Divider(),
          _SectionHeader(title: '写真の撮り方'),
          _HelpItem(
            question: '色の検索と比較を信頼できるものにするには',
            answer:
                '色は写真から読み取るので、撮り方が変わると同じ釉薬でも違う色として記録されます。\n'
                '撮影する場所・照明・角度を毎回同じにしてください。'
                'カメラの露出とホワイトバランスを固定できる場合は固定し、直射日光や色の付いた照明は避けてください。',
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
