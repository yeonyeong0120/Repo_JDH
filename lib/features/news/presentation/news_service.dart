import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:repo_jdh/core/constants/api_config.dart';
import 'news_detail_screen.dart'; // NewsArticle 모델 재사용

/// 환경 뉴스 서비스 — FastAPI 서버(/news)를 호출한다.
///
/// 서버가 네이버 검색 API 를 대신 불러 정리된 뉴스를 준다.
/// (네이버 키는 서버에만 있고 앱은 모른다 → 안전)
class NewsService {
  // 서버 주소는 .env 의 FASTAPI_BASE_URL 사용 (지도/detect 와 동일 서버)
  static String get _baseUrl => ApiConfig.baseUrl;

  /// 환경 뉴스 목록을 가져온다.
  /// 실패 시 예외를 던진다 → 화면에서 에러 상태로 처리.
  static Future<List<NewsArticle>> fetchNews({
    String query = '환경 플로깅',
    int display = 10,
  }) async {
    if (_baseUrl.isEmpty) {
      throw Exception('서버 주소(FASTAPI_BASE_URL)가 설정되지 않았습니다');
    }

    // 예: http://12.34.56.78:8000/news?query=환경 플로깅&display=10
    final uri = Uri.parse('$_baseUrl/news').replace(queryParameters: {
      'query': query,
      'display': '$display',
    });

    debugPrint('[뉴스] 요청: $uri');

    try {
      // 서버가 네이버 호출 + Gemini 요약까지 하므로 응답이 느릴 수 있다.
      // (Gemini 보강이 붙으면서 8초로는 부족해 타임아웃이 발생했음)
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));

      debugPrint('[뉴스] 응답 코드: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        throw Exception('뉴스 요청 실패 (${resp.statusCode})');
      }

      // 한글 깨짐 방지: 응답을 UTF-8 로 디코딩
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final items = (data['articles'] as List?) ?? const [];

      debugPrint('[뉴스] 기사 ${items.length}건 수신');

      return items.map((e) => _toArticle(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // 실패 원인을 로그로 남긴다 (타임아웃/연결실패/파싱오류 구분용)
      debugPrint('[뉴스] 실패: $e');
      rethrow; // 화면이 에러 상태를 표시하도록 다시 던짐
    }
  }

  /// 서버 응답 1건 → NewsArticle 로 변환
  ///
  /// 서버는 title/summary/category/link/pubDate/imageUrl 을 주고,
  /// Gemini 보강이 성공하면 aiSummary(3줄 요약) · press(언론사 한글명)도 함께 준다.
  static NewsArticle _toArticle(Map<String, dynamic> json) {
    final title = (json['title'] as String?) ?? '';
    final summary = (json['summary'] as String?) ?? '';
    final link = (json['link'] as String?) ?? '';
    final pubDate = (json['pubDate'] as String?) ?? '';
    // 서버가 분류한 카테고리 (없으면 '환경')
    final category = (json['category'] as String?) ?? '환경';

    // 기사 대표 이미지 (서버가 원문의 og:image 로 채운다)
    // 없거나 수집 실패면 빈 문자열 → 화면 3곳이 이미지 자리를 통째로 생략한다
    final imageUrl = (json['imageUrl'] as String?) ?? '';

    // Gemini 3줄 요약 (실패 시 빈 배열 → 화면이 알아서 summary 로 대체)
    final aiSummary =
        ((json['aiSummary'] as List?) ?? const []).cast<String>();

    // 언론사 한글명 — Gemini 가 못 주면 링크 도메인으로 대체
    final press = (json['press'] as String?) ?? '';
    final sourceName = press.isNotEmpty ? press : _sourceFromUrl(link);

    return NewsArticle(
      category: category,
      title: title,
      summary: summary,
      reporter: sourceName,
      date: _formatDate(pubDate), // 'Wed, 29 Jul 2026 ...' → '2026.07.29'
      emoji: _emojiFor(category), // 카테고리에 맞는 아이콘
      body: summary.isEmpty ? const [] : [summary],
      sourceName: sourceName,
      sourceUrl: link, // 원문 보기용 링크
      aiSummary: aiSummary, // 있으면 상세 화면이 3줄로 표시
      imageUrl: imageUrl, // 있으면 목록·상세·홈 카드가 사진 표시
    );
  }

  /// 카테고리 → 아이콘(이모지) 매핑
  /// 서버의 카테고리 종류가 늘어나면 여기에 한 줄 추가하면 된다.
  static String _emojiFor(String category) {
    switch (category) {
      case '재활용':
        return '♻️';
      case '정책':
        return '📋';
      case '캠페인':
        return '🚶';
      case '생활':
        return '🌱';
      default:
        return '📰'; // '환경' 및 알 수 없는 분류
    }
  }

  // 링크 도메인에서 언론사 이름 대략 추출 (예: www.xxxnews.com → xxxnews)
  static String _sourceFromUrl(String url) {
    if (url.isEmpty) return '뉴스';
    try {
      final host = Uri.parse(url).host; // 예: 'www.hyunbulnews.com'
      final cleaned = host.replaceFirst('www.', '');
      final name = cleaned.split('.').first; // 'hyunbulnews'
      return name.isEmpty ? '뉴스' : name;
    } catch (_) {
      return '뉴스';
    }
  }

  // 네이버 pubDate('Wed, 29 Jul 2026 23:38:00 +0900') → '2026.07.29'
  static String _formatDate(String pubDate) {
    if (pubDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(_rfc822ToIso(pubDate));
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      return '${dt.year}.$mm.$dd';
    } catch (e) {
      debugPrint('[뉴스 날짜 파싱 실패] $pubDate → $e');
      return ''; // 실패해도 화면은 안 깨지게 빈 문자열
    }
  }

  // RFC822(네이버) → ISO8601 근사 변환
  // 'Wed, 29 Jul 2026 23:38:00 +0900' 형태를 DateTime.parse 가 읽게 바꿈
  static String _rfc822ToIso(String s) {
    const months = {
      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
      'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
      'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
    };
    // 'Wed, 29 Jul 2026 23:38:00 +0900'
    final parts = s.split(' ');
    if (parts.length < 5) throw const FormatException('예상 못한 날짜 형식');
    final day = parts[1].padLeft(2, '0');
    final month = months[parts[2]] ?? '01';
    final year = parts[3];
    final time = parts[4];
    return '$year-$month-${day}T$time'; // 2026-07-29T23:38:00
  }
}
