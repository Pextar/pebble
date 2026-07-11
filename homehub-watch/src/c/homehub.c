#include <pebble.h>

#define MAX_ITEMS 32
#define ID_LEN 40
#define NAME_LEN 32
#define STATUS_LEN 40

#define TYPE_SOCKET 0
#define TYPE_GROUP 1

typedef struct {
  char id[ID_LEN];
  char name[NAME_LEN];
  uint8_t type;
  bool state;
} HomeHubItem;

static Window *s_window;
static MenuLayer *s_menu_layer;
static TextLayer *s_status_layer;

static HomeHubItem s_items[MAX_ITEMS];
static int s_item_count = 0;
static char s_status_text[STATUS_LEN] = "Connecting...";

static uint16_t count_type(uint8_t type) {
  uint16_t count = 0;
  for (int i = 0; i < s_item_count; i++) {
    if (s_items[i].type == type) {
      count++;
    }
  }
  return count;
}

static HomeHubItem *find_item(uint8_t type, uint16_t row) {
  uint16_t seen = 0;
  for (int i = 0; i < s_item_count; i++) {
    if (s_items[i].type == type) {
      if (seen == row) {
        return &s_items[i];
      }
      seen++;
    }
  }
  return NULL;
}

static void request_sync(void) {
  DictionaryIterator *iter;
  if (app_message_outbox_begin(&iter) == APP_MSG_OK) {
    dict_write_uint8(iter, MESSAGE_KEY_REQUEST_SYNC, 1);
    app_message_outbox_send();
  }
}

static void set_status(const char *text) {
  strncpy(s_status_text, text, STATUS_LEN - 1);
  s_status_text[STATUS_LEN - 1] = '\0';
  if (s_status_layer) {
    text_layer_set_text(s_status_layer, s_status_text);
  }
}

static uint16_t menu_get_num_sections_callback(MenuLayer *menu_layer, void *context) {
  return 2;
}

static uint16_t menu_get_num_rows_callback(MenuLayer *menu_layer, uint16_t section_index,
                                           void *context) {
  return count_type(section_index == 0 ? TYPE_SOCKET : TYPE_GROUP);
}

static int16_t menu_get_header_height_callback(MenuLayer *menu_layer, uint16_t section_index,
                                               void *context) {
  return MENU_CELL_BASIC_HEADER_HEIGHT;
}

static void menu_draw_header_callback(GContext *ctx, const Layer *cell_layer,
                                      uint16_t section_index, void *context) {
  menu_cell_basic_header_draw(ctx, cell_layer, section_index == 0 ? "Sockets" : "Groups");
}

static void menu_draw_row_callback(GContext *ctx, const Layer *cell_layer, MenuIndex *cell_index,
                                   void *context) {
  uint8_t type = cell_index->section == 0 ? TYPE_SOCKET : TYPE_GROUP;
  HomeHubItem *item = find_item(type, cell_index->row);
  if (!item) {
    menu_cell_basic_draw(ctx, cell_layer, "-", NULL, NULL);
    return;
  }
  const char *subtitle = NULL;
  if (type == TYPE_SOCKET) {
    subtitle = item->state ? "On" : "Off";
  }
  menu_cell_basic_draw(ctx, cell_layer, item->name, subtitle, NULL);
}

static void menu_select_callback(MenuLayer *menu_layer, MenuIndex *cell_index, void *context) {
  uint8_t type = cell_index->section == 0 ? TYPE_SOCKET : TYPE_GROUP;
  HomeHubItem *item = find_item(type, cell_index->row);
  if (!item) {
    return;
  }

  DictionaryIterator *iter;
  if (app_message_outbox_begin(&iter) == APP_MSG_OK) {
    dict_write_uint8(iter, MESSAGE_KEY_TOGGLE_TYPE, type);
    dict_write_cstring(iter, MESSAGE_KEY_TOGGLE_ID, item->id);
    app_message_outbox_send();
    set_status("Toggling...");
  }

  vibes_short_pulse();
}

