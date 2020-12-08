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

import 'dart:io';
import 'package:lsif_indexer/analyzer.dart';

/// Generate LSIF information for the directory listed in the first [argument], or
/// the current directory if not specified.
///
/// Currently prints to standard out.
void main(List<String> arguments) async {
  // TODO: Allow specifying an output file.
  await Analyzer(arguments.isEmpty ? Directory.current.absolute.path : arguments.first)
      .analyzePackage();
}
