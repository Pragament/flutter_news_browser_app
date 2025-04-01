// import 'package:cached_network_image/cached_network_image.dart';
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_browser/Db/hive_db_helper.dart';
import 'package:flutter_browser/app_bar/url_info_popup.dart';
import 'package:flutter_browser/custom_image.dart';
import 'package:flutter_browser/main.dart';
import 'package:flutter_browser/models/browser_model.dart';
import 'package:flutter_browser/models/favorite_model.dart';
import 'package:flutter_browser/models/web_archive_model.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'package:flutter_browser/pages/developers/main.dart';
import 'package:flutter_browser/pages/settings/main.dart';
import 'package:flutter_browser/rss_news/models/most_visited_website_model.dart';
import 'package:flutter_browser/rss_news/services/summeriz_article.dart';
import 'package:flutter_browser/rss_news/services/whitelist.dart';
import 'package:flutter_browser/tab_popup_menu_actions.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_font_icons/flutter_font_icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
// import 'package:share_extend/share_extend.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../animated_flutter_browser_logo.dart';
import '../custom_popup_dialog.dart';
import '../custom_popup_menu_item.dart';
import '../models/window_model.dart';
import '../popup_menu_actions.dart';
import '../project_info_popup.dart';
import '../pages/childsActivity/childs_activity_page.dart';
import '../webview_tab.dart';

class WebViewTabAppBar extends StatefulWidget {
  final void Function()? showFindOnPage;

  const WebViewTabAppBar({super.key, this.showFindOnPage});

  @override
  State<WebViewTabAppBar> createState() => _WebViewTabAppBarState();
}

