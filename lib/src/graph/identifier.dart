// Copyright 2020 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// --------------------------------------------------
//
// This lsif_indexer software is based on a number of software repositories with
// separate copyright notices and/or license terms. Your use of the source
// code for the these software repositories is subject to the terms and
// conditions of the following licenses:
//
// lsif-dart: https://github.com/sourcegraph/lsif-dart
// Copyright Anton Astashov. All rights reserved.
// Licensed under the BSD-2 Clause License: https://github.com/sourcegraph/lsif-dart/blob/master/LICENSE
//
// crossdart: https://github.com/astashov/crossdart
// Copyright Anton Astashov. All rights reserved.
// Licensed under the BSD-2 Clause License: https://github.com/astashov/crossdart/blob/master/LICENSE

import 'package:lsif_indexer/lsif_graph.dart';

/// Graph entities that have a particular place in the source -
/// currently [Reference]s and [Declaration]s.
abstract class Identifier {
  // TODO: Better name.
  Document document;
  String name;

  /// The character offset within the file.

  int offset;

  /// The character offset within the file of the end of this.
  int end;

  /// The source range.
  // TODO: Position information is duplicated in the range, get rid of it here?
  Range range;

  /// We put these in a Set to avoid duplicating declarations,
  /// so we need to make them hashable and have an equality operation.
  @override
  bool operator ==(Object other) =>
      other is Identifier &&
      other.document == document &&
      other.name == name &&
      other.offset == offset &&
      other.end == end;

  @override
  int get hashCode =>
      document.hashCode ^ name.hashCode ^ offset.hashCode ^ end.hashCode;

  /// The *one-based* line number containing this.
  int lineNumber;

  /// The *one-based* character position within the line
  int lineOffset;

  /// The *one-based* line number containing the end of this identifier.
  int endLineNumber;

  /// The *one-based* character position within the line of the end of this identifier.
  int endLineOffset;

  Identifier(this.document, this.name, this.offset, this.end) : super() {
    var location = document.lineInfo.getLocation(offset);
    lineNumber = location.lineNumber - 1;
    lineOffset = location.columnNumber - 1;
    var endLocation = document.lineInfo.getLocation(end);
    endLineNumber = endLocation.lineNumber - 1;
    endLineOffset = endLocation.columnNumber - 1;
    range = Range(this);
  }

  @override
  String toString() =>
      '{$runtimeType($name) at ${range.source.lineNumber}:${range.source.lineOffset}';
}

/// The declaration of anything - method, class, variable, getter, function, etc.
class Declaration extends Identifier {
  Declaration({
    Document document,
    String name,
    int offset,
    int end,
    String docString,
  }) : super(document, name, offset, end) {
    hoverText = docString == null ? sourceLineAsDoc : toMarkdown(docString);
    hoverResult = HoverResult(hoverText);
    hover = Hover(resultSet.jsonId, hoverResult.jsonId);
  }

  /// If there isn't a doc comment, we just use the source line converted loosely to markdown.
  String get sourceLineAsDoc => '```dart\n${document.line(lineNumber)}\n```';

  @override
  bool operator ==(Object other) {
    return super == other &&
        other is Declaration &&
        other.hoverText == hoverText;
  }

  @override
  int get hashCode => super.hashCode ^ hoverText.hashCode;

  String hoverText;
  Hover hover;
  HoverResult hoverResult;

  var resultSet = ResultSet();

  var definitionResult = DefinitionResult();

  Item _item;
  Item get item => _item ??= Item(document)
    ..outV = definitionResult.jsonId
    ..inVs = [range.jsonId];

  Definition _definition;
  Definition get definition => _definition ??= Definition()
    ..outV = resultSet.jsonId
    ..inV = definitionResult.jsonId;

  /// Write out the LSIF entities for this declaration.
  void emit() {
    range.emit();
    resultSet.emit();
    definitionResult.emit();
    item.emit();
    hoverResult.emit();
    definition.emit();
    hover.emit();
  }
}

class HoverResult extends Vertex {
  @override
  String get label => 'hoverResult';
  String hoverText;
  HoverResult(this.hoverText);

  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'result': {
          'contents': {'kind': 'markdown', 'value': hoverText}
        }
      };
}

class Hover extends Edge {
  @override
  String get label => 'textDocument/hover';
  String inV;
  String outV;
  Hover(this.inV, this.outV);
  @override
  Map<String, Object> toLsif() => {...super.toLsif(), 'inV': inV, 'outV': outV};
}

String toMarkdown(String docstring) {
  return docstring
      .replaceAll(RegExp(r'^/\*\*\n', multiLine: true), '')
      .replaceAll(RegExp(r'^/\*\* ', multiLine: true), '')
      .replaceAll(RegExp(r'^ \*$', multiLine: true), '')
      .replaceAll(RegExp(r'^ \* ', multiLine: true), '')
      .replaceAll(RegExp(r'\*/$', multiLine: true), '');
}

/// A reference to a declaration.
///
/// This only handles references within the same package (or maybe even just file?).
class Reference extends Identifier {
  Reference(
    Document document,
    String name,
    int offset,
    int end,
    this.declaration,
  ) : super(document, name, offset, end) {
    next = Next(declaration.resultSet.jsonId, range.jsonId);
  }

  Declaration declaration;
  Next next;

  void emit() {
    range.emit();
    next.emit();
  }
}
