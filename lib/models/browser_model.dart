import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_browser/Db/hive_db_helper.dart';
import 'package:flutter_browser/models/web_archive_model.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'package:flutter_browser/rss_news/models/website_list.dart';
import 'package:flutter_browser/rss_news/services/whitelist.dart';
import 'package:flutter_browser/rss_news/utils/debug.dart';
import 'package:flutter_browser/rss_news/utils/show_snackbar.dart';
import 'package:flutter_browser/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_browser/util.dart';
import 'package:window_manager_plus/window_manager_plus.dart';
import '../main.dart';
import 'web_archive_model.dart';
import 'window_model.dart';
import 'favorite_model.dart';
import 'search_engine_model.dart';
import 'package:collection/collection.dart';

class BrowserSettings {
  SearchEngineModel searchEngine;
  bool homePageEnabled;
  String customUrlHomePage;
  bool debuggingEnabled;
  bool adsDisabled;
  bool immersiveReaderEnabled;
  String geminiApiKey;

  BrowserSettings({
    this.searchEngine = GoogleSearchEngine,
    this.homePageEnabled = false,
    this.customUrlHomePage = "",
    this.debuggingEnabled = false,
    this.adsDisabled = true,
    this.immersiveReaderEnabled = false,
    this.geminiApiKey = "",
  });

  BrowserSettings copy() {
    return BrowserSettings(
        searchEngine: searchEngine,
        homePageEnabled: homePageEnabled,
        customUrlHomePage: customUrlHomePage,
        debuggingEnabled: debuggingEnabled,
        adsDisabled: adsDisabled,
        immersiveReaderEnabled: immersiveReaderEnabled,
        geminiApiKey: geminiApiKey);
  }

  static BrowserSettings? fromMap(Map<String, dynamic>? map) {
    return map != null
        ? BrowserSettings(
            searchEngine: SearchEngines[map["searchEngineIndex"]],
            homePageEnabled: map["homePageEnabled"],
            customUrlHomePage: map["customUrlHomePage"],
            debuggingEnabled: map["debuggingEnabled"],
            adsDisabled: map["adsDisabled"],
            immersiveReaderEnabled: map["immersiveReaderEnabled"],
            geminiApiKey: map["geminiApiKey"],
          )
        : null;
  }

