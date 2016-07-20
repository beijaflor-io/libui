// 28 april 2015
#import "uipriv_darwin.h"

static NSMutableArray *menus = nil;
static BOOL menusFinalized = NO;

struct uiMenuIcon {
	NSStatusItem *statusItem;
	NSMenu *menu;
	NSMenuItem *item;
	NSMutableArray *items;
};

struct uiMenuIconItem {
	NSMenuItem *item;
	int type;
	BOOL disabled;
	void (*onClicked)(uiMenuIconItem *, uiWindow *, void *);
	void *onClickedData;
};

enum {
	typeRegular,
	typeCheckbox,
	typeQuit,
	typePreferences,
	typeAbout,
	typeSeparator,
};

static void mapItemReleaser(void *key, void *value)
{
	uiMenuIconItem *item;
 
	item = (uiMenuIconItem *)value;
	[item->item release];
}

static void defaultOnClicked(uiMenuIconItem *item, uiWindow *w, void *data)
{
	// do nothing
}

void uiMenuIconItemEnable(uiMenuIconItem *item)
{
	item->disabled = NO;
	// we don't need to explicitly update the menus here; they'll be updated the next time they're opened (thanks mikeash in irc.freenode.net/#macdev)
}

void uiMenuIconItemDisable(uiMenuIconItem *item)
{
	item->disabled = YES;
}

void uiMenuIconItemOnClicked(uiMenuIconItem *item, void (*f)(uiMenuIconItem *, uiWindow *, void *), void *data)
{
	if (item->type == typeQuit)
		userbug("You can't call uiMenuIconItemOnClicked() on a Quit item; use uiOnShouldQuit() instead.");
	item->onClicked = f;
	item->onClickedData = data;
}

int uiMenuIconItemChecked(uiMenuIconItem *item)
{
	return [item->item state] != NSOffState;
}

void uiMenuIconItemSetChecked(uiMenuIconItem *item, int checked)
{
	NSInteger state;

	state = NSOffState;
	if ([item->item state] == NSOffState)
		state = NSOnState;
	[item->item setState:state];
}

static uiMenuIconItem *newItem(uiMenuIcon *m, int type, const char *name)
{
	@autoreleasepool {

	uiMenuIconItem *item;

	if (menusFinalized)
		userbug("You can't create a new menu item after menus have been finalized.");

	item = uiNew(uiMenuIconItem);

	item->type = type;
	switch (item->type) {
	case typeQuit:
		item->item = [appDelegate().menuManager.quitItem retain];
		break;
	case typePreferences:
		item->item = [appDelegate().menuManager.preferencesItem retain];
		break;
	case typeAbout:
		item->item = [appDelegate().menuManager.aboutItem retain];
		break;
	case typeSeparator:
		item->item = [[NSMenuItem separatorItem] retain];
		[m->menu addItem:item->item];
		break;
	default:
		item->item = [[NSMenuItem alloc] initWithTitle:toNSString(name) action:@selector(onClicked:) keyEquivalent:@""];
		[item->item setTarget:appDelegate().menuManager];
		[m->menu addItem:item->item];
		break;
	}

	[appDelegate().menuManager register:item->item to:item];
	item->onClicked = defaultOnClicked;

	[m->items addObject:[NSValue valueWithPointer:item]];

	return item;

	} // @autoreleasepool
}

uiMenuIconItem *uiMenuIconAppendItem(uiMenuIcon *m, const char *name)
{
	return newItem(m, typeRegular, name);
}

uiMenuIconItem *uiMenuIconAppendCheckItem(uiMenuIcon *m, const char *name)
{
	return newItem(m, typeCheckbox, name);
}

uiMenuIconItem *uiMenuIconAppendQuitItem(uiMenuIcon *m)
{
	// duplicate check is in the register:to: selector
	return newItem(m, typeQuit, NULL);
}

uiMenuIconItem *uiMenuIconAppendPreferencesItem(uiMenuIcon *m)
{
	// duplicate check is in the register:to: selector
	return newItem(m, typePreferences, NULL);
}

uiMenuIconItem *uiMenuIconAppendAboutItem(uiMenuIcon *m)
{
	// duplicate check is in the register:to: selector
	return newItem(m, typeAbout, NULL);
}

void uiMenuIconAppendSeparator(uiMenuIcon *m)
{
	newItem(m, typeSeparator, NULL);
}

uiMenuIcon *uiNewMenuIcon(const char *name)
{
	@autoreleasepool {

	uiMenuIcon *m;

	if (menusFinalized)
		userbug("You can't create a new menu after menus have been finalized.");
	if (menus == nil)
		menus = [NSMutableArray new];

	m = uiNew(uiMenuIcon);

	m->statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  m->statusItem.title = toNSString("Stuff");
  // m->statusItem.image = [NSImage imageNamed:@"NSICloudDownload"];
	m->menu = [[NSMenu alloc] initWithTitle:toNSString(name)];

  appDelegate().statusItem = m->statusItem;

	m->item = [[NSMenuItem alloc] initWithTitle:toNSString(name) action:NULL keyEquivalent:@""];
	[m->item setSubmenu:m->menu];

	m->items = [NSMutableArray new];
  m->statusItem.menu = m->menu;

	[menus addObject:[NSValue valueWithPointer:m]];

	return m;

	} // @autoreleasepool
}

void finalizeMenuIcons(void)
{
	menusFinalized = YES;
}

void uninitMenuIcons(void)
{
	if (menus == NULL)
		return;
	[menus enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		NSValue *v;
		uiMenuIcon *m;

		v = (NSValue *) obj;
		m = (uiMenuIcon *) [v pointerValue];
		[m->items enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
			NSValue *v;
			uiMenuIconItem *mi;

			v = (NSValue *) obj;
			mi = (uiMenuIconItem *) [v pointerValue];
			uiFree(mi);
		}];
		[m->items release];
		uiFree(m);
	}];
	[menus release];
}
