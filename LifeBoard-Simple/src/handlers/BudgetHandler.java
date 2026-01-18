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
 * Budget Handler
 * 
 * Manages budget sources and entries.
 * 
 * Endpoints:
 * GET /api/budget/sources - List all sources
 * POST /api/budget/sources - Create a source
 * PUT /api/budget/sources/{id} - Update a source
 * DELETE /api/budget/sources/{id} - Delete a source
 * GET /api/budget/entries - List entries (with date filters)
 * POST /api/budget/entries - Create an entry
 * PUT /api/budget/entries/{id} - Update an entry
 * DELETE /api/budget/entries/{id} - Delete an entry
 * GET /api/budget/summary - Get budget summary
 */
public class BudgetHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();
        String query = exchange.getRequestURI().getQuery();

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

            if (parts.length >= 4) {
                String resource = parts[3];

                if (resource.equals("sources")) {
                    if (parts.length == 4) {
                        if (method.equals("GET"))
                            listSources(exchange, userId);
                        else if (method.equals("POST"))
                            createSource(exchange, userId);
                        else
                            Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    } else if (parts.length == 5) {
                        long sourceId = Long.parseLong(parts[4]);
                        if (method.equals("PUT"))
                            updateSource(exchange, userId, sourceId);
                        else if (method.equals("DELETE"))
                            deleteSource(exchange, userId, sourceId);
                        else
                            Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    }
                } else if (resource.equals("entries")) {
                    if (parts.length == 4) {
                        if (method.equals("GET"))
                            listEntries(exchange, userId, query);
                        else if (method.equals("POST"))
                            createEntry(exchange, userId);
                        else
                            Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    } else if (parts.length == 5) {
                        long entryId = Long.parseLong(parts[4]);
                        if (method.equals("PUT"))
                            updateEntry(exchange, userId, entryId);
                        else if (method.equals("DELETE"))
                            deleteEntry(exchange, userId, entryId);
                        else
                            Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    }
                } else if (resource.equals("summary") && method.equals("GET")) {
                    getSummary(exchange, userId, query);
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
    // SOURCES
    // ========================================================================

    private void listSources(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray sources = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT * FROM budget_sources WHERE user_id = ? ORDER BY type, name",
                userId)) {
            while (rs.next()) {
                sources.add(sourceToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, sources.toString());
    }

    private void createSource(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.get("name");
        String type = (String) data.get("type");

        if (name == null || type == null) {
            Main.sendJson(exchange, 400, "{\"error\":\"Name and type are required\"}");
            return;
        }

        long sourceId = Database.insert(
                "INSERT INTO budget_sources (user_id, name, type, amount, frequency, color, icon) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?)",
                userId, name, type,
                data.getOrDefault("amount", 0.0),
                data.getOrDefault("frequency", "monthly"),
                data.getOrDefault("color", type.equals("income") ? "#10B981" : "#EF4444"),
                data.getOrDefault("icon", type.equals("income") ? "💰" : "💸"));

        try (ResultSet rs = Database.query("SELECT * FROM budget_sources WHERE id = ?", sourceId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, sourceToJson(rs).toString());
            }
        }
    }

    private void updateSource(HttpExchange exchange, long userId, long sourceId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE budget_sources SET user_id = user_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("type")) {
            sql.append(", type = ?");
            params.add(data.get("type"));
        }
        if (data.containsKey("amount")) {
            sql.append(", amount = ?");
            params.add(data.get("amount"));
        }
        if (data.containsKey("frequency")) {
            sql.append(", frequency = ?");
            params.add(data.get("frequency"));
        }
        if (data.containsKey("color")) {
            sql.append(", color = ?");
            params.add(data.get("color"));
        }
        if (data.containsKey("icon")) {
            sql.append(", icon = ?");
            params.add(data.get("icon"));
        }
        if (data.containsKey("isActive")) {
            sql.append(", is_active = ?");
            params.add(Boolean.TRUE.equals(data.get("isActive")) ? 1 : 0);
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(sourceId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteSource(HttpExchange exchange, long userId, long sourceId) throws IOException, SQLException {
        int deleted = Database.update(
                "DELETE FROM budget_sources WHERE id = ? AND user_id = ?",
                sourceId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Source not found\"}");
        }
    }

    // ========================================================================
    // ENTRIES
    // ========================================================================

    private void listEntries(HttpExchange exchange, long userId, String query) throws IOException, SQLException {
        Map<String, String> params = parseQuery(query);

        StringBuilder sql = new StringBuilder(
                "SELECT e.*, s.name as source_name, s.type as source_type, s.color as source_color " +
                        "FROM budget_entries e " +
                        "JOIN budget_sources s ON e.source_id = s.id " +
                        "WHERE s.user_id = ? ");

        List<Object> sqlParams = new ArrayList<>();
        sqlParams.add(userId);

        if (params.containsKey("startDate") && params.containsKey("endDate")) {
            sql.append("AND e.date BETWEEN ? AND ? ");
            sqlParams.add(params.get("startDate"));
            sqlParams.add(params.get("endDate"));
        } else if (params.containsKey("month") && params.containsKey("year")) {
            sql.append("AND strftime('%m', e.date) = ? AND strftime('%Y', e.date) = ? ");
            sqlParams.add(String.format("%02d", Integer.parseInt(params.get("month"))));
            sqlParams.add(params.get("year"));
        }

        sql.append("ORDER BY e.date DESC");

        JsonArray entries = JsonUtil.array();
        try (ResultSet rs = Database.query(sql.toString(), sqlParams.toArray())) {
            while (rs.next()) {
                entries.add(JsonUtil.object()
                        .put("id", rs.getLong("id"))
                        .put("sourceId", rs.getLong("source_id"))
                        .put("sourceName", rs.getString("source_name"))
                        .put("sourceType", rs.getString("source_type"))
                        .put("sourceColor", rs.getString("source_color"))
                        .put("amount", rs.getDouble("amount"))
                        .put("date", rs.getString("date"))
                        .put("description", rs.getString("description"))
                        .put("createdAt", rs.getString("created_at")));
            }
        }

        Main.sendJson(exchange, 200, entries.toString());
    }

    private void createEntry(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        Long sourceId = data.get("sourceId") != null ? ((Number) data.get("sourceId")).longValue() : null;
        String date = (String) data.get("date");

        if (sourceId == null || date == null) {
            Main.sendJson(exchange, 400, "{\"error\":\"Source ID and date are required\"}");
            return;
        }

        // Verify source ownership
        try (ResultSet rs = Database.query(
                "SELECT id FROM budget_sources WHERE id = ? AND user_id = ?",
                sourceId, userId)) {
            if (!rs.next()) {
                Main.sendJson(exchange, 404, "{\"error\":\"Source not found\"}");
                return;
            }
        }

        long entryId = Database.insert(
                "INSERT INTO budget_entries (source_id, amount, date, description) VALUES (?, ?, ?, ?)",
                sourceId,
                data.getOrDefault("amount", 0.0),
                date,
                data.get("description"));

        String response = JsonUtil.object()
                .put("id", entryId)
                .put("sourceId", sourceId)
                .put("amount", data.getOrDefault("amount", 0.0))
                .put("date", date)
                .put("description", data.get("description"))
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    private void updateEntry(HttpExchange exchange, long userId, long entryId) throws IOException, SQLException {
        // Verify ownership
        try (ResultSet rs = Database.query(
                "SELECT e.id FROM budget_entries e " +
                        "JOIN budget_sources s ON e.source_id = s.id " +
                        "WHERE e.id = ? AND s.user_id = ?",
                entryId, userId)) {
            if (!rs.next()) {
                Main.sendJson(exchange, 404, "{\"error\":\"Entry not found\"}");
                return;
            }
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE budget_entries SET source_id = source_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("amount")) {
            sql.append(", amount = ?");
            params.add(data.get("amount"));
        }
        if (data.containsKey("date")) {
            sql.append(", date = ?");
            params.add(data.get("date"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
        }

        sql.append(" WHERE id = ?");
        params.add(entryId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteEntry(HttpExchange exchange, long userId, long entryId) throws IOException, SQLException {
        int deleted = Database.update(
                "DELETE FROM budget_entries WHERE id IN (" +
                        "  SELECT e.id FROM budget_entries e " +
                        "  JOIN budget_sources s ON e.source_id = s.id " +
                        "  WHERE e.id = ? AND s.user_id = ?)",
                entryId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Entry not found\"}");
        }
    }

    // ========================================================================
    // SUMMARY
    // ========================================================================

    private void getSummary(HttpExchange exchange, long userId, String query) throws IOException, SQLException {
        Map<String, String> params = parseQuery(query);

        String startDate = params.getOrDefault("startDate", "2000-01-01");
        String endDate = params.getOrDefault("endDate", "2099-12-31");

        double totalIncome = 0;
        double totalExpenses = 0;

        try (ResultSet rs = Database.query(
                "SELECT s.type, SUM(e.amount) as total " +
                        "FROM budget_entries e " +
                        "JOIN budget_sources s ON e.source_id = s.id " +
                        "WHERE s.user_id = ? AND e.date BETWEEN ? AND ? " +
                        "GROUP BY s.type",
                userId, startDate, endDate)) {
            while (rs.next()) {
                if ("income".equals(rs.getString("type"))) {
                    totalIncome = rs.getDouble("total");
                } else {
                    totalExpenses = rs.getDouble("total");
                }
            }
        }

        String response = JsonUtil.object()
                .put("totalIncome", totalIncome)
                .put("totalExpenses", totalExpenses)
                .put("balance", totalIncome - totalExpenses)
                .put("startDate", startDate)
                .put("endDate", endDate)
                .toString();

        Main.sendJson(exchange, 200, response);
    }

    private JsonObject sourceToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("name", rs.getString("name"))
                .put("type", rs.getString("type"))
                .put("amount", rs.getDouble("amount"))
                .put("frequency", rs.getString("frequency"))
                .put("color", rs.getString("color"))
                .put("icon", rs.getString("icon"))
                .put("isActive", rs.getInt("is_active") == 1)
                .put("createdAt", rs.getString("created_at"));
    }

    private Map<String, String> parseQuery(String query) {
        Map<String, String> params = new HashMap<>();
        if (query != null && !query.isEmpty()) {
            for (String param : query.split("&")) {
                String[] kv = param.split("=", 2);
                if (kv.length == 2) {
                    params.put(kv[0], kv[1]);
                }
            }
        }
        return params;
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
