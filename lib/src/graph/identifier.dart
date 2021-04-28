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
import 'package:meta/meta.dart';

import 'utilities.dart';

/// Graph entities that have a particular place in the source -
/// currently [Reference]s and [LocalDeclaration]s.
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

/// An abstract class for both local and imported declarations.
abstract class AbstractDeclaration {
  void emit();
}

/// The declaration of anything - method, class, variable, getter, function, etc.
class LocalDeclaration extends Identifier implements AbstractDeclaration {
  LocalDeclaration({
    Document document,
    String name,
    int offset,
    int end,
    String docString,
    String declaration,
    this.location,
  }) : super(document, name, offset, end) {
    hoverResult = HoverResult(docString: docString, declaration: declaration);
    hover = Hover(hoverResult.jsonId, resultSet.jsonId);
  }

  /// The location in terms of the ElementLocation.encoding.
  ///
  /// The encoding is a String the analyzer gives us that should uniformly identify a reference. It
  /// seems to be of the form '<package:url>;<package:url>;identifier'. I don't know why
  /// the package is repeated - there may be cases where there are two different URLs there?
  String location;

  @override
  bool operator ==(Object other) {
    return super == other &&
        other is LocalDeclaration &&
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

  ExportedDeclaration _export;
  ExportedDeclaration get export =>
      _export ??= ExportedDeclaration(location, this);

  /// The name of the thing we're declaring, for convenience debugging.
  String get _debugName => range.source.name;

  /// Write out the LSIF entities for this declaration.
  @override
  void emit() {
    Comment('Emitting LocalDeclaration of [$_debugName]').emit();
    // The actual source definition.
    resultSet.emit();
    range.emit();
    Next(resultSet.jsonId, range.jsonId).emit();

    // Support textdocument/definition
    definitionResult.emit();
    // textdocument/definition, links from definitionResult to resultSet
    definition.emit();
    item.emit();

    hoverResult.emit();
    hover.emit();
    // Don't emit an export moniker for private identifiers.
    if (!name.startsWith('_')) {
      export.emit();
    }
    Comment('Done localDeclaration of [$_debugName]').emit();
  }
}

class HoverResult extends Vertex {
  @override
  String get label => 'hoverResult';

  /// The documentation string for the element associated to this hover. Can often be `null`.
  final String docString;

  /// The package for the element associated to this hover. Eg. package:lsif_indexer, dart:core
  /// Can be `null` (eg. for [LocalDeclaration])
  final String package;

  /// The declaration for the element associated to this hover.
  final String declaration;

  HoverResult({@required this.declaration, this.docString, this.package});

  /// Represents the hover result in the following format:
  /// packageName (eg. `package:lsif_indexer` or `dart:core`)
  /// -------------------------
  /// declaration (eg. `final String delclaration`)
  /// -------------------------
  /// docString (eg. `/// The declaration for the element associated to this hover.`)
  @override
  Map<String, Object> toLsif() {
    final hoverTexts = [package, declaration, docString];

    return {
      ...super.toLsif(),
      'result': {
        'contents': [
          for (final text in hoverTexts)
            if (text != null) {'language': 'dart', 'value': text}
        ],
      },
    };
  }
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

/// A reference to a declaration.
///
/// This only handles references within the same package (or maybe even just file?).
class LocalReference extends Identifier with Reference {
  LocalReference(
    Document document,
    String name,
    int offset,
    int end,
    this.declaration,
  ) : super(document, name, offset, end) {
    next = Next(declaration.resultSet.jsonId, range.jsonId);
  }

  LocalDeclaration declaration;
  Next next;

  @override
  References get textDocReferences => References()
    ..to = referenceResult.jsonId
    ..from = declaration.resultSet.jsonId;

  Item get definitionsItem => Item(document, 'definitions')
    ..to = [declaration.range.jsonId]
    ..from = referenceResult.jsonId;

  @override
  void emit() {
    Comment('Emitting LocalReference to [$name]').emit();
    super.emit();
    next.emit();
    definitionsItem.emit();
    Comment('Done LocalReference to [$name]').emit();
  }
}

/// An abstract class for both imported and local references, made a mixin
/// so that they can also inherit from [Identifier].
mixin Reference {
  void emit() {
    range.emit();
    referenceResult.emit();
    textDocReferences.emit();
    referenceItem.emit();
  }

  ReferenceResult referenceResult = ReferenceResult();

  Document get document;

  Range get range;

  References get textDocReferences;

  // TODO: It's possible that these should be combined for multiple references to the same thing.
  Item get referenceItem => Item(document, 'references')
    ..to = [range.jsonId]
    ..from = referenceResult.jsonId;
}

/// A reference to a declaration in a different package, via an import moniker.
class ExternalReference extends Identifier with Reference {
  ExternalReference(
      Document document, String name, int offset, int end, this.declaration)
      : moniker = ImportMoniker(declaration.identifier),
        super(document, name, offset, end);

