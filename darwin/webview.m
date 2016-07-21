// 15 august 2015
#import "uipriv_darwin.h"

struct uiWebview {
  uiDarwinControl c;
  WebView *webview;
  void (*onLoad)(uiButton *, void *);
  void *onLoadData;
};

@interface webviewDelegateClass : NSObject {
  struct mapTable *webviews;
}
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
- (void)registerWebview:(uiWebview *)w;
- (void)unregisterWebview:(uiWebview *)w;
@end

@implementation webviewDelegateClass
- (id)init {
  self = [super init];
  if (self)
    self->webviews = newMap();
  return self;
}

- (void)dealloc {
  mapDestroy(self->webviews);
  [super dealloc];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
  uiWebview *w;
  w = (uiWebview *) mapGet(self->webviews, sender);
  (*(w->onLoad))(w, w->onLoadData);
}

- (void)registerWebview:(uiWebview *)w {
  mapSet(self->webviews, w->webview, w);
  [w->webview setFrameLoadDelegate:self];
}

- (void)unregisterWebview:(uiWebview *)w {
  [w->webview setFrameLoadDelegate:nil];
  mapDelete(self->webviews, w->webview);
}
@end

static webviewDelegateClass *webviewDelegate = nil;

static void uiWebviewDestroy(uiControl *c) {
  uiWebview *w = uiWebview(c);

  [webviewDelegate unregisterWebview:w];
  [w->webview release];
  uiFreeControl(uiControl(w));
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

void uiWebviewOnLoad(uiWebview *w, void (*f)(uiWebview *, void*), void *data) {
  w->onLoad = f;
  w->onLoadData = data;
}

static void defaultOnLoad(uiWebview *w, void *data) {
}

uiWebview *uiNewWebview() {
  uiWebview *w;
  uiDarwinNewControl(uiWebview, w);
  w->webview = [[WebView alloc] initWithFrame:NSZeroRect];

  if (webviewDelegate == nil) {
    webviewDelegate = [[webviewDelegateClass new] autorelease];
    [delegates addObject:webviewDelegate];
  }
  [webviewDelegate registerWebview:w];
  uiWebviewOnLoad(w, defaultOnLoad, NULL);

  return w;
}
