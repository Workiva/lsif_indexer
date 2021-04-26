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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:lsif_indexer/lsif_graph.dart' as lsif;

import 'src/graph/utilities.dart';

/// Visits the AST and constructs an [lsif.Document] with the [Reference]s and [Declaration]s found.
class ReferencesVisitor extends GeneralizingAstVisitor<void> {
// TODO: Be able to follow imports.
// TODO: Do prefixed references work? Probably only relevant in cross-package references
// TODO: Link inherited/implemented members. The deprecatalog visitor may be useful to
// look at.

  ReferencesVisitor(this.document);

  /// The document being constructed.
  lsif.Document document;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);

    var element = elementFor(node);

    // TODO: What about the case of declarations here that are only referenced elsewhere?
    // Would visitDeclaredIdentifier or visitDeclaredElement work for that?
    if (element != null && element.library != null) {
      AstReference(document, node, element).note();
    }
  }

  /// Find the element that [node] refers to.
  Element elementFor(SimpleIdentifier node) {
    if (node.staticElement != null) return node.staticElement;
    // For some expressions there isn't a single static element, but could be separate read and write.
    if (node.parent is CompoundAssignmentExpression) {
      // Shouldn't the type be inferred here, so the cast wouldn't be required??
      var assignmentNode = node.parent as CompoundAssignmentExpression;
      return assignmentNode.readElement ?? assignmentNode.writeElement;
    }
    return null;
  }
}

/// A specific reference in the source.
class AstReference {
  lsif.Document document;
  SimpleIdentifier node;
  Element element;

  AstReference(this.document, this.node, this.element);

  void note() {
    // Check if it's a declaration, not a reference.
    // TODO: We are ignoring import prefixes right now - fix.
    if (node.inDeclarationContext() && declaringElement is! PrefixElement) {
      _declare(node);
    } else {
      checkForLocalReference();
      checkForExternalReference();
    }
  }

  void checkForLocalReference() {
    if (declaringNode is! Declaration) {
      return;
    }

    if (localDeclaration != null) {
      var reference = lsif.LocalReference(document, element.displayName,
          node.offset, node.end, localDeclaration);
      document.references.add(reference);
    }
  }

  void checkForExternalReference() {
    var declaration = externalDeclarationFor(declaringElement);
    if (declaration != null) {
      document.addExternal(declaration);
      var reference = lsif.ExternalReference(
          document, element.displayName, node.offset, node.end, declaration);
      document.externalReferences.add(reference);
    }
  }

  lsif.LocalDeclaration _localDeclaration;
  lsif.LocalDeclaration get localDeclaration =>
      _localDeclaration ??= _findLocalDeclaration();

  lsif.LocalDeclaration _findLocalDeclaration() {
    if (!_isLocal(declaringElement)) return null;

    return _declare(declaringNode);
  }

  lsif.LocalDeclaration _declare(AstNode node) {
    var narrowed = narrow(node);
    var declaration = lsif.LocalDeclaration(
        document: document,
        name: declaringElement.displayName,
        offset: narrowed.offset,
        end: narrowed.end,
        docString: declaringElement.documentationComment,
        location: declaringElement.location.encoding);

    return document.addDeclaration(declaration);
  }

  Element _declaringElement;
  Element get declaringElement => _declaringElement ??= _findDeclaringElement();

  /// The declaring element, which may be the same as [element]
  Element _findDeclaringElement() {
    if (declaringNode == null && element is PropertyAccessorElement) {
      return (element as PropertyAccessorElement).variable;
    } else if (node == null && element is FieldFormalParameterElement) {
      return (element as FieldFormalParameterElement).field;
    } else {
      return element;
    }
  }

  AstNode _declaringNode;
  AstNode get declaringNode => _declaringNode ??= _findDeclaringNode();

  /// The node for the declaration of [element].
  AstNode _findDeclaringNode() {
    var session = element.session;
    var parsedLib = session.getParsedLibraryByElement(element.library);
    // This can be various sorts of declaration, but they all have a `node`.
    dynamic declaration = parsedLib.getElementDeclaration(element);
    return declaration?.node;
  }

  /// Attempt to narrow the range of the declaration to just its name, if it has one.
  ///
  /// The whole declaration can be large, including e.g. annotations, so we use the name
  /// if possible. But some things like DefaultFormalParameter don't have names.
  AstNode narrow(dynamic declarationNode) {
    // If this has a name, use just the name, not the whole declaration which
    // even includes annotations. But things like DefaultFormalParameter don't have a name,
    // so use the whole thing. Use a try/catch to avoid explicitly listing all the different
    // possibilities.
    try {
      var name = declarationNode.name;
      if (name is AstNode) {
        return name;
      }
    } on NoSuchMethodError {} // ignore
    return declarationNode;
  }

  /// Is this element part of the current library.
  // TODO: I don't think this is right. We are treating references from other libraries
  // in the same package as cross-package references. I think it works, but we should probably avoid.
  bool _isLocal(Element element) => element.source.uri == document.packageUri;

  /// Does this element come from the Dart SDK.
  bool _isSdk(Element element) => element.library.identifier.startsWith('dart');

  lsif.ImportedDeclaration externalDeclarationFor(Element element) {
    final packagePrefix = _isSdk(element) ? 'dart' : 'package';

    final packageName =
        Uri.parse(element.library.identifier).pathSegments.first;

    var hover =
        element.documentationComment ?? element.getExtendedDisplayName(null);
    // TODO: Is the assumption that the package follows this form correct? It won't be for
    // SDK references or special Dart URI schemes for non-lib references.
    var declaration = lsif.ImportedDeclaration(
      element.location.encoding,
      '$packagePrefix:$packageName',
      hover,
      document,
    );
    return document.externalDeclarations.addIfAbsent(declaration);
  }
}