  ImportedDeclaration declaration;

  ImportMoniker moniker;

  @override
  void emit() {
    Comment('Emitting imported reference to [$name]').emit();
    super.emit();
    moniker.emit();
    MonikerEdge(moniker.jsonId, range.jsonId).emit();
    PackageInformationEdge(
            moniker.jsonId, declaration.packageInformation.jsonId)
        .emit();
    Hover(declaration.hoverResult.jsonId, range.jsonId).emit();
    Comment('Done imported reference to [$name]').emit();
  }

  // This is extremely weird. An external reference seems to point from the reference range
  // to the referenceResult. But a local reference is from the declaration's resultSet.
  // I guess this is because an external declaration doesn't have a result set, but it
  // still seems weird.
  @override
  References get textDocReferences => References()
    ..to = referenceResult.jsonId
    ..from = range.jsonId;
}

abstract class Moniker extends Vertex {
  @override
  String get label => 'moniker';

  /// The identifier within the 'dart' scheme of this declaration.
  ///
  /// We expect this to correspond to the `encoding` string form of an ElementLocation
  /// in the Dart analyzer.
  String identifier;

  String get kind;

  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'scheme': 'dart',
        //    'unique': 'scheme',   # currently unused
        'kind': kind,
        'identifier': identifier
      };

  Moniker(this.identifier);
}

/// A declaration in another package.
class ImportedDeclaration extends AbstractDeclaration {
  ImportedDeclaration(
    this.identifier,
    this.packageUri,
    String hover,
    Document document,
    String declaration,
  ) {
    packageInformation =
        document.externalPackages.addIfAbsent(PackageInformation(packageUri));
    hoverResult = HoverResult(
      docString: hover,
      declaration: declaration,
      package: packageUri,
    );
  }

  HoverResult hoverResult;

  @override
  bool operator ==(Object other) =>
      other is ImportedDeclaration && other.identifier == identifier;

  @override
  int get hashCode => identifier.hashCode;

  String packageUri;

  PackageInformation packageInformation;

  /// This is only used to distinguish declarations
  String identifier;

  /// We emit nothing, we just act as a placeholder.
  @override
  void emit() {
    Comment('Emitting imported declaration').emit();
    hoverResult.emit();
    Comment('Done emitting imported declaration').emit();
  }
}

/// An exported declaration - corresponds to an export moniker.
class ExportedDeclaration extends Moniker {
  @override
  String get kind => 'export';

  Document get document => declaration.document;
  LocalDeclaration declaration;

  ExportedDeclaration(String identifier, this.declaration) : super(identifier);

  PackageInformationEdge get packageInformationEdge => PackageInformationEdge(
      jsonId, document.project.packageInformation.jsonId);

  MonikerEdge get monikerEdge =>
      MonikerEdge(jsonId, declaration.resultSet.jsonId);

  @override
  void emit() {
    Comment('Emitting export for [${declaration.name}]').emit();
    super.emit();
    packageInformationEdge.emit();
    monikerEdge.emit();
    Comment('Done export for [${declaration.name}]').emit();
  }
}

/// A reference to an external declaration.
///
/// This corresponds to a moniker import in the graph.
class ImportMoniker extends Moniker implements AbstractDeclaration {
  @override
  String get label => 'moniker';

  @override
  String get kind => 'import';
  String library;
  List<String> qualifiers;
  ImportMoniker(String identifier) : super(identifier);

  var resultSet = ResultSet();
}

/// LSIF has both vertices and edges named 'packageInformation', this is the
/// edge version, connecting the vertex to a moniker.
class PackageInformationEdge extends Edge {
  @override
  String get label => 'packageInformation';
  PackageInformationEdge(this.moniker, this.packageInformation);

  String moniker;
  String packageInformation;

  @override
  Map<String, Object> toLsif() =>
      {...super.toLsif(), 'outV': moniker, 'inV': packageInformation};
}

/// LSIF has both vertices and edges named 'moniker', this is the
/// edge version, connecting a moniker to a range.
class MonikerEdge extends Edge {
  @override
  String get label => 'moniker';
  MonikerEdge(this.moniker, this.range);

  String moniker;
  String range;

  @override
  Map<String, Object> toLsif() =>
      {...super.toLsif(), 'inV': moniker, 'outV': range};
}
