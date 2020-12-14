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


import 'package:collection/collection.dart';

import 'lsif_graph.dart';

/// Write out a project based at [projectRoot] containing [documents].
///
/// The actual understanding of the LSIF format is in the graph entities.
void writeProject(String projectRoot, List<Document> documents) {
  Metadata(projectRoot).emit();
  _within(Project(documents), _emitProject);
}

/// Perform the operation [doThis] between the begin/end events of [scope].
void _within<T extends Scope>(T scope, void Function(T scope) doThis) {
  scope.emit();
  BeginEvent(scope).emit();
  doThis(scope);
  EndEvent(scope).emit();
  scope.contains?.emit();
}

void _emitProject(Project p) {
  for (var document in p.documents) {
    _within(document, _emitDocument);
  }
}

void _emitDocument(Document document) {
  // TODO: Organize this better.
  var groupedReferences = groupBy(document.references, (Reference ref) => ref.declaration);
  for (var declaration in document.declarations) {
    declaration.emit();
    var references = groupedReferences[declaration];
    var referenceResult = ReferenceResult()..emit();
    for (var reference in references) {
      reference.emit();
    }
    var ranges = references.map((each) => each.range.jsonId).toList();
    var referenceItem = Item(document, 'references')
      ..outV = referenceResult.jsonId
      ..inVs = ranges;
    referenceItem.emit();
    var definitionItem = Item(document, 'definitions')
      ..inVs = [declaration.range.jsonId]
      ..outV = referenceResult.jsonId;
    definitionItem.emit();
    (References()
          ..inV = referenceResult.jsonId
          ..outV = declaration.resultSet.jsonId)
        .emit();
    Next(declaration.resultSet.jsonId, declaration.range.jsonId).emit();
  }
}
