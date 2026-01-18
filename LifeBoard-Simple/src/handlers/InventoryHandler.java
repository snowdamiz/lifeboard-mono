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
 * Inventory Handler
 * 
 * Manages inventory sheets and items.
 * 
 * Endpoints:
 * GET /api/inventory/sheets - List all sheets
 * POST /api/inventory/sheets - Create a sheet
 * GET /api/inventory/sheets/{id} - Get a sheet with items
 * PUT /api/inventory/sheets/{id} - Update a sheet
 * DELETE /api/inventory/sheets/{id} - Delete a sheet
 * POST /api/inventory/items - Create an item
 * PUT /api/inventory/items/{id} - Update an item
 * DELETE /api/inventory/items/{id} - Delete an item
 */
public class InventoryHandler implements HttpHandler {

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

            // Route: /api/inventory/sheets or /api/inventory/items
            String[] parts = path.split("/");

            if (parts.length >= 4) {
                String resource = parts[3]; // "sheets" or "items"

                if (resource.equals("sheets")) {
                    if (parts.length == 4) {
                        if (method.equals("GET"))
                            listSheets(exchange, userId);
                        else if (method.equals("POST"))
                            createSheet(exchange, userId);
                        else
                            Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    } else if (parts.length == 5) {
                        long sheetId = Long.parseLong(parts[4]);
                        if (method.equals("GET"))
                            getSheet(exchange, userId, sheetId);
                        else if (method.equals("PUT"))
                            updateSheet(exchange, userId, sheetId);
                        else if (method.equals("DELETE"))
                            deleteSheet(exchange, userId, sheetId);
                        else
                            Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    }
                } else if (resource.equals("items")) {
                    if (parts.length == 4 && method.equals("POST")) {
                        createItem(exchange, userId);
                    } else if (parts.length == 5) {
                        long itemId = Long.parseLong(parts[4]);
                        if (method.equals("PUT"))
                            updateItem(exchange, userId, itemId);
                        else if (method.equals("DELETE"))
                            deleteItem(exchange, userId, itemId);
                        else
                            Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    }
                } else {
                    Main.sendJson(exchange, 404, "{\"error\":\"Not found\"}");
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

    // ========================================================================
    // SHEETS
    // ========================================================================

    private void listSheets(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray sheets = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT * FROM inventory_sheets WHERE user_id = ? ORDER BY sort_order, name",
                userId)) {
            while (rs.next()) {
                sheets.add(sheetToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, sheets.toString());
    }

    private void createSheet(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.get("name");
        if (name == null || name.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }

        long sheetId = Database.insert(
                "INSERT INTO inventory_sheets (user_id, name, description, icon, color) VALUES (?, ?, ?, ?, ?)",
                userId, name, data.get("description"),
                data.getOrDefault("icon", "📦"),
                data.getOrDefault("color", "#3B82F6"));

        try (ResultSet rs = Database.query("SELECT * FROM inventory_sheets WHERE id = ?", sheetId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, sheetToJson(rs).toString());
            }
        }
    }

    private void getSheet(HttpExchange exchange, long userId, long sheetId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT * FROM inventory_sheets WHERE id = ? AND user_id = ?",
                sheetId, userId)) {
            if (rs.next()) {
                JsonObject sheet = sheetToJson(rs);

                // Load items
                JsonArray items = JsonUtil.array();
                try (ResultSet itemsRs = Database.query(
                        "SELECT * FROM inventory_items WHERE sheet_id = ? ORDER BY sort_order, name",
                        sheetId)) {
                    while (itemsRs.next()) {
                        items.add(itemToJson(itemsRs));
                    }
                }
                sheet.put("items", items);

                Main.sendJson(exchange, 200, sheet.toString());
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Sheet not found\"}");
            }
        }
    }

    private void updateSheet(HttpExchange exchange, long userId, long sheetId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE inventory_sheets SET updated_at = CURRENT_TIMESTAMP");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
        }
        if (data.containsKey("icon")) {
            sql.append(", icon = ?");
            params.add(data.get("icon"));
        }
        if (data.containsKey("color")) {
            sql.append(", color = ?");
            params.add(data.get("color"));
        }
        if (data.containsKey("sortOrder")) {
            sql.append(", sort_order = ?");
            params.add(data.get("sortOrder"));
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(sheetId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteSheet(HttpExchange exchange, long userId, long sheetId) throws IOException, SQLException {
        int deleted = Database.update(
                "DELETE FROM inventory_sheets WHERE id = ? AND user_id = ?",
                sheetId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Sheet not found\"}");
        }
    }

    // ========================================================================
    // ITEMS
    // ========================================================================

    private void createItem(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        Long sheetId = data.get("sheetId") != null ? ((Number) data.get("sheetId")).longValue() : null;
        String name = (String) data.get("name");

        if (sheetId == null || name == null || name.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Sheet ID and name are required\"}");
            return;
        }

        // Verify sheet ownership
        try (ResultSet rs = Database.query(
                "SELECT id FROM inventory_sheets WHERE id = ? AND user_id = ?",
                sheetId, userId)) {
            if (!rs.next()) {
                Main.sendJson(exchange, 404, "{\"error\":\"Sheet not found\"}");
                return;
            }
        }

        long itemId = Database.insert(
                "INSERT INTO inventory_items (sheet_id, name, description, quantity, min_quantity, unit, is_essential, notes) "
                        +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                sheetId, name, data.get("description"),
                data.getOrDefault("quantity", 0),
                data.getOrDefault("minQuantity", 0),
                data.get("unit"),
                Boolean.TRUE.equals(data.get("isEssential")) ? 1 : 0,
                data.get("notes"));

        try (ResultSet rs = Database.query("SELECT * FROM inventory_items WHERE id = ?", itemId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, itemToJson(rs).toString());
            }
        }
    }

    private void updateItem(HttpExchange exchange, long userId, long itemId) throws IOException, SQLException {
        // Verify ownership via sheet
        try (ResultSet rs = Database.query(
                "SELECT i.id FROM inventory_items i " +
                        "JOIN inventory_sheets s ON i.sheet_id = s.id " +
                        "WHERE i.id = ? AND s.user_id = ?",
                itemId, userId)) {
            if (!rs.next()) {
                Main.sendJson(exchange, 404, "{\"error\":\"Item not found\"}");
                return;
            }
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE inventory_items SET updated_at = CURRENT_TIMESTAMP");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
        }
        if (data.containsKey("quantity")) {
            sql.append(", quantity = ?");
            params.add(data.get("quantity"));
        }
        if (data.containsKey("minQuantity")) {
            sql.append(", min_quantity = ?");
            params.add(data.get("minQuantity"));
        }
        if (data.containsKey("unit")) {
            sql.append(", unit = ?");
            params.add(data.get("unit"));
        }
        if (data.containsKey("isEssential")) {
            sql.append(", is_essential = ?");
            params.add(Boolean.TRUE.equals(data.get("isEssential")) ? 1 : 0);
        }
        if (data.containsKey("notes")) {
            sql.append(", notes = ?");
            params.add(data.get("notes"));
        }

        sql.append(" WHERE id = ?");
        params.add(itemId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteItem(HttpExchange exchange, long userId, long itemId) throws IOException, SQLException {
        int deleted = Database.update(
                "DELETE FROM inventory_items WHERE id IN (" +
                        "  SELECT i.id FROM inventory_items i " +
                        "  JOIN inventory_sheets s ON i.sheet_id = s.id " +
                        "  WHERE i.id = ? AND s.user_id = ?)",
                itemId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Item not found\"}");
        }
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    private JsonObject sheetToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("name", rs.getString("name"))
                .put("description", rs.getString("description"))
                .put("icon", rs.getString("icon"))
                .put("color", rs.getString("color"))
                .put("sortOrder", rs.getInt("sort_order"))
                .put("createdAt", rs.getString("created_at"))
                .put("updatedAt", rs.getString("updated_at"));
    }

    private JsonObject itemToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("sheetId", rs.getLong("sheet_id"))
                .put("name", rs.getString("name"))
                .put("description", rs.getString("description"))
                .put("quantity", rs.getInt("quantity"))
                .put("minQuantity", rs.getInt("min_quantity"))
                .put("unit", rs.getString("unit"))
                .put("isEssential", rs.getInt("is_essential") == 1)
                .put("notes", rs.getString("notes"))
                .put("sortOrder", rs.getInt("sort_order"))
                .put("createdAt", rs.getString("created_at"))
                .put("updatedAt", rs.getString("updated_at"));
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
