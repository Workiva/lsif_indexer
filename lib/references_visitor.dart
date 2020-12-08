// Copyright 2020 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'package:lsif_indexer/lsif_graph.dart' as lsif;

/// Visits the AST and constructs an [lsif.Document] with the [Reference]s and [Declaration]s found.
class ReferencesVisitor extends GeneralizingAstVisitor<void> {
// TODO: Be able to follow imports.
// TODO: Do prefixed references work? Probably only relevant in cross-package references

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
      createReference(referenceNode: node, staticElement: element);
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

  /// The declaring element, which may be the same as [element]
  Element declaringElement(Element element) {
    var node = declaringNode(element);
    if (node == null && element is PropertyAccessorElement) {
      return element.variable;
    } else if (node == null && element is FieldFormalParameterElement) {
      return element.field;
    } else {
      return element;
    }
  }

  /// The node for the declaration of [element].
  AstNode declaringNode(Element element) {
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
      return declarationNode.name;
    } on NoSuchMethodError {} // ignore
    return declarationNode;
  }

  /// Create a [Reference] and [Declaration] for referenceNode and its definition.
  void createReference({SimpleIdentifier referenceNode, Element staticElement}) {
    var declarationElement = declaringElement(staticElement);
    var declarationNode = declaringNode(declarationElement);

    /// Create a reference and the corresponding declaration if it doesn't already exist.
    if (declarationNode is Declaration && !referenceNode.inDeclarationContext()) {
      var canonical;
      if (declarationElement.source.uri == document.packageUri) {
        declarationNode = narrow(declarationNode);
        var declaration = lsif.Declaration(
            document: document,
            name: declarationElement.displayName,
            offset: declarationNode.offset,
            end: declarationNode.end,
            docString: declarationElement.documentationComment);

        canonical = document.declarations.lookup(declaration);
        if (canonical == null) {
          document.declarations.add(declaration);
          canonical = declaration;
        }
      }
      // Add the reference if the declaration is in this document.
      // TODO: Cross-document references!!
      if (canonical != null) {
        var reference = lsif.Reference(document, staticElement.displayName, referenceNode.offset,
            referenceNode.end, canonical);
        document.references.add(reference);
      }
    }
  }
}
