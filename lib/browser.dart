import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_browser/custom_image.dart';
import 'package:flutter_browser/tab_viewer.dart';
import 'package:flutter_browser/app_bar/browser_app_bar.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_browser/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import 'app_bar/tab_viewer_app_bar.dart';
import 'empty_tab.dart';
import 'models/browser_model.dart';
import 'models/window_model.dart';

class Browser extends StatefulWidget {
  const Browser({super.key});

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> with SingleTickerProviderStateMixin {
  static const platform =
      MethodChannel('com.pichillilorenzo.flutter_browser.intent_data');

  var _isRestored = false;

  @override
  void initState() {
    super.initState();
    getIntentData();
  }

  getIntentData() async {
    if (Util.isAndroid()) {
      String? url = await platform.invokeMethod("getIntentData");
      if (url != null) {
        if (mounted) {
          if (Util.isDesktop()) {
            final windowModel = Provider.of<WindowModel>(context, listen: false);
            windowModel.addTab(WebViewTab(
              key: GlobalKey(),
              webViewModel: WebViewModel(url: WebUri(url)),
            ));
          } else {
            // Handle in mobile version if needed
          }
        }
      }
    }
  }
  
  restore() async {
    if (Util.isDesktop()) {
      final windowModel = Provider.of<WindowModel>(context, listen: false);
      windowModel.restoreInfo();
    }
    // Don't call browserModel.restore() if it doesn't exist
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRestored) {
      _isRestored = true;
      restore();
    }
    precacheImage(const AssetImage("assets/icon/icon.png"), context);
  }

  @override
  Widget build(BuildContext context) {
    return _buildBrowser();
  }

  Widget _buildBrowser() {
    final currentWebViewModel = Provider.of<WebViewModel>(context, listen: true);
    
    if (Util.isDesktop()) {
      final windowModel = Provider.of<WindowModel>(context, listen: true);
      
      windowModel.addListener(() {
        windowModel.saveInfo();
      });
      
      currentWebViewModel.addListener(() {
        windowModel.saveInfo();
      });

      var canShowTabScroller = windowModel.webViewTabs.isNotEmpty;

      return IndexedStack(
        index: canShowTabScroller ? 1 : 0,
        children: [
          _buildWebViewTabs(),
          canShowTabScroller ? _buildWebViewTabsViewer() : Container()
        ],
      );
    } else {
      // Simplified version for mobile
      return _buildWebViewTabs();
    }
  }

  Widget _buildWebViewTabs() {
    return WillPopScope(
        onWillPop: () async {
          if (Util.isDesktop()) {
            final windowModel = Provider.of<WindowModel>(context, listen: false);
            final webViewModel = windowModel.getCurrentTab()?.webViewModel;
            final webViewController = webViewModel?.webViewController;

            if (webViewController != null) {
              if (await webViewController.canGoBack()) {
                webViewController.goBack();
                return false;
              }
            }

            if (webViewModel != null && webViewModel.tabIndex != null) {
              setState(() {
                windowModel.closeTab(webViewModel.tabIndex!);
              });
              if (mounted) {
                FocusScope.of(context).unfocus();
              }
              return false;
            }

            return windowModel.webViewTabs.isEmpty;
          } else {
            // Mobile back handling
            return true;
          }
        },
        child: Listener(
          onPointerUp: (_) {
            if (Util.isIOS() || Util.isAndroid()) {
              FocusScopeNode currentFocus = FocusScope.of(context);
              if (!currentFocus.hasPrimaryFocus &&
                  currentFocus.focusedChild != null) {
                currentFocus.focusedChild!.unfocus();
              }
            }
          },
          child: Scaffold(
              appBar: BrowserAppBar(), 
              body: _buildWebViewTabsContent()),
        ));
  }

  Widget _buildWebViewTabsContent() {
    if (Util.isDesktop()) {
      final windowModel = Provider.of<WindowModel>(context, listen: true);
      
      if (windowModel.webViewTabs.isEmpty) {
        return const EmptyTab();
      }

      var stackChildren = <Widget>[
        windowModel.getCurrentTab() ?? Container(),
        _createProgressIndicator()
      ];

      return Column(
        children: [
          Expanded(
              child: Stack(
            children: stackChildren,
          ))
        ],
      );
    } else {
      // Simplified version for mobile
      return const EmptyTab();
    }
  }

  Widget _createProgressIndicator() {
    return Selector<WebViewModel, double>(
        selector: (context, webViewModel) => webViewModel.progress,
        builder: (context, progress, child) {
          if (progress >= 1.0) {
            return Container();
          }
          return PreferredSize(
              preferredSize: const Size(double.infinity, 4.0),
              child: SizedBox(
                  height: 4.0,
                  child: LinearProgressIndicator(
                    value: progress,
                  )));
        });
  }

  Widget _buildWebViewTabsViewer() {
    if (Util.isDesktop()) {
      final windowModel = Provider.of<WindowModel>(context, listen: true);

      return WillPopScope(
          onWillPop: () async {
            return false;
          },
          child: Scaffold(
              appBar: const TabViewerAppBar(),
              body: TabViewer(
                currentIndex: windowModel.getCurrentTabIndex(),
                children: windowModel.webViewTabs.map((webViewTab) {
                  var screenshotData = webViewTab.webViewModel.screenshot;
                  Widget screenshotImage = Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    width: double.infinity,
                    child: screenshotData != null
                        ? Image.memory(screenshotData)
                        : null,
                  );

                  var url = webViewTab.webViewModel.url;
                  var faviconUrl = webViewTab.webViewModel.favicon != null
                      ? webViewTab.webViewModel.favicon!.url
                      : (url != null && ["http", "https"].contains(url.scheme)
                          ? Uri.parse("${url.origin}/favicon.ico")
                          : null);

                  var isCurrentTab = windowModel.getCurrentTabIndex() ==
                      webViewTab.webViewModel.tabIndex;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Material(
                        color: isCurrentTab
                            ? Colors.blue
                            : (webViewTab.webViewModel.isIncognitoMode
                                ? Colors.black
                                : Colors.white),
                        child: ListTile(
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              CustomImage(
                                  url: faviconUrl, maxWidth: 30.0, height: 30.0)
                            ],
                          ),
                          title: Text(
                              webViewTab.webViewModel.title ??
                                  webViewTab.webViewModel.url?.toString() ??
                                  "",
                              maxLines: 2,
                              style: TextStyle(
                                color: webViewTab.webViewModel.isIncognitoMode ||
                                        isCurrentTab
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis),
                          subtitle:
                              Text(webViewTab.webViewModel.url?.toString() ?? "",
                                  style: TextStyle(
                                    color:
                                        webViewTab.webViewModel.isIncognitoMode ||
                                                isCurrentTab
                                            ? Colors.white60
                                            : Colors.black54,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 20.0,
                                  color:
                                      webViewTab.webViewModel.isIncognitoMode ||
                                              isCurrentTab
                                          ? Colors.white60
                                          : Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (webViewTab.webViewModel.tabIndex != null) {
                                      windowModel.closeTab(webViewTab.webViewModel.tabIndex!);
                                    }
                                  });
                                },
                              )
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: screenshotImage,
                      )
                    ],
                  );
                }).toList(),
                onTap: (index) async {
                  windowModel.showTab(index);
                },
              )));
    } else {
      // Simplified version for mobile
      return Container();
    }
  }
}