class _WebViewTabAppBarState extends State<WebViewTabAppBar>
    with SingleTickerProviderStateMixin {
  TextEditingController? _searchController = TextEditingController();
  FocusNode? _focusNode;

  GlobalKey tabInkWellKey = GlobalKey();

  Duration customPopupDialogTransitionDuration =
      const Duration(milliseconds: 300);
  CustomPopupDialogPageRoute? route;
  SummarizeArticle summarizeArticle = SummarizeArticle();
  String summary = "";
  OutlineInputBorder outlineBorder = const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.transparent, width: 0.0),
    borderRadius: BorderRadius.all(
      Radius.circular(50.0),
    ),
  );

  bool shouldSelectText = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _searchController = TextEditingController();

    _focusNode?.addListener(() async {
      if (_focusNode != null &&
          !_focusNode!.hasFocus &&
          _searchController != null &&
          _searchController!.text.isEmpty) {
        var browserModel = Provider.of<BrowserModel>(context, listen: false);
        var webViewModel = browserModel.getCurrentTab()?.webViewModel;
        var webViewController = webViewModel?.webViewController;
        _searchController!.text =
            (await webViewController?.getUrl())?.toString() ?? "";
      }
    });
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    _focusNode = null;
    _searchController?.dispose();
    _searchController = null;
    super.dispose();
  }

  int _prevTabIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Selector<WebViewModel, WebUri?>(
        selector: (context, webViewModel) => webViewModel.url,
        builder: (context, url, child) {
          // Only update text when not focused to avoid interrupting user input
          if (url == null) {
            if (!_focusNode!.hasFocus) {
              _searchController?.text = "";
            }
          }
          if (url != null && _focusNode != null && !_focusNode!.hasFocus) {
            _searchController?.text = url.toString();
            _saveMostVisitedWebsite(url.toString());
          }

          Widget? leading = _buildAppBarHomePageWidget();

          return Selector<WebViewModel, bool>(
              selector: (context, webViewModel) => webViewModel.isIncognitoMode,
              builder: (context, isIncognitoMode, child) {
                return leading != null
                    ? AppBar(
                  backgroundColor: isIncognitoMode
                      ? Colors.black38
                      : Theme.of(context).colorScheme.primaryContainer,
                  leading: leading,
                  leadingWidth: 130,
                  titleSpacing: 0.0,
                  title: _buildSearchTextField(),
                  actions: _buildActionsMenu(),
                )
                    : AppBar(
                  backgroundColor: isIncognitoMode
                      ? Colors.black38
                      : Theme.of(context).colorScheme.primaryContainer,
                  titleSpacing: 10.0,
                  title: _buildSearchTextField(),
                  actions: _buildActionsMenu(),
                );
              });
        });
  }

  Widget? _buildAppBarHomePageWidget() {
    var browserModel = Provider.of<BrowserModel>(context, listen: true);
    return IconButton(
      icon: const Icon(Icons.home),
      onPressed: () {
        browserModel.openEmptyTab();
      },
    );
  }

  Widget _buildSearchTextField() {
    final browserModel = Provider.of<BrowserModel>(context, listen: true);
    final settings = browserModel.getSettings();

    final webViewModel = Provider.of<WebViewModel>(context, listen: true);
    final webViewController = webViewModel.webViewController;

    return SizedBox(
      height: 47,
      child: Stack(
        children: <Widget>[
          TextField(
            onSubmitted: (value) async {
              var url = WebUri(value.trim());
              if (Util.isLocalizedContent(url) ||
                  (url.isValidUri && url.toString().split(".").length > 1)) {
                url = url.scheme.isEmpty ? WebUri("https://$url") : url;
              } else {
                url = WebUri(settings.searchEngine.searchUrl + value);
              }

              if (webViewController != null &&
                  Whitelist.isWebsiteAllowed(url)) {
                webViewController.loadUrl(urlRequest: URLRequest(url: url));
              } else {
                addNewTab(url: url);
                webViewModel.url = url;
              }
              // Only unfocus after submission
              _focusNode?.unfocus();
            },
            onTap: () {
              // Select all text when the field is tapped
              _searchController?.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _searchController?.text.length ?? 0,
              );
            // },
            // onTap: () {
              if (!shouldSelectText ||
                  _searchController == null ||
                  _searchController!.text.isEmpty) return;
              shouldSelectText = false;
              _searchController!.selection = TextSelection(
                  baseOffset: 0, extentOffset: _searchController!.text.length);
            },
            onTapOutside: (event) {
              shouldSelectText = true;
            },
            keyboardType: TextInputType.url,
            focusNode: _focusNode,
            autofocus: false,
            controller: _searchController,
            textInputAction: TextInputAction.go,
            enableInteractiveSelection:
                true, // Explicitly enable text selection
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.only(
                  left: 45.0, top: 10.0, right: 10.0, bottom: 10.0),
              filled: true,
              fillColor: Colors.white,
              border: outlineBorder,
              focusedBorder: outlineBorder,
              enabledBorder: outlineBorder,
              hintText: "Search for or type a web address",
              hintStyle: const TextStyle(color: Colors.black54, fontSize: 16.0),
            ),
            style: const TextStyle(color: Colors.black, fontSize: 16.0),
          ),
          IconButton(
            icon: Selector<WebViewModel, bool>(
              selector: (context, webViewModel) => webViewModel.isSecure,
              builder: (context, isSecure, child) {
                var icon = Icons.info_outline;
                if (webViewModel.isIncognitoMode) {
                  icon = MaterialCommunityIcons.incognito;
                } else if (isSecure) {
                  if (webViewModel.url != null &&
                      webViewModel.url!.scheme == "file") {
                    icon = Icons.offline_pin;
                  } else {
                    icon = Icons.lock;
                  }
                }

                return Icon(
                  icon,
                  color: isSecure ? Colors.green : Colors.grey,
                );
              },
            ),
            onPressed: () {
              showUrlInfo();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionsMenu() {
    final browserModel = Provider.of<BrowserModel>(context, listen: true);
    final windowModel = Provider.of<WindowModel>(context, listen: true);
    final settings = browserModel.getSettings();

    return [
      settings.homePageEnabled
          ? const SizedBox(
              width: 10.0,
            )
          : Container(),
      Util.isDesktop()
          ? null
          : InkWell(
              key: tabInkWellKey,
              onLongPress: () {
                final RenderBox? box = tabInkWellKey.currentContext!
                    .findRenderObject() as RenderBox?;
                if (box == null) {
                  return;
                }

                Offset position = box.localToGlobal(Offset.zero);

                showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(position.dx,
                            position.dy + box.size.height, box.size.width, 0),
                        items: TabPopupMenuActions.choices
                            .map((tabPopupMenuAction) {
                          IconData? iconData;
                          switch (tabPopupMenuAction) {
                            case TabPopupMenuActions.CLOSE_TABS:
                              iconData = Icons.cancel;
                              break;
                            case TabPopupMenuActions.NEW_TAB:
                              iconData = Icons.add;
                              break;
                            case TabPopupMenuActions.NEW_INCOGNITO_TAB:
                              iconData = MaterialCommunityIcons.incognito;
                              break;
                          }

                          return PopupMenuItem<String>(
                            value: tabPopupMenuAction,
                            child: Row(children: [
                              Icon(
                                iconData,
                                color: Colors.black,
                              ),
                              Container(
                                padding: const EdgeInsets.only(left: 10.0),
                                child: Text(tabPopupMenuAction),
                              )
                            ]),
                          );
                        }).toList())
                    .then((value) {
                  switch (value) {
                    case TabPopupMenuActions.CLOSE_TABS:
                      windowModel.closeAllTabs();
                      break;
                    case TabPopupMenuActions.NEW_TAB:
                      addNewTab();
                      break;
                    case TabPopupMenuActions.NEW_INCOGNITO_TAB:
                      addNewIncognitoTab();
                      break;
                  }
                });
              },
              onTap: () async {
                if (windowModel.webViewTabs.isNotEmpty) {
                  var webViewModel = windowModel.getCurrentTab()?.webViewModel;
                  var webViewController = webViewModel?.webViewController;

                  if (View.of(context).viewInsets.bottom > 0.0) {
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                    if (FocusManager.instance.primaryFocus != null) {
                      FocusManager.instance.primaryFocus!.unfocus();
                    }
                    if (webViewController != null) {
                      await webViewController.evaluateJavascript(
                          source: "document.activeElement.blur();");
                    }
                    await Future.delayed(const Duration(milliseconds: 300));
                  }

                  if (webViewModel != null && webViewController != null) {
                    webViewModel.screenshot = await webViewController
                        .takeScreenshot(
                            screenshotConfiguration: ScreenshotConfiguration(
                                compressFormat: CompressFormat.JPEG,
                                quality: 20))
                        .timeout(
                          const Duration(milliseconds: 1500),
                          onTimeout: () => null,
                        );
                  }

                  browserModel.showTabScroller = true;
                }
              },
              child: Container(
                margin: const EdgeInsets.only(
                    left: 10.0, top: 15.0, right: 10.0, bottom: 15.0),
                decoration: BoxDecoration(
                    border: Border.all(width: 2.0),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(5.0)),
                constraints: const BoxConstraints(minWidth: 25.0),
                child: Center(
                    child: Text(
                  windowModel.webViewTabs.length.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.0),
                )),
              ),
            ),
      const SizedBox.square(
        dimension: 5,
      ),
      PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert,
        ),
        position: PopupMenuPosition.under,
        onSelected: _popupMenuChoiceAction,
        itemBuilder: (popupMenuContext) {
          var items = [
            CustomPopupMenuItem<String>(
              enabled: true,
              isIconButtonRow: true,
              child: StatefulBuilder(
                builder: (statefulContext, setState) {
                  var browserModel =
                      Provider.of<BrowserModel>(statefulContext, listen: true);
                  var webViewModel =
                      Provider.of<WebViewModel>(statefulContext, listen: true);

                  var isFavorite = false;
                  FavoriteModel? favorite;

                  if (webViewModel.url != null &&
                      webViewModel.url!.toString().isNotEmpty) {
                    favorite = FavoriteModel(
                        url: webViewModel.url,
                        title: webViewModel.title ?? "",
                        favicon: webViewModel.favicon);
                    isFavorite = browserModel.containsFavorite(favorite);
                  }

                  var children = <Widget>[];

                  if (Util.isIOS() || Util.isMacOS() || Util.isWindows()) {
                    children.add(
                      SizedBox(
                          width: 35.0,
                          child: IconButton(
                              padding: const EdgeInsets.all(0.0),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                webViewModel.webViewController?.goBack();
                                Navigator.pop(popupMenuContext);
                              })),
                    );
                  }

                  children.addAll([
                    SizedBox(
                        width: 35.0,
                        child: IconButton(
                            padding: const EdgeInsets.all(0.0),
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              webViewModel.webViewController?.goForward();
                              Navigator.pop(popupMenuContext);
                            })),
                    SizedBox(
                        width: 35.0,
                        child: IconButton(
                            padding: const EdgeInsets.all(0.0),
                            icon: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                if (favorite != null) {
                                  if (!browserModel
                                      .containsFavorite(favorite)) {
                                    browserModel.addFavorite(favorite);
                                  } else if (browserModel
                                      .containsFavorite(favorite)) {
                                    browserModel.removeFavorite(favorite);
                                  }
                                }
                              });
                            })),
                    SizedBox(
                        width: 35.0,
                        child: IconButton(
                            padding: const EdgeInsets.all(0.0),
                            icon: const Icon(
                              Icons.file_download,
                              color: Colors.black,
                            ),
                            onPressed: () async {
                              Navigator.pop(popupMenuContext);
                              if (webViewModel.url != null &&
                                  webViewModel.url!.scheme.startsWith("http")) {
                                var url = webViewModel.url;
                                if (url == null) {
                                  return;
                                }

                                String webArchivePath =
                                    "$WEB_ARCHIVE_DIR${Platform.pathSeparator}${url.scheme}-${url.host}${url.path.replaceAll("/", "-")}${DateTime.now().microsecondsSinceEpoch}.${Util.isAndroid() ? WebArchiveFormat.MHT.toValue() : WebArchiveFormat.WEBARCHIVE.toValue()}";

                                String? savedPath = (await webViewModel
                                    .webViewController
                                    ?.saveWebArchive(
                                        filePath: webArchivePath,
                                        autoname: false));

                                var webArchiveModel = WebArchiveModel(
                                    url: url,
                                    path: savedPath,
                                    title: webViewModel.title,
                                    favicon: webViewModel.favicon,
                                    timestamp: DateTime.now());

                                if (savedPath != null) {
                                  browserModel.addWebArchive(
                                      url.toString(), webArchiveModel);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          "${webViewModel.url} saved offline!"),
                                    ));
                                  }
                                  browserModel.save();
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text("Unable to save!"),
                                    ));
                                  }
                                }
                              }
                            })),
                    SizedBox(
                        width: 35.0,
                        child: IconButton(
                            padding: const EdgeInsets.all(0.0),
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.black,
                            ),
                            onPressed: () async {
                              Navigator.pop(popupMenuContext);

                              await route?.completed;
                              showUrlInfo();
                            })),
                    SizedBox(
                        width: 35.0,
                        child: IconButton(
                            padding: const EdgeInsets.all(0.0),
                            icon: const Icon(
                              MaterialCommunityIcons.cellphone_screenshot,
                              color: Colors.black,
                            ),
                            onPressed: () async {
                              Navigator.pop(popupMenuContext);

                              await route?.completed;

                              takeScreenshotAndShow();
                            })),
                    SizedBox(
                        width: 35.0,
                        child: IconButton(
                            padding: const EdgeInsets.all(0.0),
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              webViewModel.webViewController?.reload();
                              Navigator.pop(popupMenuContext);
                            })),
                  ]);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: children,
                  );
                },
              ),
            )
          ];

          items.addAll(PopupMenuActions.choices.map((choice) {
            switch (choice) {
              case PopupMenuActions.OPEN_NEW_WINDOW:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.open_in_new,
                        )
                      ]),
                );
              case PopupMenuActions.SAVE_WINDOW:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        Selector<WindowModel, bool>(
                          selector: (context, windowModel) =>
                              windowModel.shouldSave,
                          builder: (context, value, child) {
                            return Icon(
                              value
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: Colors.black,
                            );
                          },
                        )
                      ]),
                );
              case PopupMenuActions.SAVED_WINDOWS:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.window,
                        )
                      ]),
                );
              case PopupMenuActions.NEW_TAB:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.add,
                          color: Colors.black,
                        )
                      ]),
                );
              case PopupMenuActions.NEW_INCOGNITO_TAB:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          MaterialCommunityIcons.incognito,
                          color: Colors.black,
                        )
                      ]),
                );
              case PopupMenuActions.FAVORITES:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.star,
                          color: Colors.yellow,
                        )
                      ]),
                );
              case PopupMenuActions.WEB_ARCHIVES:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.offline_pin,
                          color: Colors.blue,
                        )
                      ]),
                );
              case PopupMenuActions.CHILD_ACTIVITY:
                return CustomPopupMenuItem<String>(
                  enabled: HiveDBHelper.getAllChildDevices().isNotEmpty,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.child_care,
                          color: Colors.blue,
                        )
                      ]),
                );
              case PopupMenuActions.DESKTOP_MODE:
                return CustomPopupMenuItem<String>(
                  enabled: windowModel.getCurrentTab() != null,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        Selector<WebViewModel, bool>(
                          selector: (context, webViewModel) =>
                              webViewModel.isDesktopMode,
                          builder: (context, value, child) {
                            return Icon(
                              value
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: Colors.black,
                            );
                          },
                        )
                      ]),
                );
              case PopupMenuActions.INSPECT_ELEMENTS_MODE:
                return CustomPopupMenuItem<String>(
                  enabled: browserModel.getCurrentTab() != null,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        Selector<WebViewModel, bool>(
                          selector: (context, webViewModel) =>
                              webViewModel.isInspectMode,
                          builder: (context, value, child) {
                            return Icon(
                              value
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: Colors.black,
                            );
                          },
                        )
                      ]),
                );
              case PopupMenuActions.HISTORY:
                return CustomPopupMenuItem<String>(
                  enabled: windowModel.getCurrentTab() != null,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.history,
                          color: Colors.black,
                        )
                      ]),
                );
              case PopupMenuActions.SHARE:
                return CustomPopupMenuItem<String>(
                  enabled: windowModel.getCurrentTab() != null,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Ionicons.logo_whatsapp,
                          color: Colors.green,
                        )
                      ]),
                );
              case PopupMenuActions.SETTINGS:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.settings,
                          color: Colors.grey,
                        )
                      ]),
                );
              case PopupMenuActions.DEVELOPERS:
                return CustomPopupMenuItem<String>(
                  enabled: windowModel.getCurrentTab() != null,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.developer_mode,
                          color: Colors.black,
                        )
                      ]),
                );
              case PopupMenuActions.FIND_ON_PAGE:
                return CustomPopupMenuItem<String>(
                  enabled: windowModel.getCurrentTab() != null,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Icons.search,
                          color: Colors.black,
                        )
                      ]),
                );
              case PopupMenuActions.FETCH_GEMINI_AI_HIGHLIGHTS:
                return CustomPopupMenuItem<String>(
                  enabled: browserModel.getSettings().geminiApiKey.isNotEmpty,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        const Icon(
                          Ionicons.bulb,
                          color: Colors.black,
                        )
                      ]),
                );
              case PopupMenuActions.INAPPWEBVIEW_PROJECT:
                return CustomPopupMenuItem<String>(
                  enabled: true,
                  value: choice,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(choice),
                        Container(
                          padding: const EdgeInsets.only(right: 6),
                          child: const AnimatedFlutterBrowserLogo(
                            size: 12.5,
                          ),
                        )
                      ]),
                );
              default:
                return CustomPopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
            }
          }).toList());

          return items;
        },
      )
    ].whereNotNull().toList();
  }

  void _popupMenuChoiceAction(String choice) async {
    var currentWebViewModel = Provider.of<WebViewModel>(context, listen: false);
    switch (choice) {
      case PopupMenuActions.OPEN_NEW_WINDOW:
        openNewWindow();
        break;
      case PopupMenuActions.SAVE_WINDOW:
        setShouldSave();
        break;
      case PopupMenuActions.SAVED_WINDOWS:
        showSavedWindows();
        break;
      case PopupMenuActions.NEW_TAB:
        addNewTab();
        break;
      case PopupMenuActions.NEW_INCOGNITO_TAB:
        addNewIncognitoTab();
        break;
      case PopupMenuActions.FAVORITES:
        showFavorites();
        break;
      case PopupMenuActions.HISTORY:
        showHistory();
        break;
      case PopupMenuActions.WEB_ARCHIVES:
        showWebArchives();
        break;
      case PopupMenuActions.CHILD_ACTIVITY:
        goToChildsActivityPage();
        break;
      case PopupMenuActions.FIND_ON_PAGE:
        var isFindInteractionEnabled =
            currentWebViewModel.settings?.isFindInteractionEnabled ?? false;
        var findInteractionController =
            currentWebViewModel.findInteractionController;
        if (Util.isIOS() &&
            isFindInteractionEnabled &&
            findInteractionController != null) {
          await findInteractionController.presentFindNavigator();
        } else if (widget.showFindOnPage != null) {
          widget.showFindOnPage!();
        }
        break;
      case PopupMenuActions.FETCH_GEMINI_AI_HIGHLIGHTS:
        fetchAiHighlights(currentWebViewModel.url.toString(), context);
        break;
      case PopupMenuActions.SHARE:
        share();
        break;
      case PopupMenuActions.DESKTOP_MODE:
        toggleDesktopMode();
        break;
      case PopupMenuActions.INSPECT_ELEMENTS_MODE:
        toggleInspectElementsMode();
        break;
      case PopupMenuActions.DEVELOPERS:
        Future.delayed(const Duration(milliseconds: 300), () {
          goToDevelopersPage();
        });
        break;
      case PopupMenuActions.SETTINGS:
        Future.delayed(const Duration(milliseconds: 300), () {
          goToSettingsPage();
        });
        break;
      case PopupMenuActions.INAPPWEBVIEW_PROJECT:
        Future.delayed(const Duration(milliseconds: 300), () {
          openProjectPopup();
        });
        break;
    }
  }

  void addNewTab({WebUri? url}) {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final settings = browserModel.getSettings();

    url ??= settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);

    windowModel.addTab(WebViewTab(
      key: GlobalKey(),
      webViewModel: WebViewModel(url: url),
    ));
  }

  void addNewIncognitoTab({WebUri? url}) {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final settings = browserModel.getSettings();

    url ??= settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);

    windowModel.addTab(WebViewTab(
      key: GlobalKey(),
      webViewModel: WebViewModel(url: url, isIncognitoMode: true),
    ));
  }

  void showSavedWindows() {
    showDialog(
        context: context,
        builder: (context) {
          final browserModel = Provider.of<BrowserModel>(context, listen: true);

          return AlertDialog(
              contentPadding: const EdgeInsets.all(0.0),
              content: SizedBox(
                  width: double.maxFinite,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return FutureBuilder(
                        future: browserModel.getWindows(),
                        builder: (context, snapshot) {
                          final savedWindows = (snapshot.data ?? []);
                          savedWindows.sortBy(
                            (e) => e.updatedTime,
                          );
                          return ListView(
                            children: savedWindows.map((window) {
                              return ListTile(
                                title: Text(
                                    window.name.isNotEmpty
                                        ? window.name
                                        : window.id,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () async {
                                  await browserModel.openWindow(window);
                                  setState(() {
                                    Navigator.pop(context);
                                  });
                                },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20.0),
                                      onPressed: () async {
                                        await browserModel.removeWindow(window);
                                        setState(() {
                                          if (savedWindows.isEmpty ||
                                              savedWindows.length == 1) {
                                            Navigator.pop(context);
                                          }
                                        });
                                      },
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  )));
        });
  }

  void showFavorites() {
    showDialog(
        context: context,
        builder: (context) {
          var browserModel = Provider.of<BrowserModel>(context, listen: true);

          return AlertDialog(
              contentPadding: const EdgeInsets.all(0.0),
              content: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    children: browserModel.favorites.map((favorite) {
                      var url = favorite.url;
                      var faviconUrl = favorite.favicon != null
                          ? favorite.favicon!.url
                          : WebUri("${url?.origin ?? ""}/favicon.ico");

                      return ListTile(
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            // CachedNetworkImage(
                            //   placeholder: (context, url) =>
                            //       CircularProgressIndicator(),
                            //   imageUrl: faviconUrl,
                            //   height: 30,
                            // )
                            CustomImage(
                              url: faviconUrl,
                              maxWidth: 30.0,
                              height: 30.0,
                            )
                          ],
                        ),
                        title: Text(
                            favorite.title ?? favorite.url?.toString() ?? "",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(favorite.url?.toString() ?? "",
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        onTap: () {
                          setState(() {
                            addNewTab(url: favorite.url);
                            Navigator.pop(context);
                          });
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.close, size: 20.0),
                              onPressed: () {
                                setState(() {
                                  browserModel.removeFavorite(favorite);
                                  if (browserModel.favorites.isEmpty) {
                                    Navigator.pop(context);
                                  }
                                });
                              },
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  )));
        });
  }

  void showHistory() {
    showDialog(
        context: context,
        builder: (context) {
          var webViewModel = Provider.of<WebViewModel>(context, listen: true);

          return AlertDialog(
              contentPadding: const EdgeInsets.all(0.0),
              content: FutureBuilder(
                future:
                    webViewModel.webViewController?.getCopyBackForwardList(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container();
                  }

                  WebHistory history = snapshot.data as WebHistory;
                  return SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        children: history.list?.reversed.map((historyItem) {
                              var url = historyItem.url;

                              return ListTile(
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    // CachedNetworkImage(
                                    //   placeholder: (context, url) =>
                                    //       CircularProgressIndicator(),
                                    //   imageUrl: (url?.origin ?? "") + "/favicon.ico",
                                    //   height: 30,
                                    // )
                                    CustomImage(
                                        url: WebUri(
                                            "${url?.origin ?? ""}/favicon.ico"),
                                        maxWidth: 30.0,
                                        height: 30.0)
                                  ],
                                ),
                                title: Text(historyItem.title ?? url.toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(url?.toString() ?? "",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                isThreeLine: true,
                                onTap: () {
                                  webViewModel.webViewController
                                      ?.goTo(historyItem: historyItem);
                                  Navigator.pop(context);
                                },
                              );
                            }).toList() ??
                            <Widget>[],
                      ));
                },
              ));
        });
  }

  void showWebArchives() async {
    showDialog(
        context: context,
        builder: (context) {
          var browserModel = Provider.of<BrowserModel>(context, listen: true);
          var webArchives = browserModel.webArchives;

          var listViewChildren = <Widget>[];
          webArchives.forEach((key, webArchive) {
            var path = webArchive.path;
            // String fileName = path.substring(path.lastIndexOf('/') + 1);

            var url = webArchive.url;

            listViewChildren.add(ListTile(
              leading: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // CachedNetworkImage(
                  //   placeholder: (context, url) => CircularProgressIndicator(),
                  //   imageUrl: (url?.origin ?? "") + "/favicon.ico",
                  //   height: 30,
                  // )
                  CustomImage(
                      url: WebUri("${url?.origin ?? ""}/favicon.ico"),
                      maxWidth: 30.0,
                      height: 30.0)
                ],
              ),
              title: Text(webArchive.title ?? url?.toString() ?? "",
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(url?.toString() ?? "",
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  setState(() {
                    browserModel.removeWebArchive(webArchive);
                    browserModel.save();
                  });
                },
              ),
              isThreeLine: true,
              onTap: () {
                if (path != null) {
                  final windowModel =
                      Provider.of<WindowModel>(context, listen: false);
                  windowModel.addTab(WebViewTab(
                    key: GlobalKey(),
                    webViewModel: WebViewModel(url: WebUri("file://$path")),
                  ));
                }
                Navigator.pop(context);
              },
            ));
          });

          return AlertDialog(
              contentPadding: const EdgeInsets.all(0.0),
              content: Builder(
                builder: (context) {
                  return SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        children: listViewChildren,
                      ));
                },
              ));
        });
  }

  void share() {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final webViewModel = windowModel.getCurrentTab()?.webViewModel;
    final url = webViewModel?.url;
    if (url != null) {
      Share.share(url.toString(), subject: webViewModel?.title);
    }
  }

  void openNewWindow() {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    browserModel.openWindow(null);
  }

  void setShouldSave() {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    windowModel.shouldSave = !windowModel.shouldSave;
  }

  void toggleDesktopMode() async {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final webViewModel = windowModel.getCurrentTab()?.webViewModel;
    final webViewController = webViewModel?.webViewController;

    final currentWebViewModel =
        Provider.of<WebViewModel>(context, listen: false);

    if (webViewController != null) {
      webViewModel?.isDesktopMode = !webViewModel.isDesktopMode;
      currentWebViewModel.isDesktopMode = webViewModel?.isDesktopMode ?? false;

      final currentSettings = await webViewController.getSettings();
      if (currentSettings != null) {
        currentSettings.preferredContentMode =
            webViewModel?.isDesktopMode ?? false
                ? UserPreferredContentMode.DESKTOP
                : UserPreferredContentMode.RECOMMENDED;
        await webViewController.setSettings(settings: currentSettings);
      }
      await webViewController.reload();
    }
  }

  void toggleInspectElementsMode() async {
    var browserModel = Provider.of<BrowserModel>(context, listen: false);
    var webViewModel = browserModel.getCurrentTab()?.webViewModel;
    var webViewTabState = browserModel.getCurrentTab()?.getState();

    if (webViewModel != null) {
      // Toggle the inspect mode flag
      webViewModel.isInspectMode = !webViewModel.isInspectMode;

      // Update the current WebViewModel to reflect the change
      var currentWebViewModel =
          Provider.of<WebViewModel>(context, listen: false);
      currentWebViewModel.isInspectMode = webViewModel.isInspectMode;

      // The WebViewTab will handle enabling/disabling the inspector based on this flag
      if (webViewTabState != null) {
        if (webViewModel.isInspectMode) {
          // A simple refresh or onShowTab might trigger the DOM inspector
          webViewTabState.onShowTab();
        } else {
          // This might disable the DOM inspector
          webViewTabState.onHideTab();
        }
      }
    }
  }

  void showUrlInfo() {
    var webViewModel = Provider.of<WebViewModel>(context, listen: false);
    var url = webViewModel.url;
    if (url == null || url.toString().isEmpty) {
      return;
    }

    route = CustomPopupDialog.show(
      context: context,
      transitionDuration: customPopupDialogTransitionDuration,
      builder: (context) {
        return UrlInfoPopup(
          route: route!,
          transitionDuration: customPopupDialogTransitionDuration,
          onWebViewTabSettingsClicked: () {
            goToSettingsPage();
          },
        );
      },
    );
  }

  void goToDevelopersPage() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const DevelopersPage()));
  }

  void goToSettingsPage() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  void goToChildsActivityPage() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ChildsActivityPage()));
  }

  void openProjectPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return const ProjectInfoPopup();
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void takeScreenshotAndShow() async {
    var webViewModel = Provider.of<WebViewModel>(context, listen: false);
    var screenshot = await webViewModel.webViewController?.takeScreenshot();

    if (screenshot != null) {
      var dir = await getApplicationDocumentsDirectory();
      File file = File(
          "${dir.path}/screenshot_${DateTime.now().microsecondsSinceEpoch}.png");
      await file.writeAsBytes(screenshot);

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Image.memory(screenshot),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("Share"),
                onPressed: () async {
                  // await ShareExtend.share(file.path, "image");
                },
              )
            ],
          );
        },
      );

      file.delete();
    }
  }

  Future<String> loadLocalJs() async {
    return await rootBundle.loadString('assets/js/custom.js');
  }

  Future<List<String>> summarizeIfNotAlready(String url) async {
    // debugPrint("not summerized already");
    try {
      String summary = await summarizeArticle.summarizeArticle(context, url);

      final box = Hive.box<List<String>>('preferences');
      await box.put(url, summary.split(',').map((s) => s.trim()).toList());

      // debugPrint("not Summary: $summary");
      return summary.split(',').map((s) => s.trim()).toList();
    } catch (e) {
      // Handle the exception
      debugPrint("Error occurred while summarizing: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to summarize the article. Please try again."),
          ),
        );
      }
      // Return an empty list or a default value
      return []; // Return an empty list if summarization fails
    }
  }

  Future<void> fetchAiHighlights(String url, BuildContext context) async {
    var browserModel = Provider.of<BrowserModel>(context, listen: false);
    var webViewModel = browserModel.getCurrentTab()?.webViewModel;
    var webViewController = webViewModel?.webViewController;

    {
      final box = Hive.box<List<String>>('preferences');
      // debugPrint('articlelink $url');
      List<String>? listSummary = box.get(url);
      listSummary ??= await summarizeIfNotAlready(url);
      String jsCode = await loadLocalJs();
      // Inject the list of strings to highlight into the JavaScript code
      String finalJsCode = """
        window.textToHighlightList = ${listSummary.map((e) => "'${e.replaceAll("'", "\\'")}'").toList()};
        $jsCode
      """;
      // String newJS = await load();

      await webViewController!.evaluateJavascript(source: finalJsCode);
      // debugPrint("rrrrrrrrrrrr" + result.toString());
    }
  }

  String _extractBaseDomain(String domain) {
    final parts = domain.split('.');
    return parts.length > 2
        ? parts.sublist(parts.length - 2).join('.')
        : domain;
  }

  /// Helper function to check if a URL points to a valid image
  Future<bool> _isValidImageUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      final contentType = response.headers['content-type'] ?? '';
      return response.statusCode == 200 && contentType.startsWith('image/');
    } catch (e) {
      // print("Error checking image URL: $url, Error: $e");
      return false;
    }
  }

  String _extractNameFromInput(String value) {
    String result;

    if (value.contains("://")) {
      final url = WebUri(value);
      final parts = url.host.split('.');

      // Find the longest part in the domain
      result = parts.reduce((a, b) => a.length >= b.length ? a : b);
    } else {
      final words = value.split(' ');
      // If there are one or two words, take both; otherwise, take the first two
      result = words.length <= 2 ? value : words.take(2).join(' ');
    }

    // Capitalize the first character and concatenate with the rest of the string
    if (result.isNotEmpty) {
      return result[0].toUpperCase() + result.substring(1);
    }

    return result; // Return empty string if result is empty
  }

  Future<void> _saveMostVisitedWebsite(String urlString) async {
    final url = WebUri(urlString);
    final box = Hive.box<MostVisitedWebsiteModel>('mostVisitedWebsites');
    final now = DateTime.now();

    // Extract title and favicon from WebViewModel
    var browserModel = Provider.of<BrowserModel>(context, listen: false);
    var webViewModel = browserModel.getCurrentTab()?.webViewModel;

    // final name = webViewModel?.title.toString() ?? url.host;
    final name = _extractNameFromInput(urlString);
    final faviconUrl =
        webViewModel?.favicon ?? "${url.scheme}://${url.host}/favicon.ico";

    // Skip saving if URL starts with "www.google"
    if (url.host.startsWith("www.google")) {
      // print("Skipped saving: $urlString (Google URL)");
      return;
    }

    // Check if the favicon exists and is an image
    if (!await _isValidImageUrl(faviconUrl.toString())) {
      // print("Skipped saving: $urlString (Invalid or missing favicon)");
      return;
    }

    // Normalize the base domain
    final baseDomain = _extractBaseDomain(url.host);

    // Check if a similar domain already exists in the box
    final existingWebsite =
        box.values.cast<MostVisitedWebsiteModel?>().firstWhere(
              (website) =>
                  website != null &&
                  _extractBaseDomain(WebUri(website.domain).host) == baseDomain,
              orElse: () => null,
            );

    if (existingWebsite != null) {
      // Update visit count and last visit time
      existingWebsite.visitCount += 1;
      existingWebsite.addedAt = now;
      await existingWebsite.save();
      // print("Updated existing website: ${existingWebsite.domain}");
    } else {
      // Add a new entry
      await box.add(
        MostVisitedWebsiteModel(
          id: GlobalKey().toString(),
          domain: urlString,
          faviconUrl: faviconUrl.toString(),
          visitCount: 1,
          addedAt: now,
          isFavorite: false,
          name: name,
        ),
      );
      // print("Added new website: $urlString");
    }
  }
}
