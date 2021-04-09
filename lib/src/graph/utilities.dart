extension SetUtilities<T> on Set {
  /// Add [element] if we don't already have an equal
  /// member, and return either [element] or the existing member.
  T addIfAbsent(T element) {
    var existing = lookup(element);
    if (existing == null) {
      add(element);
      return element;
    } else {
      return existing;
    }
  }
}
