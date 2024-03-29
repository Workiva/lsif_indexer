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

/// The entities within the LSIF graph.

import 'dart:collection';
import 'dart:convert';

import 'src/emitter.dart';
import 'src/graph/document.dart';
import 'src/graph/identifier.dart';
import 'src/graph/project.dart';

export 'src/graph/document.dart';
export 'src/graph/event.dart';
export 'src/graph/identifier.dart';
export 'src/graph/project.dart';

// TODO: Break these huge files up. One per class? Or something a little coarser?

/// An element in the graph model, either a vertex or an edge.
abstract class Element {
  // The id can be either a string or a number. If nothing is provided we auto-allocate numbers.
  Object _id;
  Object get id => _id ??= _nextId++;
  static int _nextId = 1;

  Element({Object id}) {
    // We can't use `this.id` because it won't let private fields be named arguments,
    // and we want id to be lazy.
    _id = id;
  }

  /// The ID as a String, which is what the JSON form seems to want.
  // TODO: Entities store this form - consider converting to a proper graph and getting the jsonId
  // when writing.
  String get jsonId => '$id';

  /// Convert this to a JSON representation.
  Map<String, Object> toLsif() => {'id': jsonId, 'type': type, 'label': label};

  void emit() {
    // TODO: Write in a more consistently useful order, e.g. ID first but then alphabetical?
    final alphabetical = SplayTreeMap<String, Object>()..addAll(toLsif());
    emitter.emit(json.encode(alphabetical));
  }

  @override
  String toString() => json.encode(toLsif());

  String get type;
  String get label;
}

/// A vertex in the graph.
abstract class Vertex extends Element {
  @override
  String get type => 'vertex';
}

/// An edge in the graph.
abstract class Edge extends Element {
  @override
  String get type => 'edge';
}

/// An element that contains other elements, i.e. a Project or a Document right now.
abstract class Scope extends Vertex {
  /// We expect this to be either a ProjectContains or a DocumentContains.
  // TODO: Consider an abstract class for these.
  Edge get contains;
}

/// A text range in the source code.
class Range extends Vertex {
  @override
  String get label => 'range';
  Identifier source;
  Range(this.source);
  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'start': {'line': source.lineNumber, 'character': source.lineOffset},
        'end': {
          'line': source.endLineNumber,
          'character': source.endLineOffset,
        },
        // Attributes that make it easier to read the emitted file but aren't used.
        '_debugName': source.name,
        '_debugContainingFile': '${source.document.packageUri}',
      };
}

/// Rather than connecting a [Range] directly to the various types of entities
/// it's related to (e.g. reference, definition, hover), we link ranges to single a
/// [ResultSet] that is then connected to the other entities.
class ResultSet extends Vertex {
  @override
  String get label => 'resultSet';
}

class DefinitionResult extends Vertex {
  @override
  String get label => 'definitionResult';
}

class ReferenceResult extends Vertex {
  @override
  String get label => 'referenceResult';
}

// TODO: Document what this is for.
class Next extends Edge {
  @override
  String get label => 'next';

  Next(this.inV, this.outV);
  String inV;
  String outV;
  @override
  Map<String, Object> toLsif() => {...super.toLsif(), 'inV': inV, 'outV': outV};
}

class Item extends Edge {
  @override
  String get label => 'item';

  Item(this.document, [this.property]) : super();
  String outV;
  List<String> inVs;

  /// Where the edge is coming from - equivalent, but much easier to read than outV.
  // TODO: Make these uniformly available.
  // TODO: Consider pushing inV/outV up to edge, but some of them have inVs/outVs, so
  // how do we allow for that?
  set from(String origin) => outV = origin;
  String get from => outV;

  /// Where the edge is coming from - equivalent, but much easier to read than inVs.
  set to(List<String> destinations) => inVs = destinations;
  List<String> get to => inVs;
  Document document;

  // An edge label, the only current usage is to distinguish
  // references/definitions.
  String property;

  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'outV': outV,
        'inVs': inVs,
        if (property != null) 'property': property,
        if (document != null) 'document': document.jsonId
      };
}

class Definition extends Edge {
  @override
  String get label => 'textDocument/definition';
  String outV;
  String inV;
  @override
  Map<String, Object> toLsif() => {...super.toLsif(), 'outV': outV, 'inV': inV};
}

class References extends Edge {
  @override
  String get label => 'textDocument/references';
  String from;
  String to;
  @override
  Map<String, Object> toLsif() => {...super.toLsif(), 'outV': from, 'inV': to};
}

/// Describes the metadata for the whole project.
class Metadata extends Element {
  @override
  String get type => 'vertex';
  @override
  String get label => 'metaData';

  String projectRoot;

  Metadata(this.projectRoot);

  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'projectRoot': projectRoot,
        'version': '0.4.3',
        'positionEncoding': 'utf-16',
        'toolInfo': toolInfo,
      };

  Map<String, Object> get toolInfo => {
        'name': 'lsif_indexer',
        'args': [],
        'version': 'dev',
      };
}

/// A "contains" edge specifically for a [Document], which contains references and declarations.
class DocumentContains extends Edge {
  @override
  String get label => 'contains';

  DocumentContains(this.container);

  Document container;

  @override
  Map<String, Object> toLsif() =>
      {...super.toLsif(), 'outV': container.jsonId, 'inVs': incomingEdges};

  // TODO: Tidy this up, and the semantics of when things are added to declarations. See
  // emitReferencesAndDeclarations in Document, where we push things into the references
  // from declarations, but not vice versa.
  List<String> get incomingEdges => {
        for (var ref in container.references) ref.range.jsonId,
        for (var ref in container.externalReferences) ref.range.jsonId,
        for (var declaration in container.declarations)
          declaration.range.jsonId,
        for (var ref in container.references) ref.declaration.range.jsonId,
      }.toList();
}

/// A "contains" edge specifically for a [Project], which contains [Document]s
class ProjectContains extends Edge {
  @override
  String get label => 'contains';

  ProjectContains(this.project);

  Project project;

  @override
  Map<String, Object> toLsif() =>
      {...super.toLsif(), 'outV': project.jsonId, 'inVs': incomingEdges};

  List<String> get incomingEdges =>
      project.nonEmptyDocuments.map((each) => each.jsonId).toList();
}

/// A comment, to make reading the file easier.
///
/// This is ignored by Sourcegraph. Note that lsif-validate will complain
/// about these as unreachable, but that can be ignored.
class Comment extends Element {
  String text;
  Comment(this.text);

  @override
  String get label => '';

  @override
  String get type => 'vertex';

  @override
  Map<String, Object> toLsif() => {...super.toLsif(), '-----Comment': text};
}
