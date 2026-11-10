/// 日付を「2026/11/8」の形に整える (月日はゼロ埋めしない)。
String formatDate(DateTime date) => '${date.year}/${date.month}/${date.day}';
