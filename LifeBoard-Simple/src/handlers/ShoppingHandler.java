package lifeboard.handlers;

import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import lifeboard.db.Database;
import lifeboard.util.JsonUtil;
import lifeboard.util.JsonUtil.JsonObject;
import lifeboard.util.JsonUtil.JsonArray;
import lifeboard.util.SessionUtil;
import lifeboard.Main;

import java.io.*;
import java.sql.*;
import java.util.*;

/**
 * Shopping List Handler
 * 
 * Manages shopping lists and their items.
 * 
 * Endpoints:
 * GET /api/shopping-lists - List all shopping lists
 * POST /api/shopping-lists - Create a shopping list
 * GET /api/shopping-lists/{id} - Get a shopping list with items
 * PUT /api/shopping-lists/{id} - Update a shopping list
 * DELETE /api/shopping-lists/{id} - Delete a shopping list
 * POST /api/shopping-lists/{id}/items - Add item to list
 * PUT /api/shopping-lists/{id}/items/{itemId} - Update item
 * DELETE /api/shopping-lists/{id}/items/{itemId} - Remove item
 * POST /api/shopping-lists/generate - Generate list from low inventory
 */
public class ShoppingHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();

        if (method.equals("OPTIONS")) {
            handleCors(exchange);
            return;
        }

        try {
            long userId = SessionUtil.getUserIdFromRequest(exchange);
            if (userId < 0) {
                Main.sendJson(exchange, 401, "{\"error\":\"Not authenticated\"}");
                return;
            }

            String[] parts = path.split("/");

            if (parts.length == 3) {
                // /api/shopping-lists
                if (method.equals("GET"))
                    listLists(exchange, userId);
                else if (method.equals("POST"))
                    createList(exchange, userId);
                else
                    Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
            } else if (parts.length == 4) {
                if (parts[3].equals("generate") && method.equals("POST")) {
                    generateList(exchange, userId);
                } else {
                    long listId = Long.parseLong(parts[3]);
                    if (method.equals("GET"))
                        getList(exchange, userId, listId);
                    else if (method.equals("PUT"))
                        updateList(exchange, userId, listId);
                    else if (method.equals("DELETE"))
                        deleteList(exchange, userId, listId);
                    else
                        Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                }
            } else if (parts.length >= 5 && parts[4].equals("items")) {
                long listId = Long.parseLong(parts[3]);
                if (parts.length == 5 && method.equals("POST")) {
                    addItem(exchange, userId, listId);
                } else if (parts.length == 6) {
                    long itemId = Long.parseLong(parts[5]);
                    if (method.equals("PUT"))
                        updateItem(exchange, userId, listId, itemId);
                    else if (method.equals("DELETE"))
                        removeItem(exchange, userId, listId, itemId);
                    else
                        Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                }
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Not found\"}");
            }

        } catch (NumberFormatException e) {
            Main.sendJson(exchange, 400, "{\"error\":\"Invalid ID format\"}");
        } catch (SQLException e) {
            e.printStackTrace();
            Main.sendJson(exchange, 500, "{\"error\":\"Database error\"}");
        }
    }

    private void listLists(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray lists = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT * FROM shopping_lists WHERE user_id = ? ORDER BY created_at DESC",
                userId)) {
            while (rs.next()) {
                lists.add(listToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, lists.toString());
    }

    private void createList(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.getOrDefault("name", "Shopping List");

        long listId = Database.insert(
                "INSERT INTO shopping_lists (user_id, name) VALUES (?, ?)",
                userId, name);

        try (ResultSet rs = Database.query("SELECT * FROM shopping_lists WHERE id = ?", listId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, listToJson(rs).toString());
            }
        }
    }

    private void getList(HttpExchange exchange, long userId, long listId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT * FROM shopping_lists WHERE id = ? AND user_id = ?",
                listId, userId)) {
            if (rs.next()) {
                JsonObject list = listToJson(rs);

                // Load items
                JsonArray items = JsonUtil.array();
                try (ResultSet itemsRs = Database.query(
                        "SELECT * FROM shopping_list_items WHERE list_id = ? ORDER BY sort_order, name",
                        listId)) {
                    while (itemsRs.next()) {
                        items.add(JsonUtil.object()
                                .put("id", itemsRs.getLong("id"))
                                .put("name", itemsRs.getString("name"))
                                .put("quantity", itemsRs.getInt("quantity"))
                                .put("checked", itemsRs.getInt("checked") == 1)
                                .put("inventoryItemId", itemsRs.getObject("inventory_item_id")));
                    }
                }
                list.put("items", items);

                Main.sendJson(exchange, 200, list.toString());
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"List not found\"}");
            }
        }
    }

    private void updateList(HttpExchange exchange, long userId, long listId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE shopping_lists SET user_id = user_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("status")) {
            sql.append(", status = ?");
            params.add(data.get("status"));
            if ("completed".equals(data.get("status"))) {
                sql.append(", completed_at = CURRENT_TIMESTAMP");
            }
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(listId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteList(HttpExchange exchange, long userId, long listId) throws IOException, SQLException {
        int deleted = Database.update(
                "DELETE FROM shopping_lists WHERE id = ? AND user_id = ?",
                listId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"List not found\"}");
        }
    }

    private void addItem(HttpExchange exchange, long userId, long listId) throws IOException, SQLException {
        // Verify ownership
        if (!verifyOwnership(listId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"List not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.get("name");
        if (name == null || name.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }

        long itemId = Database.insert(
                "INSERT INTO shopping_list_items (list_id, name, quantity, inventory_item_id) VALUES (?, ?, ?, ?)",
                listId, name,
                data.getOrDefault("quantity", 1),
                data.get("inventoryItemId"));

        String response = JsonUtil.object()
                .put("id", itemId)
                .put("listId", listId)
                .put("name", name)
                .put("quantity", data.getOrDefault("quantity", 1))
                .put("checked", false)
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    private void updateItem(HttpExchange exchange, long userId, long listId, long itemId)
            throws IOException, SQLException {
        if (!verifyOwnership(listId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"List not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE shopping_list_items SET list_id = list_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("quantity")) {
            sql.append(", quantity = ?");
            params.add(data.get("quantity"));
        }
        if (data.containsKey("checked")) {
            sql.append(", checked = ?");
            params.add(Boolean.TRUE.equals(data.get("checked")) ? 1 : 0);
        }

        sql.append(" WHERE id = ? AND list_id = ?");
        params.add(itemId);
        params.add(listId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void removeItem(HttpExchange exchange, long userId, long listId, long itemId)
            throws IOException, SQLException {
        if (!verifyOwnership(listId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"List not found\"}");
            return;
        }

        Database.update(
                "DELETE FROM shopping_list_items WHERE id = ? AND list_id = ?",
                itemId, listId);

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void generateList(HttpExchange exchange, long userId) throws IOException, SQLException {
        // Create a new shopping list
        long listId = Database.insert(
                "INSERT INTO shopping_lists (user_id, name) VALUES (?, ?)",
                userId, "Auto-Generated Shopping List");

        // Find items below minimum quantity
        try (ResultSet rs = Database.query(
                "SELECT i.* FROM inventory_items i " +
                        "JOIN inventory_sheets s ON i.sheet_id = s.id " +
                        "WHERE s.user_id = ? AND i.quantity < i.min_quantity",
                userId)) {

            int order = 0;
            while (rs.next()) {
                int needed = rs.getInt("min_quantity") - rs.getInt("quantity");
                Database.insert(
                        "INSERT INTO shopping_list_items (list_id, name, quantity, inventory_item_id, sort_order) " +
                                "VALUES (?, ?, ?, ?, ?)",
                        listId, rs.getString("name"), needed, rs.getLong("id"), order++);
            }
        }

        // Return the created list
        try (ResultSet rs = Database.query("SELECT * FROM shopping_lists WHERE id = ?", listId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, listToJson(rs).toString());
            }
        }
    }

    private JsonObject listToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("name", rs.getString("name"))
                .put("status", rs.getString("status"))
                .put("createdAt", rs.getString("created_at"))
                .put("completedAt", rs.getString("completed_at"));
    }

    private boolean verifyOwnership(long listId, long userId) throws SQLException {
        try (ResultSet rs = Database.query(
                "SELECT id FROM shopping_lists WHERE id = ? AND user_id = ?",
                listId, userId)) {
            return rs.next();
        }
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
