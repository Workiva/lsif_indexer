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

import 'package:args/args.dart';
import 'package:meta/meta.dart';

/// The resulting config of parsing arguments for the lsif_indexer program.
class LsifDartConfig {
  /// All arguments that are either options (eg. -o file.ext) or flags (eg. -h).
  final Map<String, dynamic> options;

  /// All arguments provided after [options].
  final List<String> rest;

  /// If the command line arguments are valid.
  final bool isValid;

  const LsifDartConfig(this.options, this.rest, {this.isValid = true});

  /// The provided output destination to store the LSIF results in. Can be `null`.
  String get output => _valueForItem(Config.output);

  /// The provided project root for analysis. Can be `null`.
  String get projectRoot => _valueForItem(Config.projectRoot);

  String _valueForItem(_ConfigItem item) => options[item.name];
}

class LsifDartArgumentParser {
  final ArgParser _argParser;

  LsifDartArgumentParser() : _argParser = ArgParser() {
    _argParser.addItems(Config.all);
  }

  LsifDartConfig parse(List<String> arguments) {
    final argResult = _argParser.parse(arguments);

    if (argResult['help'] == true) {
      _showHelp();
      return LsifDartConfig({}, [], isValid: false);
    }

    final options = argResult.options.fold(
      <String, dynamic>{},
      (accumulator, option) {
        accumulator[option] = argResult[option];
        return accumulator;
      },
    );

    return LsifDartConfig(options, argResult.rest);
  }

  void _showHelp([String errorMessage]) {
    print(
      'LSIF Dart Indexer - A Dart language server index format generator.\n',
    );
    print(
      'lsif_indexer.dart analyzes all the files of the given project, '
      'and stores the analyze information in the specified file.',
    );

    if (errorMessage != null) {
      print('$errorMessage\n');
    }

    print('Available options:');
    print(_argParser.usage);
    print('Optionally provide a list of files to filter the analysis');
    print('Eg. pub global run lsif_indexer a.dart b.dart c.dart');
  }
}

/// The base of anything configurable (options, flags).
abstract class _ConfigItem<T> {
  final String name;
  final String help;
  final String abbreviation;
  final T defaultsTo;

  const _ConfigItem({
    @required this.name,
    this.help,
    this.abbreviation,
    this.defaultsTo,
  });
}

/// An option configuration value.
///
/// Example: -o <path/to/output.extension>
class _ConfigOption extends _ConfigItem<String> {
  const _ConfigOption({
    @required String name,
    String help,
    String abbreviation,
    String defaultsTo,
  }) : super(
          name: name,
          help: help,
          abbreviation: abbreviation,
          defaultsTo: defaultsTo,
        );
}

/// A flag configuration value.
///
/// Example: -h (true or false)
class _ConfigFlag extends _ConfigItem<bool> {
  final bool negatable;

  const _ConfigFlag({
    @required String name,
    String help,
    String abbreviation,
    this.negatable = true,
    bool defaultsTo = false,
  }) : super(
          name: name,
          help: help,
          abbreviation: abbreviation,
          defaultsTo: defaultsTo,
        );
}

class Config {
  static const help = _ConfigFlag(
    name: 'help',
    help: 'Show this message',
    abbreviation: 'h',
    negatable: false,
  );
  static const output = _ConfigOption(
    name: 'output',
    help: 'The output file\n(defaults to standard output)',
    abbreviation: 'o',
  );
  static const projectRoot = _ConfigOption(
    name: 'root',
    help: 'The project root input\n(defaults to the current directory)',
    abbreviation: 'r',
  );

  static List<_ConfigItem> get all {
    return [help, output, projectRoot]
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}

extension _ArgParserConfig on ArgParser {
  void addItem(_ConfigItem item) {
    if (item is _ConfigOption) {
      addOption(
        item.name,
        help: item.help,
        abbr: item.abbreviation,
        defaultsTo: item.defaultsTo,
      );
    } else if (item is _ConfigFlag) {
      addFlag(
        item.name,
        help: item.help,
        abbr: item.abbreviation,
        negatable: item.negatable,
        defaultsTo: item.defaultsTo,
      );
    }
  }

  void addItems(List<_ConfigItem> items) => items.forEach(addItem);
}
