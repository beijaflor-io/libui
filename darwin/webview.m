// 15 august 2015
#import "uipriv_darwin.h"

struct uiWebview {
	uiDarwinControl c;
	WebView *webview;
};


static void uiWebviewDestroy(uiControl *c)
{
}

uiDarwinControlAllDefaultsExceptDestroy(uiWebview, webview)

uiWebview *uiNewWebview(const char *url) {
  uiWebview *w;
	uiDarwinNewControl(uiWebview, w);

  w->webview = [[WebView alloc] initWithFrame:NSZeroRect];
  [[w->webview mainFrame]
    loadRequest:[NSURLRequest
                  requestWithURL:[NSURL URLWithString:toNSString(url)]]];
  return w;
}
