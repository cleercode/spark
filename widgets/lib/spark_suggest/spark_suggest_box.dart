// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.suggest;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_menu/spark_menu.dart';
import '../spark_overlay/spark_overlay.dart';

/**
 * A single suggestion supplied by a [SuggestOracle]. Provides a [label]
 * and an [onSelected] callback. [onSelected] is called when the user chooses
 * `this` suggestion.
 */
@reflectable
class Suggestion {
  String label;
  String details;

  Function onSelected;

  Suggestion(this.label, {String details, this.onSelected})
      : details = details.isNotEmpty ? "[$details]" : "";
}

/**
 * Source suggestions for spark-suggest-box. Implemented and supplied by the
 * component implementing a concrete suggest box.
 */
abstract class SuggestOracle {
  /**
   * [SparkSuggestBox] will call this method with [text] entered by user and
   * listen on returned [Stream] for suggestions. The stream may return
   * suggestions multiple times. This way if the suggestions are coming from
   * multiple sources they can be supplied incrementally. While the stream is
   * open the suggest-box will show a loading indicator as a cue for the user
   * that more suggestions may be received. It is up to the implementor to
   * close the stream after delivering all suggestions.
   */
  Stream<List<Suggestion>> getSuggestions(String text);
}

/**
 * A suggest component. See docs in `spark_suggest_box.html`.
 */
@CustomTag("spark-suggest-box")
class SparkSuggestBox extends SparkWidget {
  /// Text shown when the text box is empty.
  @published String placeholder;
  /// Provies suggestions for `this` suggest box.
  @published SuggestOracle oracle;
  /// Open state of the overlay.
  @published bool opened = false;

  /// Currently displayed suggestions.
  @observable final suggestions = new ObservableList();

  InputElement _textBox;
  SparkMenu _menu;
  SparkOverlay _overlay;

  StreamSubscription _oracleSub;

  SparkSuggestBox.created() : super.created();

  @override
  void ready() {
    super.ready();

    _textBox = $['text-box'];
    _menu = $['suggestion-list-menu'];
    _overlay = $['suggestion-list-overlay'];
  }

  /// Shows the suggestion list popup with the given suggestions.
  void _showSuggestions(List<Suggestion> update) {
    suggestions.clear();
    suggestions.addAll(update);
    toggle(true);
  }

  /// Hides the suggestion list popup and clears the suggestion list.
  void _hideSuggestions() {
    suggestions.clear();
    toggle(false);
  }

  void onInputKeyUp(KeyboardEvent e) {
    if (e.keyCode == SparkWidget.DOWN_KEY ||
        e.keyCode == SparkWidget.UP_KEY ||
        e.keyCode == SparkWidget.ENTER_KEY) {
      if (!opened) {
        suggest();
      }
    } else if (e.keyCode == SparkWidget.ESCAPE_KEY) {
      _textBox.value = "";
      _hideSuggestions();
    } else {
      suggest();
    }
  }

  void onInputFocused(Event e) {
    if (_textBox.value.length != 0) {
      suggest();
    }
  }

  void suggest() {
    _cleanupSubscriptions();
    _oracleSub = oracle.getSuggestions(_textBox.value)
        .listen((List<Suggestion> update) {
          if (update != null && update.isNotEmpty) {
            _showSuggestions(update);
          } else {
            _hideSuggestions();
          }
        }, onDone: _cleanupSubscriptions);
  }

  void _cleanupSubscriptions() {
    if (_oracleSub != null) {
      _oracleSub.cancel();
      _oracleSub = null;
    }
  }

  //* Toggle the opened state of the dropdown.
  void toggle([bool inOpened]) {
    final oldOpened = opened;
    opened = inOpened != null ? inOpened : !opened;
    if (opened != oldOpened) {
      _menu.clearSelection();
      // TODO(ussuri): A temporary plug to make spark-overlay see changes
      // in 'opened' when run as deployed code. Just binding via {{opened}}
      // alone isn't detected and the menu doesn't open.
      if (IS_DART2JS) {
        _overlay.opened = opened;
      }
    }
  }

  //* Handle the on-opened event from the dropdown. It will be fired e.g. when
  //* mouse is clicked outside the dropdown (with autoCloseDisabled == false).
  void onOverlayOpened(CustomEvent e) {
    // Autoclosing is the only event we're interested in.
    if (e.detail == false) {
      opened = false;
    }
  }

  void onMenuSelected(Event event, var detail) {
    if (detail['isSelected']) {
      final int index = int.parse(detail['value']);
      suggestions[index].onSelected();
      _hideSuggestions();
    }
  }
}