  Map<String, dynamic> toMap() {
    return {
      "searchEngineIndex": SearchEngines.indexOf(searchEngine),
      "homePageEnabled": homePageEnabled,
      "customUrlHomePage": customUrlHomePage,
      "debuggingEnabled": debuggingEnabled,
      "adsDisabled": adsDisabled,
      "immersiveReaderEnabled": immersiveReaderEnabled,
      "geminiApiKey": geminiApiKey
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

class BrowserModel extends ChangeNotifier {
  final List<FavoriteModel> _favorites = [];
  final Map<String, WebArchiveModel> _webArchives = {};
  BrowserSettings _settings = BrowserSettings();
  bool _showTabScroller = false;
  bool _homePage = true;
  List<WebViewTab> _webViewTabs = [];
  int _currentTabIndex = -1;
  WebViewModel _currentWebViewModel = WebViewModel();

  bool get showTabScroller => _showTabScroller;

  set showTabScroller(bool value) {
    if (value != _showTabScroller) {
      _showTabScroller = value;
      notifyListeners();
    }
  }

  BrowserModel();

  UnmodifiableListView<FavoriteModel> get favorites =>
      UnmodifiableListView(_favorites);

  UnmodifiableMapView<String, WebArchiveModel> get webArchives =>
      UnmodifiableMapView(_webArchives);
      
  bool get homePage => _homePage;
  
  set homePage(bool value) {
    if (value != _homePage) {
      _homePage = value;
      notifyListeners();
    }
  }

  

  void addTab(WebViewTab webViewTab) {
    // Use the Whitelist.isWebsiteAllowed method for consistent validation
    if (webViewTab.webViewModel.url != null) {
      if (!Whitelist.isWebsiteAllowed(webViewTab.webViewModel.url!)) {
        showSnackBar(message: "This website is not allowed");
        return;
      }
    }
    
    _homePage = true;
    _webViewTabs.add(webViewTab);
    _currentTabIndex = _webViewTabs.length - 1;
    webViewTab.webViewModel.tabIndex = _currentTabIndex;
    _currentWebViewModel.updateWithValue(webViewTab.webViewModel);
    notifyListeners();
  }
  
  void addTabs(List<WebViewTab> webViewTabs) {
    _homePage = true;
    for (var webViewTab in webViewTabs) {
      _webViewTabs.add(webViewTab);
      webViewTab.webViewModel.tabIndex = _webViewTabs.length - 1;
    }
    _currentTabIndex = _webViewTabs.length - 1;
    if (_currentTabIndex >= 0) {
      _currentWebViewModel.updateWithValue(webViewTabs.last.webViewModel);
    }

    notifyListeners();
  }

  Future<void> closeTab(int index) async {
    final webViewTab = _webViewTabs[index];
    _webViewTabs.removeAt(index);
    InAppWebViewController.disposeKeepAlive(webViewTab.webViewModel.keepAlive);

    _currentTabIndex = _webViewTabs.length - 1;

    for (int i = index; i < _webViewTabs.length; i++) {
      _webViewTabs[i].webViewModel.tabIndex = i;
    }

    // Only try to create window on desktop platforms
    if (Util.isDesktop()) {
      // Need to reference the window model correctly
      final windowModelId = Util.isDesktop() ? WindowManagerPlus.current.id.toString() : null;
      final window = await WindowManagerPlus.createWindow(windowModelId != null ? [windowModelId] : null);
      if (window != null) {
        if (kDebugMode) {
          print("Window created: $window}");
        }
      } else {
        if (kDebugMode) {
          print("Cannot create window");
        }
      }
    }

    notifyListeners();
  }

  Future<void> removeWindow(WindowModel window) async {
    await window.removeInfo();
  }

  void closeAllTabs() {
    for (final webViewTab in _webViewTabs) {
      InAppWebViewController.disposeKeepAlive(
          webViewTab.webViewModel.keepAlive);
    }
    _webViewTabs.clear();
    _currentTabIndex = -1;
    _currentWebViewModel.updateWithValue(WebViewModel());

    notifyListeners();
  }

  void openEmptyTab() {
    _homePage = false;
    notifyListeners();
  }

  int getCurrentTabIndex() {
    return _currentTabIndex;
  }

  WebViewTab? getCurrentTab() {
    return _currentTabIndex >= 0 ? _webViewTabs[_currentTabIndex] : null;
  }

  bool containsFavorite(FavoriteModel favorite) {
    return _favorites.contains(favorite) ||
        _favorites
                .map((e) => e)
                .firstWhereOrNull((element) => element.url == favorite.url) !=
            null;
  }

  void addFavorite(FavoriteModel favorite) {
    _favorites.add(favorite);
    notifyListeners();
  }

  void addFavorites(List<FavoriteModel> favorites) {
    _favorites.addAll(favorites);
    notifyListeners();
  }

  void clearFavorites() {
    _favorites.clear();
    notifyListeners();
  }

  void removeFavorite(FavoriteModel favorite) {
    if (!_favorites.remove(favorite)) {
      var favToRemove = _favorites
          .map((e) => e)
          .firstWhereOrNull((element) => element.url == favorite.url);
      _favorites.remove(favToRemove);
    }

    notifyListeners();
  }

  void addWebArchive(String url, WebArchiveModel webArchiveModel) {
    _webArchives.putIfAbsent(url, () => webArchiveModel);
    notifyListeners();
  }

  void addWebArchives(Map<String, WebArchiveModel> webArchives) {
    _webArchives.addAll(webArchives);
    notifyListeners();
  }

  void removeWebArchive(WebArchiveModel webArchive) {
    var path = webArchive.path;
    if (path != null) {
      final webArchiveFile = File(path);
      try {
        webArchiveFile.deleteSync();
      } finally {
        _webArchives.remove(webArchive.url.toString());
      }
      notifyListeners();
    }
  }

  void clearWebArchives() {
    _webArchives.forEach((key, webArchive) {
      var path = webArchive.path;
      if (path != null) {
        final webArchiveFile = File(path);
        try {
          webArchiveFile.deleteSync();
        } finally {
          _webArchives.remove(key);
        }
      }
    });

    notifyListeners();
  }

  BrowserSettings getSettings() {
    return _settings.copy();
  }

  void updateSettings(BrowserSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  Future<List<WindowModel>> getWindows() async {
    final List<WindowModel> windows = [];
    final windowsMap = await db?.rawQuery('SELECT * FROM windows');
    if (windowsMap == null) {
      return windows;
    }

    for (final w in windowsMap) {
      final wId = w['id'] as String;
      if (wId.startsWith('window_')) {
        final source = w['json'] as String;
        Map<String, dynamic> wBrowserData = json.decode(source);
        windows.add(WindowModel.fromMap(wBrowserData));
      }
    }

    return windows;
  }

  DateTime _lastTrySave = DateTime.now();
  Timer? _timerSave;

  Future<void> save() async {
    _timerSave?.cancel();

    if (DateTime.now().difference(_lastTrySave) >=
        const Duration(milliseconds: 400)) {
      _lastTrySave = DateTime.now();
      await flush();
    } else {
      _lastTrySave = DateTime.now();
      _timerSave = Timer(const Duration(milliseconds: 500), () {
        save();
      });
    }
  }

  Future<void> openWindow(dynamic window) async {
  if (window == null) {
    // Create a new window
    final settings = getSettings();
    final url = settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);
    
    // Check if we're on desktop platform
    if (Util.isDesktop()) {
      try {
        final windowId = Random().nextInt(1000).toString();
        final newWindow = await WindowManagerPlus.createWindow(['window_$windowId']);
        if (newWindow != null) {
          debugPrint("New window created: $newWindow");
        }
      } catch (e) {
        debugPrint("Error creating window: $e");
      }
    } else {
      // For mobile, create a new tab instead of a window
      final newTab = WebViewTab(
        key: GlobalKey(),
        webViewModel: WebViewModel(url: url),
      );
      addTab(newTab);
    }
  } else {
    // Open existing window (window is a WindowModel object)
    try {
      // Restore the window state
      final windowModel = window as WindowModel;
      
      // Clear existing tabs
      closeAllTabs();
      
      // Add the tabs from the saved window
      if (windowModel.webViewTabs.isNotEmpty) {
        addTabs(windowModel.webViewTabs);
      } else {
        // If no tabs, add a default one
        final settings = getSettings();
        final url = settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
            ? WebUri(settings.customUrlHomePage)
            : WebUri(settings.searchEngine.url);
            
        addTab(WebViewTab(
          key: GlobalKey(),
          webViewModel: WebViewModel(url: url),
        ));
      }
      
      // Notify that window has been opened
      notifyListeners();
    } catch (e) {
      debugPrint("Error opening saved window: $e");
    }
  }
}

  Future<void> flush() async {
    final browser =
        await db?.rawQuery('SELECT * FROM browser WHERE id = ?', [1]);
    int? count;
    if (browser == null || browser.length == 0) {
      count = await db?.rawInsert('INSERT INTO browser(id, json) VALUES(?, ?)',
          [1, json.encode(toJson())]);
    } else {
      count = await db?.rawUpdate('UPDATE browser SET json = ? WHERE id = ?',
          [json.encode(toJson()), 1]);
    }

    if ((count == null || count == 0) && kDebugMode) {
      print("Cannot insert/update browser 1");
    }
  }

  Future<void> restore() async {
    final browsers =
        await db?.rawQuery('SELECT * FROM browser WHERE id = ?', [1]);
    if (browsers == null || browsers.length == 0) {
      return;
    }
    final browser = browsers[0];
    Map<String, dynamic> browserData = json.decode(browser['json'] as String);
    try {
      clearFavorites();
      clearWebArchives();

      List<Map<String, dynamic>> favoritesList =
          browserData["favorites"]?.cast<Map<String, dynamic>>() ?? [];
      List<FavoriteModel> favorites =
          favoritesList.map((e) => FavoriteModel.fromMap(e)!).toList();

      Map<String, dynamic> webArchivesMap =
          browserData["webArchives"]?.cast<String, dynamic>() ?? {};
      Map<String, WebArchiveModel> webArchives = webArchivesMap.map(
          (key, value) => MapEntry(
              key, WebArchiveModel.fromMap(value?.cast<String, dynamic>())!));

      BrowserSettings settings = BrowserSettings.fromMap(
              browserData["settings"]?.cast<String, dynamic>()) ??
          BrowserSettings();

      addFavorites(favorites);
      addWebArchives(webArchives);
      updateSettings(settings);
    } catch (e) {
      if (kDebugMode) {
        print(e);
        debug(e);
      }
      return;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      "favorites": _favorites.map((e) => e.toMap()).toList(),
      "webArchives":
          _webArchives.map((key, value) => MapEntry(key, value.toMap())),
      "settings": _settings.toMap()
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return toMap().toString();
  }
}