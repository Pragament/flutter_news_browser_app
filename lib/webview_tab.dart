import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_browser/Db/hive_db_helper.dart';
import 'package:flutter_browser/main.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'package:flutter_browser/rss_news/grpahql/graphql_requests.dart';
import 'package:flutter_browser/rss_news/models/rules_model.dart';
import 'package:flutter_browser/rss_news/models/website_list.dart';
import 'package:flutter_browser/rss_news/provider/adblock_filter_provider.dart';
import 'package:flutter_browser/rss_news/services/custom_rules.dart';
import 'package:flutter_browser/rss_news/services/hilighting.dart';
import 'package:flutter_browser/rss_news/services/whitelist.dart';
import 'package:flutter_browser/rss_news/utils/debug.dart';
import 'package:flutter_browser/rss_news/utils/show_snackbar.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'javascript_console_result.dart';
import 'long_press_alert_dialog.dart';
import 'models/browser_model.dart';
import 'models/window_model.dart';

class WebViewTab extends StatefulWidget {
 WebViewTab({super.key, required this.webViewModel});

  final WebViewModel webViewModel;
  final FocusNode _focusNode = FocusNode();
  
  // Add a method to access the state
  _WebViewTabState? getState() => key is GlobalKey<_WebViewTabState> ? (key as GlobalKey<_WebViewTabState>).currentState : null;

  @override
  State<WebViewTab> createState() => _WebViewTabState();
}


