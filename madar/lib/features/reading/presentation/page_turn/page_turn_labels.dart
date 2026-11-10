/// The words the page turn needs for screen readers. The widget has no
/// strings of its own: the caller passes the localised ones.
class PageTurnLabels {
  const PageTurnLabels({
    required this.nextPage,
    required this.previousPage,
    required this.pageStatus,
  });

  /// Custom action: go to the next page («الصفحة التالية»).
  final String nextPage;

  /// Custom action: go back («الصفحة السابقة»).
  final String previousPage;

  /// What is announced after each turn, from the 1-based page number and the
  /// total: «صفحة 3 من 120».
  final String Function(int page, int total) pageStatus;
}
