// 15 august 2015
#import "uipriv_darwin.h"

struct uiWebview {
  uiDarwinControl c;
  WebView *webview;
};


static void uiWebviewDestroy(uiControl *c) {
}

uiDarwinControlAllDefaultsExceptDestroy(uiWebview, webview)

void uiWebviewLoadHTML(uiWebview *w, const char *html, const char *baseUrl) {
  [[w->webview mainFrame] loadHTMLString: toNSString(html)
                                 baseURL: [NSURL URLWithString:toNSString(baseUrl)]];
}

void uiWebviewLoadUrl(uiWebview *w, const char *url) {
  [[w->webview mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:toNSString(url)]]];
}

char* uiWebviewEval(uiWebview *w, const char *script) {
  return [[w->webview stringByEvaluatingJavaScriptFromString:toNSString(script)] UTF8String];
}

uiWebview *uiNewWebview() {
  uiWebview *w;
  uiDarwinNewControl(uiWebview, w);
  w->webview = [[WebView alloc] initWithFrame:NSZeroRect];
  return w;
}