class _WebViewTabState extends State<WebViewTab> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  FindInteractionController? _findInteractionController;
  FocusNode? _focusNode;
  bool _isWindowClosed = false;
  CustomRules customRules = CustomRules();
  final TextEditingController _httpAuthUsernameController =
      TextEditingController();
  final TextEditingController _httpAuthPasswordController =
      TextEditingController();
  var _isWebsiteAllowed = true;
  ContextMenu? contextMenu;
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _focusNode = FocusNode();
    _isWebsiteAllowed = Whitelist.isWebsiteAllowed(widget.webViewModel.url!);
    if (_isWebsiteAllowed) {
      _pullToRefreshController = kIsWeb
          ? null
          : PullToRefreshController(
              settings: PullToRefreshSettings(color: Colors.blue),
              onRefresh: () async {
                if (defaultTargetPlatform == TargetPlatform.android) {
                  _webViewController?.reload();
                } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                  _webViewController?.loadUrl(
                      urlRequest:
                          URLRequest(url: await _webViewController?.getUrl()));
                }
              },
            );

      _findInteractionController = FindInteractionController();
      setupContextMenu();
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    widget.webViewModel.webViewController = null;
    widget.webViewModel.pullToRefreshController = null;
    widget.webViewModel.findInteractionController = null;
    _httpAuthUsernameController.dispose();
    _httpAuthPasswordController.dispose();

    _focusNode?.dispose();
     _focusNode = null;

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_webViewController != null && (Util.isAndroid() || Util.isWindows())) {
      if (state == AppLifecycleState.paused) {
        pauseAll();
      } else {
        resumeAll();
      }
    }
  }

  void pauseAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
    pauseTimers();
  }

  void resumeAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
    resumeTimers();
  }

  void pause() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
  }

  void resume() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
  }

  void pauseTimers() {
    if (!Util.isWindows()) {
      _webViewController?.pauseTimers();
    }
  }

  void resumeTimers() {
    if (!Util.isWindows()) {
      _webViewController?.resumeTimers();
    }
  }

  void setupContextMenu() {
    contextMenu = ContextMenu(
      menuItems: [
        ContextMenuItem(
          id: 0,
          title: "Highlight",
          action: () async {
            await _webViewController?.evaluateJavascript(
              source: 'window.highlightSelection()',
            );
          },
        ),
        ContextMenuItem(
          id: 1,
          title: "Copy",
          action: () async {
            await _webViewController?.evaluateJavascript(
              source: 'document.execCommand("copy")',
            );
          },
        ),
        ContextMenuItem(
          id: 2,
          title: "Select All",
          action: () async {
            await _webViewController?.evaluateJavascript(
              source: 'document.execCommand("selectAll")',
            );
          },
        ),
        ContextMenuItem(
          id: 3,
          title: "Share",
          action: () async {
            final selectedText = await _webViewController?.evaluateJavascript(
              source: 'window.getSelection().toString()',
            );
            if (selectedText != null && selectedText.isNotEmpty) {
              await Share.share(selectedText);
            }
          },
        ),
        ContextMenuItem(
          id: 4,
          title: "Web Search",
          action: () async {
            final selectedText = await _webViewController?.evaluateJavascript(
              source: 'window.getSelection().toString()',
            );
            if (selectedText != null && selectedText.isNotEmpty) {
              final encodedQuery = Uri.encodeComponent(selectedText);
              final url =
                  WebUri('https://www.google.com/search?q=$encodedQuery');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            }
          },
        ),
      ],
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
    );
  }

  Future<String> loadLocalJs() async {
    return await rootBundle.loadString('assets/js/highlighting.js');
  }

  @override
  Widget build(BuildContext context) {
    return !_isWebsiteAllowed
        ? const Center(
            child: Text("Website Not Allowed"),
          )
        : Container(
            color: Colors.white,
            child: _buildWebView(),
          );
  }

  InAppWebView _buildWebView() {
    var browserModel = Provider.of<BrowserModel>(context, listen: true);
    var windowModel = Provider.of<WindowModel>(context, listen: true);
    var settings = browserModel.getSettings();
    var currentWebViewModel = Provider.of<WebViewModel>(context, listen: true);
    var adblockFilterProvider = Provider.of<AdblockFilterProvider>(context);

    if (Util.isAndroid()) {
      InAppWebViewController.setWebContentsDebuggingEnabled(
          settings.debuggingEnabled);
    }

    var initialSettings = widget.webViewModel.settings!;
    initialSettings.isInspectable = settings.debuggingEnabled;
    initialSettings.useOnDownloadStart = true;
    initialSettings.useOnLoadResource = true;
    initialSettings.useShouldOverrideUrlLoading = true;
    initialSettings.javaScriptCanOpenWindowsAutomatically = true;
    if (Util.isIOS() || Util.isAndroid()) {
      initialSettings.userAgent =
          "Mozilla/5.0 (Linux; Android 9; LG-H870 Build/PKQ1.190522.001) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36";
    }
    initialSettings.transparentBackground = true;

    initialSettings.safeBrowsingEnabled = true;
    initialSettings.disableDefaultErrorPage = true;
    initialSettings.supportMultipleWindows = true;
    initialSettings.verticalScrollbarThumbColor =
        const Color.fromRGBO(0, 0, 0, 0.5);
    initialSettings.horizontalScrollbarThumbColor =
        const Color.fromRGBO(0, 0, 0, 0.5);

    initialSettings.allowsLinkPreview = false;
    initialSettings.isFraudulentWebsiteWarningEnabled = true;
    initialSettings.disableLongPressContextMenuOnLinks = true;
    initialSettings.allowingReadAccessTo = WebUri('file://$WEB_ARCHIVE_DIR/');

    return InAppWebView(
      contextMenu: contextMenu,
      keepAlive: widget.webViewModel.keepAlive,
      // webViewEnvironment: webViewEnvironment,
      initialUrlRequest: URLRequest(url: widget.webViewModel.url),
      initialSettings: initialSettings,
      windowId: widget.webViewModel.windowId,
      pullToRefreshController: _pullToRefreshController,
      findInteractionController: _findInteractionController,
      onWebViewCreated: (controller) async {
        initialSettings.transparentBackground = false;
        await controller.setSettings(settings: initialSettings);

        _webViewController = controller;
        widget.webViewModel.webViewController = controller;
        widget.webViewModel.pullToRefreshController = _pullToRefreshController;
        widget.webViewModel.findInteractionController =
            _findInteractionController;

        if (Util.isAndroid()) {
          controller.startSafeBrowsing();
        }

        widget.webViewModel.settings = await controller.getSettings();

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        }
        controller.addJavaScriptHandler(
          handlerName: 'onHighlight',
          callback: (args) async {
            if (args.isNotEmpty) {
              String jsCode = await loadLocalJs();

              await _webViewController!.evaluateJavascript(source: jsCode);

              String hashFun = """ window.generateContentFingerprint() """;
              String hash =
                  await _webViewController!.evaluateJavascript(source: hashFun);

              await HiveDBHelper.addHighlight(hash, args[0]);
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Highlighted text: ${args[0]}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
        
        // Setup DOM inspector handler (will only be used when inspection mode is active)
        controller.addJavaScriptHandler(
          handlerName: 'inspectorElementSelected',
          callback: (args) async {
            if (args.isNotEmpty && widget.webViewModel.isInspectMode) {
              final elementData = args[0];
              debug('Selected element: $elementData');
              
              // Pre-populate rule values
              String? ruleCategory;
              String? ruleType;
              String ruleValue = '';
              String websiteDomainValue = widget.webViewModel.url?.host ?? '';
              
              // Set the rule type and value based on the selected element
              if (elementData['id'] != null && elementData['id'].toString().isNotEmpty) {
                ruleType = "Id";
                ruleValue = elementData['id'].toString();
              } else if (elementData['className'] != null && elementData['className'].toString().isNotEmpty) {
                ruleType = "Class";
                ruleValue = elementData['className'].toString().split(' ')[0];
              }
              
              TextEditingController ruleValueController = 
                  TextEditingController(text: ruleValue);
                  
              TextEditingController websiteDomainController = 
                  TextEditingController(text: websiteDomainValue);
              
              // ignore: use_build_context_synchronously
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Add Rule from Selected Element"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Element: ${elementData['tagName']}"),
                      if (elementData['id'] != null && elementData['id'].toString().isNotEmpty)
                        Text("ID: ${elementData['id']}"),
                      if (elementData['className'] != null && elementData['className'].toString().isNotEmpty)
                        Text("Class: ${elementData['className']}"),
                        
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: ruleCategory,
                        items: const [
                          DropdownMenuItem(
                            value: "AdBlock",
                            child: Text("Adblock"),
                          ),
                          DropdownMenuItem(
                            value: "Immersive Reader",
                            child: Text("Immersive Reader"),
                          ),
                        ],
                        onChanged: (String? value) {
                          ruleCategory = value!;
                        },
                        decoration: const InputDecoration(labelText: "Rule Category"),
                      ),
                      
                      DropdownButtonFormField<String>(
                        value: ruleType,
                        items: const [
                          DropdownMenuItem(
                            value: "Class",
                            child: Text("Class"),
                          ),
                          DropdownMenuItem(
                            value: "Id",
                            child: Text("Id"),
                          ),
                        ],
                        onChanged: (String? value) {
                          ruleType = value!;
                        },
                        decoration: const InputDecoration(labelText: "Rule Type"),
                      ),
                      
                      TextField(
                        onChanged: (value) => ruleValue = value,
                        controller: ruleValueController,
                        decoration: const InputDecoration(labelText: "Class or Id"),
                      ),
                      
                      TextField(
                        onChanged: (value) => websiteDomainValue = value,
                        controller: websiteDomainController,
                        decoration: const InputDecoration(labelText: "Website Domain"),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (ruleCategory == null ||
                            ruleType == null ||
                            ruleValue.isEmpty ||
                            websiteDomainValue.isEmpty) {
                          // If any field is empty, show an error
                          // ignore: use_build_context_synchronously
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Error"),
                              content: const Text("All fields are required."),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close the error dialog
                                  },
                                  child: const Text("OK"),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Add the rule
                          await HiveDBHelper.addRule(Rules(
                            category: ruleCategory!,
                            type: ruleType!,
                            value: ruleValue,
                            domain: websiteDomainValue,
                          ));
                          
                          // Apply the rule immediately
                          await customRules.removeElementsUsingRules(
                            _webViewController,
                            ruleCategory!,
                            ruleType!,
                            ruleCategory == "AdBlock" 
                              ? browserModel.getSettings().adsDisabled 
                              : browserModel.getSettings().immersiveReaderEnabled,
                            widget.webViewModel.url
                          );
                          
                          // Show success message
                          showSnackBar(message: "Rule added successfully");
                          
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("Add"),
                    ),
                  ],
                ),
              );
            }
          }
        );
      },
      onLoadStart: (controller, url) async {
        widget.webViewModel.isSecure = Util.urlIsSecure(url!);
        widget.webViewModel.url = url;
        widget.webViewModel.loaded = false;
        widget.webViewModel.setLoadedResources([]);
        widget.webViewModel.setJavaScriptConsoleResults([]);

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        } else if (widget.webViewModel.needsToCompleteInitialLoad) {
          controller.stopLoading();
        }

        windowModel.notifyWebViewTabUpdated();
      },
      onLoadStop: (controller, url) async {
        _pullToRefreshController?.endRefreshing();
        await HilightService().highlightText(
            _webViewController, widget.webViewModel.url.toString());
        await customRules.removeElementsUsingRules(
            _webViewController,
            "AdBlock",
            "Id",
            browserModel.getSettings().adsDisabled,
            widget.webViewModel.url);
        await customRules.removeElementsUsingRules(
            _webViewController,
            "AdBlock",
            "Class",
            browserModel.getSettings().adsDisabled,
            widget.webViewModel.url);
        await customRules.removeElementsUsingRules(
            _webViewController,
            "Immersive Reader",
            "Id",
            browserModel.getSettings().immersiveReaderEnabled,
            widget.webViewModel.url);
        await customRules.removeElementsUsingRules(
            _webViewController,
            "Immersive Reader",
            "Class",
            browserModel.getSettings().immersiveReaderEnabled,
            widget.webViewModel.url);
        await customRules.removeHeaderAndFooter(_webViewController);

        widget.webViewModel.url = url;
        widget.webViewModel.favicon = null;
        widget.webViewModel.loaded = true;
        if (url != null && HiveDBHelper.getDevice() != null) {
          await GraphQLRequests().pushLog(url.host.toString(), url.toString(),
              HiveDBHelper.getDevice()!.id!, "Duplicate");
        }

        await HilightService().injectHighlightJS(_webViewController);

        var sslCertificateFuture = controller.getCertificate();
        var titleFuture = controller.getTitle();
        var faviconsFuture = controller.getFavicons();

        var sslCertificate = await sslCertificateFuture;
        if (sslCertificate == null && !Util.isLocalizedContent(url!)) {
          widget.webViewModel.isSecure = false;
        }

        widget.webViewModel.title = await titleFuture;

        List<Favicon>? favicons;
        try {
          favicons = await faviconsFuture;
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
        }
        if (favicons != null && favicons.isNotEmpty) {
          for (var fav in favicons) {
            if (widget.webViewModel.favicon == null) {
              widget.webViewModel.favicon = fav;
            } else {
              if ((widget.webViewModel.favicon!.width == null &&
                      !widget.webViewModel.favicon!.url
                          .toString()
                          .endsWith("favicon.ico")) ||
                  (fav.width != null &&
                      widget.webViewModel.favicon!.width != null &&
                      fav.width! > widget.webViewModel.favicon!.width!)) {
                widget.webViewModel.favicon = fav;
              }
            }
          }
        }

        if (isCurrentTab(currentWebViewModel)) {
          widget.webViewModel.needsToCompleteInitialLoad = false;
          currentWebViewModel.updateWithValue(widget.webViewModel);

          var screenshotData = controller
              .takeScreenshot(
                  screenshotConfiguration: ScreenshotConfiguration(
                      compressFormat: CompressFormat.JPEG, quality: 20))
              .timeout(
                const Duration(milliseconds: 1500),
                onTimeout: () => null,
              );
          widget.webViewModel.screenshot = await screenshotData;
        }
        
        // Re-inject inspector script if inspect mode is enabled
        if (widget.webViewModel.isInspectMode) {
          await controller.evaluateJavascript(source: '''
            (function() {
              // Store original styles
              window.inspectorOriginalStyles = new Map();
              window.inspectorHighlightedElement = null;
              
              // Add highlight function
              window.inspectorHighlightElement = function(element) {
                // Reset previous element if exists
                if (window.inspectorHighlightedElement) {
                  window.inspectorHighlightedElement.style.outline = window.inspectorOriginalStyles.get(window.inspectorHighlightedElement) || '';
                }
                
                // Store original style and highlight new element
                window.inspectorOriginalStyles.set(element, element.style.outline);
                element.style.outline = '2px solid red';
                window.inspectorHighlightedElement = element;
              };
              
              // Event handler for clicks
              window.inspectorClickHandler = function(event) {
                event.preventDefault();
                event.stopPropagation();
                
                // Extract element data
                const el = event.target;
                const computedStyle = window.getComputedStyle(el);
                
                // Create attribute list
                const attributes = {};
                for (let i = 0; i < el.attributes.length; i++) {
                  const attr = el.attributes[i];
                  attributes[attr.name] = attr.value;
                }
                
                // Highlight the element
                window.inspectorHighlightElement(el);
                
                // Send data to Flutter
                window.flutter_inappwebview.callHandler('inspectorElementSelected', {
                  tagName: el.tagName,
                  id: el.id,
                  className: el.className,
                  attributes: attributes,
                  innerText: el.innerText ? el.innerText.substring(0, 100) : '',
                  computedStyles: {
                    width: computedStyle.width,
                    height: computedStyle.height,
                    backgroundColor: computedStyle.backgroundColor,
                    color: computedStyle.color,
                    display: computedStyle.display,
                    position: computedStyle.position
                  }
                });
                
                return false;
              };
              
              // Add event listeners to all elements
              document.addEventListener('click', window.inspectorClickHandler, true);
              
              // Add mouseover highlighting
              window.inspectorMouseOverHandler = function(event) {
                const el = event.target;
                
                // Store original style and add highlight
                if (!window.inspectorTempStyles) {
                  window.inspectorTempStyles = new Map();
                }
                
                if (!window.inspectorTempStyles.has(el)) {
                  window.inspectorTempStyles.set(el, el.style.outline);
                }
                
                if (el !== window.inspectorHighlightedElement) {
                  el.style.outline = '2px dashed blue';
                }
              };
              
              window.inspectorMouseOutHandler = function(event) {
                const el = event.target;
                
                // Restore original style if not the selected element
                if (el !== window.inspectorHighlightedElement && window.inspectorTempStyles) {
                  el.style.outline = window.inspectorTempStyles.get(el) || '';
                  window.inspectorTempStyles.delete(el);
                }
              };
              
              document.addEventListener('mouseover', window.inspectorMouseOverHandler, true);
              document.addEventListener('mouseout', window.inspectorMouseOutHandler, true);
              
              return "Inspector mode re-enabled";
            })();
          ''');
        }
      },
      onProgressChanged: (controller, progress) {
        if (progress == 100) {
          _pullToRefreshController?.endRefreshing();
        }

        widget.webViewModel.progress = progress / 100;

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        }
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) async {
        widget.webViewModel.url = url;
        widget.webViewModel.title = await controller.getTitle();

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        }
        windowModel.notifyWebViewTabUpdated();
      },
      onLongPressHitTestResult: (controller, hitTestResult) async {
        if (LongPressAlertDialog.hitTestResultSupported
            .contains(hitTestResult.type)) {
          var requestFocusNodeHrefResult =
              await controller.requestFocusNodeHref();

          if (requestFocusNodeHrefResult != null) {
            showDialog(
              // ignore: use_build_context_synchronously
              context: context,
              builder: (context) {
                return LongPressAlertDialog(
                  webViewModel: widget.webViewModel,
                  hitTestResult: hitTestResult,
                  requestFocusNodeHrefResult: requestFocusNodeHrefResult,
                );
              },
            );
          }
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        Color consoleTextColor = Colors.black;
        Color consoleBackgroundColor = Colors.transparent;
        IconData? consoleIconData;
        Color? consoleIconColor;
        if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
          consoleTextColor = Colors.red;
          consoleIconData = Icons.report_problem;
          consoleIconColor = Colors.red;
        } else if (consoleMessage.messageLevel == ConsoleMessageLevel.TIP) {
          consoleTextColor = Colors.blue;
          consoleIconData = Icons.info;
          consoleIconColor = Colors.blueAccent;
        } else if (consoleMessage.messageLevel == ConsoleMessageLevel.WARNING) {
          consoleBackgroundColor = const Color.fromRGBO(255, 251, 227, 1);
          consoleIconData = Icons.report_problem;
          consoleIconColor = Colors.orangeAccent;
        }

        widget.webViewModel.addJavaScriptConsoleResults(JavaScriptConsoleResult(
          data: consoleMessage.message,
          textColor: consoleTextColor,
          backgroundColor: consoleBackgroundColor,
          iconData: consoleIconData,
          iconColor: consoleIconColor,
        ));

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        }
      },
      onLoadResource: (controller, resource) {
        widget.webViewModel.addLoadedResources(resource);

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        var url = navigationAction.request.url;

        if (url != null) {
          if (!Whitelist.isWebsiteAllowed(url)) {
            showSnackBar(message: 'This website is blocked: ${url.host}');
            // Cancel the navigation
            return NavigationActionPolicy.CANCEL;
          }
          // Handle non-standard schemes as before
          if (![
            "http",
            "https",
            "file",
            "chrome",
            "data",
            "javascript",
            "about"
          ].contains(url.scheme)) {
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
              return NavigationActionPolicy.CANCEL;
            }
          }
        }

        // Allow navigation for all other URLs
        return NavigationActionPolicy.ALLOW;
      },
      onDownloadStartRequest: (controller, url) async {
        String path = url.url.path;
        String fileName = path.substring(path.lastIndexOf('/') + 1);

        await FlutterDownloader.enqueue(
          url: url.toString(),
          fileName: fileName,
          savedDir: (await getTemporaryDirectory()).path,
          showNotification: true,
          openFileFromNotification: true,
        );
      },
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        var sslError = challenge.protectionSpace.sslError;
        if (sslError != null && (sslError.code != null)) {
          if ((Util.isIOS() || Util.isMacOS()) &&
              sslError.code == SslErrorType.UNSPECIFIED) {
            return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED);
          }
          widget.webViewModel.isSecure = false;
          if (isCurrentTab(currentWebViewModel)) {
            currentWebViewModel.updateWithValue(widget.webViewModel);
          }
          return ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.CANCEL);
        }
        return ServerTrustAuthResponse(
            action: ServerTrustAuthResponseAction.PROCEED);
      },
      onReceivedError: (controller, request, error) async {
        var isForMainFrame = request.isForMainFrame ?? false;
        if (!isForMainFrame) {
          return;
        }

        _pullToRefreshController?.endRefreshing();

        if ((Util.isIOS() || Util.isMacOS() || Util.isWindows()) &&
            error.type == WebResourceErrorType.CANCELLED) {
          // NSURLErrorDomain
          return;
        }
        if (Util.isWindows() &&
            error.type == WebResourceErrorType.CONNECTION_ABORTED) {
          // CONNECTION_ABORTED
          return;
        }

        var errorUrl = request.url;

        _webViewController?.loadData(data: """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <style>
    ${await InAppWebViewController.tRexRunnerCss}
    </style>
    <style>
    .interstitial-wrapper {
        box-sizing: border-box;
        font-size: 1em;
        line-height: 1.6em;
        margin: 0 auto 0;
        max-width: 600px;
        width: 100%;
    }
    </style>
</head>
<body>
    ${await InAppWebViewController.tRexRunnerHtml}
    <div class="interstitial-wrapper">
      <h1>Website not available</h1>
      <p>Could not load web pages at <strong>$errorUrl</strong> because:</p>
      <p>${error.description}</p>
    </div>
</body>
    """, baseUrl: errorUrl, historyUrl: errorUrl);

        widget.webViewModel.url = errorUrl;
        widget.webViewModel.isSecure = false;

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        }
      },
      onTitleChanged: (controller, title) async {
        widget.webViewModel.title = title;

        if (isCurrentTab(currentWebViewModel)) {
          currentWebViewModel.updateWithValue(widget.webViewModel);
        }
        windowModel.notifyWebViewTabUpdated();
      },
      onCreateWindow: (controller, createWindowRequest) async {
        var webViewTab = WebViewTab(
           key: GlobalKey<_WebViewTabState>(), 
          webViewModel: WebViewModel(
              url: WebUri("about:blank"),
              windowId: createWindowRequest.windowId),
        );

        windowModel.addTab(webViewTab);

        return true;
      },
      onCloseWindow: (controller) {
        if (_isWindowClosed) {
          return;
        }
        _isWindowClosed = true;
        if (widget.webViewModel.tabIndex != null) {
          windowModel.closeTab(widget.webViewModel.tabIndex!);
        }
      },
      onPermissionRequest: (controller, permissionRequest) async {
        return PermissionResponse(
            resources: permissionRequest.resources,
            action: PermissionResponseAction.GRANT);
      },
      onReceivedHttpAuthRequest: (controller, challenge) async {
        var action = await createHttpAuthDialog(challenge);
        return HttpAuthResponse(
            username: _httpAuthUsernameController.text.trim(),
            password: _httpAuthPasswordController.text,
            action: action,
            permanentPersistence: true);
      },
    );
  }

  bool isCurrentTab(WebViewModel currentWebViewModel) {
    return currentWebViewModel.tabIndex == widget.webViewModel.tabIndex;
  }

  Future<HttpAuthResponseAction> createHttpAuthDialog(
      URLAuthenticationChallenge challenge) async {
    HttpAuthResponseAction action = HttpAuthResponseAction.CANCEL;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Login"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(challenge.protectionSpace.host),
              TextField(
                decoration: const InputDecoration(labelText: "Username"),
                controller: _httpAuthUsernameController,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Password"),
                controller: _httpAuthPasswordController,
                obscureText: true,
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text("Cancel"),
              onPressed: () {
                action = HttpAuthResponseAction.CANCEL;
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Ok"),
              onPressed: () {
                action = HttpAuthResponseAction.PROCEED;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return action;
  }

  void onShowTab() async {
    resume();
    if (widget.webViewModel.needsToCompleteInitialLoad) {
      widget.webViewModel.needsToCompleteInitialLoad = false;
      if (Whitelist.isWebsiteAllowed(widget.webViewModel.url!)) {
        await widget.webViewModel.webViewController
            ?.loadUrl(urlRequest: URLRequest(url: widget.webViewModel.url));
      }
    }
  }

  void onHideTab() async {
    pause();
  }
}