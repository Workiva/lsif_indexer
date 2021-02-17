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

import 'package:analyzer/src/generated/source.dart' show LineInfo;
import 'package:collection/collection.dart';
import 'package:lsif_indexer/lsif_graph.dart';

import 'utilities.dart';

/// The document entity in the LSIF graph.
class Document extends Scope {
  Project project;
  @override
  String get label => 'document';
  Document({this.uri, this.content, this.packageUri, this.lineInfo});
  Uri uri;
  Uri packageUri;
  String content;
  List<String> _contentLines;
  LineInfo lineInfo;
  Set<Declaration> declarations = {};
  List<LocalReference> references = [];
  Set<ExternalDeclaration> externalDeclarations = {};
  List<ExternalReference> externalReferences = [];

  /// Add [declaration] to our list of local declarations, and
  /// return it or the already-present version if there was one.
  Declaration addDeclaration(Declaration declaration) =>
      declarations.addIfAbsent(declaration);

  /// Add [declaration] to our list of external declarations, and
  /// return it or the already-present version if there was one.
  ExternalDeclaration addExternal(ExternalDeclaration declaration) =>
      externalDeclarations.addIfAbsent(declaration);

  String line(int lineNumber) {
    _contentLines ??= content.split('\n');
    return _contentLines[lineNumber];
  }

  @override
  Contains get contains => Contains(this);

  @override
  Map<String, Object> toLsif() =>
      {...super.toLsif(), 'uri': '$uri', 'languageId': 'dart'};

  emitReferenceStuff() {
    var groupedReferences =
        groupBy(references, (LocalReference ref) => ref.declaration);
    groupedReferences.forEach(emitDeclarationWithReferences);
  }

  void emitDeclarationWithReferences(
      AbstractDeclaration declaration, List<Reference> references) {
    declaration.emit();

    // For each declaration there is a referenceResult.
    var referenceResult = ReferenceResult()..emit();

    /// Write out the reference.
    for (var reference in references) {
      reference.emit(referenceResult);
      // ### moniker edge (moniker->reference range)
    }

    // Find the source range for each reference, and connect them to the referenceResult.
    var ranges = references.map((each) => each.range.jsonId).toList();
    var referenceItem = Item(this, 'references')
      ..inVs = ranges
      ..outV = referenceResult.jsonId;
    referenceItem.emit();

    /// ### Not used with imported
    // Similarly, there's one declaration range, connect it to the referenceResult.
    var definitionItem = Item(this, 'definitions')
      ..inVs = [declaration.range.jsonId]
      ..outV = referenceResult.jsonId;
    definitionItem.emit();

    // Connect the referenceResult to the declaration.
    (References()

          /// ### I think this is wrong. Should be per-reference.
          ..inV = referenceResult.jsonId
          ..outV = declaration.resultSet.jsonId)

        /// ### external it's the range
        .emit();

    /// For an external reference this connects to the range, for
    /// an internal one it's to the resultSet. Sigh.

    // Connect the resultSet to the declaration range.
    Next(declaration.resultSet.jsonId, declaration.range.jsonId).emit();
  }

  emitExternalReferenceStuff() {
    var groupedReferences =
        groupBy(externalReferences, (ExternalReference ref) => ref.declaration);
    groupedReferences.forEach(emitDeclarationWithReferences);
  }
  // doOtherStuff() {
  //   var groupedExternals = groupBy(document.externalReferences,
  //       (ExternalReference ref) => ref.declaration);
  //   for (var importMoniker in groupedExternals.keys) {
  //     importMoniker.emit(); // 22
  //     var referenceResult = ReferenceResult()..emit(); // 116
  //     var references = groupedExternals[importMoniker];
  //     for (var reference in references) {
  //       // 119, referenceLinks
  //       reference.emit(referenceResult);
  //     }

  //     // Ignore 'definitions' for the moment, that's for things like links from subclass overrides to the parent.
  //     // Connect the import to the reference ranges, via the referenceResult.
  //     var ranges = references.map((each) => each.range.jsonId).toList();
  //     var referenceItem = Item(document, 'references')
  //       ..outV = referenceResult.jsonId
  //       ..inVs = ranges;
  //     referenceItem.emit();
// ### 43 is the referenceResult. No it's not, that's 116.
  //     // Connect the referenceResult to the declaration.
  //     (References() // textdocument/references, 117
  //           ..inV = referenceResult.jsonId
  //           ..outV = importMoniker.resultSet.jsonId)
  //         .emit();

  //     /// ### need referenceResults - 118, points from referenceResult to 43.

  //     /// ##################
  //   }
  // }
}