static void inbox_received_callback(DictionaryIterator *iterator, void *context) {
  Tuple *status_tuple = dict_find(iterator, MESSAGE_KEY_STATUS);
  if (status_tuple) {
    set_status(status_tuple->value->cstring);
  }

  Tuple *sync_start_tuple = dict_find(iterator, MESSAGE_KEY_SYNC_START);
  if (sync_start_tuple) {
    s_item_count = 0;
  }

  Tuple *id_tuple = dict_find(iterator, MESSAGE_KEY_ITEM_ID);
  if (id_tuple && s_item_count < MAX_ITEMS) {
    Tuple *type_tuple = dict_find(iterator, MESSAGE_KEY_ITEM_TYPE);
    Tuple *name_tuple = dict_find(iterator, MESSAGE_KEY_ITEM_NAME);
    Tuple *state_tuple = dict_find(iterator, MESSAGE_KEY_ITEM_STATE);

    HomeHubItem *item = &s_items[s_item_count];
    strncpy(item->id, id_tuple->value->cstring, ID_LEN - 1);
    item->id[ID_LEN - 1] = '\0';
    strncpy(item->name, name_tuple ? name_tuple->value->cstring : "?", NAME_LEN - 1);
    item->name[NAME_LEN - 1] = '\0';
    item->type = type_tuple ? type_tuple->value->uint8 : TYPE_SOCKET;
    item->state = state_tuple ? state_tuple->value->uint8 != 0 : false;
    s_item_count++;
  }

  Tuple *sync_done_tuple = dict_find(iterator, MESSAGE_KEY_SYNC_DONE);
  if (sync_done_tuple || id_tuple || sync_start_tuple) {
    menu_layer_reload_data(s_menu_layer);
  }
}

static void inbox_dropped_callback(AppMessageResult reason, void *context) {
  set_status("Message dropped");
}

static void outbox_failed_callback(DictionaryIterator *iterator, AppMessageResult reason,
                                   void *context) {
  set_status("Send failed");
}

static void prv_window_load(Window *window) {
  Layer *window_layer = window_get_root_layer(window);
  GRect bounds = layer_get_bounds(window_layer);

  const int16_t status_height = 20;
  s_status_layer = text_layer_create(
      GRect(0, PBL_IF_ROUND_ELSE(6, 0), bounds.size.w, status_height));
  text_layer_set_background_color(s_status_layer, GColorClear);
  text_layer_set_text_color(s_status_layer, GColorWhite);
  text_layer_set_font(s_status_layer, fonts_get_system_font(FONT_KEY_GOTHIC_14));
  text_layer_set_text_alignment(s_status_layer, GTextAlignmentCenter);
  text_layer_set_text(s_status_layer, s_status_text);
  layer_add_child(window_layer, text_layer_get_layer(s_status_layer));

  int16_t menu_top = PBL_IF_ROUND_ELSE(6, 0) + status_height;
  s_menu_layer = menu_layer_create(
      GRect(0, menu_top, bounds.size.w, bounds.size.h - menu_top));
  menu_layer_set_callbacks(s_menu_layer, NULL, (MenuLayerCallbacks) {
    .get_num_sections = menu_get_num_sections_callback,
    .get_num_rows = menu_get_num_rows_callback,
    .get_header_height = menu_get_header_height_callback,
    .draw_header = menu_draw_header_callback,
    .draw_row = menu_draw_row_callback,
    .select_click = menu_select_callback,
  });
  menu_layer_set_click_config_onto_window(s_menu_layer, window);
  layer_add_child(window_layer, menu_layer_get_layer(s_menu_layer));

  request_sync();
}

static void prv_window_unload(Window *window) {
  menu_layer_destroy(s_menu_layer);
  text_layer_destroy(s_status_layer);
}

static void prv_init(void) {
  s_window = window_create();
  window_set_background_color(s_window, GColorBlack);
  window_set_window_handlers(s_window, (WindowHandlers) {
    .load = prv_window_load,
    .unload = prv_window_unload,
  });

  app_message_register_inbox_received(inbox_received_callback);
  app_message_register_inbox_dropped(inbox_dropped_callback);
  app_message_register_outbox_failed(outbox_failed_callback);
  app_message_open(1024, 256);

  window_stack_push(s_window, true);
}

static void prv_deinit(void) {
  window_destroy(s_window);
}

int main(void) {
  prv_init();
  app_event_loop();
  prv_deinit();
}
