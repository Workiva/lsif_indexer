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
  Set<LocalDeclaration> declarations = {};
  List<LocalReference> references = [];
  Set<ImportedDeclaration> externalDeclarations = {};
  List<ExternalReference> externalReferences = [];
  Set<PackageInformation> externalPackages = {};

  /// Add [declaration] to our list of local declarations, and
  /// return it or the already-present version if there was one.
  LocalDeclaration addDeclaration(LocalDeclaration declaration) =>
      declarations.addIfAbsent(declaration);

  /// Add [declaration] to our list of external declarations, and
  /// return it or the already-present version if there was one.
  ImportedDeclaration addExternal(ImportedDeclaration declaration) =>
      externalDeclarations.addIfAbsent(declaration);

  String line(int lineNumber) {
    _contentLines ??= content.split('\n');
    return _contentLines[lineNumber];
  }

  bool get isNotEmpty => !isEmpty;

  bool get isEmpty =>
      declarations.isEmpty &&
      references.isEmpty &&
      externalDeclarations.isEmpty &&
      externalReferences.isEmpty;

  @override
  DocumentContains get contains => DocumentContains(this);

  List<String> get definitionIds =>
      [for (var each in declarations) each.definition.jsonId];

  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'uri': '$uri',
        'languageId': 'dart',
      };

  /// Collect up the declarations, either ones we declare or ones we have references to
  /// and emit them, declarations first.
  ///
  /// For external references also make sure we're writing the package information for them.
  void emitReferencesAndDeclarations() {
    var groupedReferences =
        groupBy(references, (LocalReference ref) => ref.declaration);
    var externals =
        groupBy(externalReferences, (ExternalReference ref) => ref.declaration);
    // Make sure unreferenced declarations are included.
    // TODO: Tidy this up. We also may not have referenced things in declarations.
    for (var declaration in declarations) {
      groupedReferences.putIfAbsent(declaration, () => []);
    }
    for (var declaration in externalDeclarations) {
      externals.putIfAbsent(declaration, () => []);
    }
    groupedReferences.forEach(emitDeclarationWithReferences);
    Comment('Emitting external package information').emit();
    for (var package in externalPackages) {
      package.emit();
    }
    Comment('Done emitting external package information').emit();
    externals.forEach(emitDeclarationWithReferences);
  }

  /// Write out a [declaration] and all of the [references] to it, works for
  /// either local or external declarations.
  void emitDeclarationWithReferences(
      AbstractDeclaration declaration, List<Reference> references) {
    declaration.emit();

    /// Write out the reference.
    for (var reference in references) {
      reference.emit();
    }
    // TODO: We may need to have a single referenceResult per declaration
    // and collect them in the references item, but let's see if this works.
  }
}
