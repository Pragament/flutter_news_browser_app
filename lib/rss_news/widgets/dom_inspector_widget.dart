// lib/rss_news/widgets/dom_inspector_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_browser/models/browser_model.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'package:flutter_browser/models/window_model.dart';
import 'package:flutter_browser/rss_news/utils/debug.dart';
import 'package:flutter_browser/Db/hive_db_helper.dart';
import 'package:flutter_browser/rss_news/models/rules_model.dart';
import 'package:flutter_browser/rss_news/utils/show_snackbar.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

class DomInspectorWidget extends StatefulWidget {
  const DomInspectorWidget({Key? key}) : super(key: key);

  @override
  State<DomInspectorWidget> createState() => _DomInspectorWidgetState();
}

class _DomInspectorWidgetState extends State<DomInspectorWidget> {
  @override
  Widget build(BuildContext context) {
    var currentWebViewModel = Provider.of<WebViewModel>(context, listen: true);
    var browserModel = Provider.of<BrowserModel>(context, listen: true);

   
   final windowModel = Provider.of<WindowModel>(context, listen: true);
   bool hasActiveWebView = windowModel.webViewTabs.isNotEmpty && 
                       currentWebViewModel.webViewController != null;

    return SwitchListTile(
      title: const Text("Inspect elements mode"),
      subtitle: const Text("Selecting an element in the page to inspect it"),
      value: currentWebViewModel.isInspectMode,
      onChanged: hasActiveWebView ? (value) {
        setState(() {
          currentWebViewModel.isInspectMode = value;
          _toggleInspectorMode(currentWebViewModel, value);
        });
      } : null,
    );
  }

  void _toggleInspectorMode(WebViewModel webViewModel, bool enabled) {
    if (webViewModel.webViewController == null) return;
    
    if (enabled) {
      _injectInspectorScript(webViewModel.webViewController!);
    } else {
      _disableInspectorScript(webViewModel.webViewController!);
    }
  }

  void _injectInspectorScript(InAppWebViewController controller) {
    controller.evaluateJavascript(source: '''
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
        
        return "Inspector mode enabled";
      })();
    ''');
  }

  void _disableInspectorScript(InAppWebViewController controller) {
    controller.evaluateJavascript(source: '''
      (function() {
        // Remove all event listeners
        if (window.inspectorClickHandler) {
          document.removeEventListener('click', window.inspectorClickHandler, true);
        }
        
        if (window.inspectorMouseOverHandler) {
          document.removeEventListener('mouseover', window.inspectorMouseOverHandler, true);
        }
        
        if (window.inspectorMouseOutHandler) {
          document.removeEventListener('mouseout', window.inspectorMouseOutHandler, true);
        }
        
        // Reset styles
        if (window.inspectorHighlightedElement) {
          window.inspectorHighlightedElement.style.outline = 
            window.inspectorOriginalStyles.get(window.inspectorHighlightedElement) || '';
        }
        
        // Reset temp styles
        if (window.inspectorTempStyles) {
          window.inspectorTempStyles.forEach((originalStyle, element) => {
            element.style.outline = originalStyle || '';
          });
        }
        
        // Clear stored references
        window.inspectorOriginalStyles = null;
        window.inspectorTempStyles = null;
        window.inspectorHighlightedElement = null;
        
        return "Inspector mode disabled";
      })();
    ''');
  }

  void _showInspectorDialog(BuildContext context, Map<dynamic, dynamic> elementData) {
    String? ruleCategory;
    String? ruleType;
    String? ruleValue;
    String? websiteDomainValue;
    
    // Pre-fill with data from selection
    if (elementData['id'] != null && elementData['id'].toString().isNotEmpty) {
      ruleType = "Id";
      ruleValue = elementData['id'].toString();
    } else if (elementData['className'] != null && elementData['className'].toString().isNotEmpty) {
      ruleType = "Class";
      ruleValue = elementData['className'].toString().split(' ')[0];
    }
    
    // Pre-fill domain
    final webViewModel = Provider.of<WebViewModel>(context, listen: false);
    if (webViewModel.url != null) {
      websiteDomainValue = webViewModel.url!.host;
    }
    
    TextEditingController ruleValueController = 
        TextEditingController(text: ruleValue);
        
    TextEditingController websiteDomainController = 
        TextEditingController(text: websiteDomainValue);
    
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
                  ruleValue == null ||
                  websiteDomainValue == null) {
                // If any field is empty, show an error
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
                  value: ruleValue!,
                  domain: websiteDomainValue!,
                ));
                
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