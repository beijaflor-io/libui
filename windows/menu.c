// 24 april 2015
#include "uipriv_windows.h"

// TODO turn this into struct menu **
static struct menu *menus = NULL;
static uintmax_t len = 0;
static uintmax_t cap = 0;
static BOOL menusFinalized = FALSE;
static WORD curID = 100;			// start somewhere safe

struct menu {
	uiMenu m;
	WCHAR *name;
	// TODO turn into struct menuItem **
	struct menuItem *items;
	uintmax_t len;
	uintmax_t cap;
};

struct menuItem {
	uiMenuItem mi;
	WCHAR *name;
	int type;
	WORD id;
	void (*onClicked)(uiMenuItem *, uiWindow *, void *);
	void *onClickedData;
	BOOL disabled;				// template for new instances; kept in sync with everything else
	BOOL checked;
	HMENU *hmenus;
	uintmax_t len;
	uintmax_t cap;
};

enum {
	typeRegular,
	typeCheckbox,
	typeQuit,
	typePreferences,
	typeAbout,
	typeSeparator,
};

#define grow 32

static void sync(struct menuItem *item)
{
	uintmax_t i;
	MENUITEMINFOW mi;

	// TODO do we need to get the current state and amend it?
	ZeroMemory(&mi, sizeof (MENUITEMINFOW));
	mi.cbSize = sizeof (MENUITEMINFOW);
	mi.fMask = MIIM_STATE;
	if (item->disabled)
		mi.fState |= MFS_DISABLED;
	if (item->checked)
		mi.fState |= MFS_CHECKED;

	for (i = 0; i < item->len; i++)
		if (SetMenuItemInfo(item->hmenus[i], item->id, FALSE, &mi) == 0)
			logLastError("error synchronizing menu items in windows/menu.c sync()");
}

static void defaultOnClicked(uiMenuItem *item, uiWindow *w, void *data)
{
	// do nothing
}

static void menuItemEnable(uiMenuItem *ii)
{
	struct menuItem *item = (struct menuItem *) ii;

	item->disabled = FALSE;
	sync(item);
}

static void menuItemDisable(uiMenuItem *ii)
{
	struct menuItem *item = (struct menuItem *) ii;

	item->disabled = TRUE;
	sync(item);
}

static void menuItemOnClicked(uiMenuItem *ii, void (*f)(uiMenuItem *, uiWindow *, void *), void *data)
{
	struct menuItem *item = (struct menuItem *) ii;

	item->onClicked = f;
	item->onClickedData = data;
}

static int menuItemChecked(uiMenuItem *ii)
{
	struct menuItem *item = (struct menuItem *) ii;

	return item->checked != FALSE;
}

static void menuItemSetChecked(uiMenuItem *ii, int checked)
{
	struct menuItem *item = (struct menuItem *) ii;

	// use explicit values
	item->checked = FALSE;
	if (checked)
		item->checked = TRUE;
	sync(item);
}

static uiMenuItem *newItem(struct menu *m, int type, const char *name)
{
	struct menuItem *item;

	if (menusFinalized)
		complain("attempt to create a new menu item after menus have been finalized");

	if (m->len >= m->cap) {
		m->cap += grow;
		m->items = (struct menuItem *) uiRealloc(m->items, m->cap * sizeof (struct menuItem), "struct menuItem[]");
	}
	item = &(m->items[m->len]);
	m->len++;

	item->type = type;
	switch (item->type) {
	case typeQuit:
		item->name = toUTF16("Quit");
		break;
	case typePreferences:
		item->name = toUTF16("Preferences...");
		break;
	case typeAbout:
		item->name = toUTF16("About");
		break;
	case typeSeparator:
		// TODO this shouldn't be necessary, but uiRealloc() doesn't yet zero out new bytes
		item->name = NULL;
		break;
	default:
		item->name = toUTF16(name);
		break;
	}

	if (item->type != typeSeparator) {
		item->id = curID;
		curID++;
	}
	// TODO this shouldn't be necessary, but uiRealloc() doesn't yet zero out new bytes
	else
		item->id = 0;

	item->onClicked = defaultOnClicked;

	// TODO this shouldn't be necessary, but uiRealloc() doesn't yet zero out new bytes
	item->disabled = FALSE;
	item->checked = FALSE;
	item->hmenus = NULL;
	item->len = 0;
	item->cap = 0;

	uiMenuItem(item)->Enable = menuItemEnable;
	uiMenuItem(item)->Disable = menuItemDisable;
	uiMenuItem(item)->OnClicked = menuItemOnClicked;
	uiMenuItem(item)->Checked = menuItemChecked;
	uiMenuItem(item)->SetChecked = menuItemSetChecked;

	return uiMenuItem(item);
}

uiMenuItem *menuAppendItem(uiMenu *mm, const char *name)
{
	return newItem((struct menu *) mm, typeRegular, name);
}

uiMenuItem *menuAppendCheckItem(uiMenu *mm, const char *name)
{
	return newItem((struct menu *) mm, typeCheckbox, name);
}

uiMenuItem *menuAppendQuitItem(uiMenu *mm)
{
	// TODO check multiple quit items
	newItem((struct menu *) mm, typeSeparator, NULL);
	return newItem((struct menu *) mm, typeQuit, NULL);
}

