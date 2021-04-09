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

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:lsif_indexer/lsif_graph.dart' as lsif;
import 'package:lsif_indexer/lsif_generator.dart';
import 'package:lsif_indexer/references_visitor.dart';

/// Analysis results for a package.
class Analyzer {
  Analyzer(this.packageRoot) {
    ready = initialize();
  }

  String packageRoot;
  Directory _packageDir;
  Directory get packageDir => _packageDir ??= Directory(packageRoot).absolute;
  String get packageDirAsUriString => Uri.file(packageDir.path).toString();

  /// Are the analysis results ready for use.
  Future<void> ready;

  List<lsif.Document> documents;

  PackageConfig packages;

  AnalysisContext context;

  String get libPath =>   p.join(packageDir.path, 'lib');

  Future<void> initialize() async {
    // This is split out into a separate method because constructors can't return a Future.
    // So the constructor calls this and sets a [ready] variable.
    packages = await findPackageConfig(packageDir);
    var allPackageRoots = packages.packages
        .map((each) => p.normalize(each.packageUriRoot.toFilePath()))
        .toList();
    var collection = AnalysisContextCollection(includedPaths: allPackageRoots);
    context = collection.contextFor(libPath);
  }

  /// Find all .dart files in the package [directory] and write an LSIF file for them.
  Future<void> analyzePackage() async {
    // TODO: Index files in non-lib directories
    await ready;
    var files = context.contextRoot
        .analyzedFiles()
        .where((each) => p.extension(each) == '.dart');
    documents = await Future.wait(files.map(analyzeFile).toList());
    writeProject(packageDirAsUriString, documents);
  }

  /// Analyze and individual file and create a document with all its references and declarations.
  Future<lsif.Document> analyzeFile(String path) async {
    var resolved = await context.currentSession.getResolvedUnit(path);
    var fileUri = Uri.file(path);
    var document = lsif.Document(
        content: resolved.content,
        uri: fileUri,
        packageUri: packages.toPackageUri(fileUri),
        lineInfo: resolved.lineInfo);
    var visitor = ReferencesVisitor(document);
    resolved.unit.accept(visitor);
    return document;
  }
}