uiMenuItem *menuAppendPreferencesItem(uiMenu *mm)
{
	// TODO check multiple preferences items
	newItem((struct menu *) mm, typeSeparator, NULL);
	return newItem((struct menu *) mm, typePreferences, NULL);
}

uiMenuItem *menuAppendAboutItem(uiMenu *mm)
{
	// TODO check multiple about items
	newItem((struct menu *) mm, typeSeparator, NULL);
	return newItem((struct menu *) mm, typeAbout, NULL);
}

void menuAppendSeparator(uiMenu *mm)
{
	// TODO check multiple about items
	newItem((struct menu *) mm, typeSeparator, NULL);
}

uiMenu *uiNewMenu(const char *name)
{
	struct menu *m;

	if (menusFinalized)
		complain("attempt to create a new menu after menus have been finalized");
	if (len >= cap) {
		cap += grow;
		menus = (struct menu *) uiRealloc(menus, cap * sizeof (struct menu), "struct menu[]");
	}
	m = &menus[len];
	len++;

	m->name = toUTF16(name);

	// TODO this shouldn't be necessary, but uiRealloc() doesn't yet zero out new bytes
	m->items = NULL;
	m->len = 0;
	m->cap = 0;

	uiMenu(m)->AppendItem = menuAppendItem;
	uiMenu(m)->AppendCheckItem = menuAppendCheckItem;
	uiMenu(m)->AppendQuitItem = menuAppendQuitItem;
	uiMenu(m)->AppendPreferencesItem = menuAppendPreferencesItem;
	uiMenu(m)->AppendAboutItem = menuAppendAboutItem;
	uiMenu(m)->AppendSeparator = menuAppendSeparator;

	return uiMenu(m);
}

static void appendMenuItem(HMENU menu, struct menuItem *item)
{
	UINT uFlags;

	uFlags = MF_SEPARATOR;
	if (item->type != typeSeparator) {
		uFlags = MF_STRING;
		if (item->disabled)
			uFlags |= MF_DISABLED | MF_GRAYED;
		if (item->checked)
			uFlags |= MF_CHECKED;
	}
	if (AppendMenuW(menu, uFlags, item->id, item->name) == 0)
		logLastError("error appending menu item in appendMenuItem()");

	if (item->len >= item->cap) {
		item->cap += grow;
		item->hmenus = (HMENU *) uiRealloc(item->hmenus, item->cap * sizeof (HMENU), "HMENU[]");
	}
	item->hmenus[item->len] = menu;
	item->len++;
}

static HMENU makeMenu(struct menu *m)
{
	HMENU menu;
	uintmax_t i;

	menu = CreatePopupMenu();
	if (menu == NULL)
		logLastError("error creating menu in makeMenu()");
	for (i = 0; i < m->len; i++)
		appendMenuItem(menu, &(m->items[i]));
	return menu;
}

// TODO should this return a zero-height widget (or NULL) if there are no menus defined?
HMENU makeMenubar(void)
{
	HMENU menubar;
	HMENU menu;
	uintmax_t i;

	menusFinalized = TRUE;

	menubar = CreateMenu();
	if (menubar == NULL)
		logLastError("error creating menubar in makeMenubar()");

	for (i = 0; i < len; i++) {
		menu = makeMenu(&menus[i]);
		if (AppendMenuW(menubar, MF_POPUP | MF_STRING, (UINT_PTR) menu, menus[i].name) == 0)
			logLastError("error appending menu to menubar in makeMenubar()");
	}

	return menubar;
}

void runMenuEvent(WORD id, uiWindow *w)
{
	struct menu *m;
	struct menuItem *item;
	uintmax_t i, j;
	uiMenuItem *umi;

	// TODO optimize this somehow?
	for (i = 0; i < len; i++) {
		m = &menus[i];
		for (j = 0; j < m->len; j++) {
			item = &(m->items[j]);
			if (item->id == id)
				goto found;
		}
	}
	// no match
	// TODO complain?
	return;

found:
	umi = uiMenuItem(item);

	// first toggle checkboxes, if any
	if (item->type == typeCheckbox)
		uiMenuItemSetChecked(umi, !uiMenuItemChecked(umi));

	// then run the event
	(*(item->onClicked))(umi, w, item->onClickedData);
}

static void freeMenu(struct menu *m, HMENU submenu)
{
	uintmax_t i;
	struct menuItem *item;
	uintmax_t j;

	for (i = 0; i < m->len; i++) {
		item = &m->items[i];
		for (j = 0; j < item->len; j++)
			if (item->hmenus[j] == submenu)
				break;
		if (j >= item->len)
			complain("submenu handle %p not found in freeMenu()", submenu);
		for (; j < item->len - 1; j++)
			item->hmenus[j] = item->hmenus[j + 1];
		item->hmenus[j] = NULL;
		item->len--;
	}
}

void freeMenubar(HMENU menubar)
{
	uintmax_t i;
	MENUITEMINFOW mi;

	for (i = 0; i < len; i++) {
		ZeroMemory(&mi, sizeof (MENUITEMINFOW));
		mi.cbSize = sizeof (MENUITEMINFOW);
		mi.fMask = MIIM_SUBMENU;
		if (GetMenuItemInfoW(menubar, i, TRUE, &mi) == 0)
			logLastError("error getting menu to delete item references from in freeMenubar()");
		freeMenu(&menus[i], mi.hSubMenu);
	}
	// no need to worry about destroying any menus; destruction of the window they're in will do it for us
}