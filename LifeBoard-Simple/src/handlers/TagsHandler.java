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
 * Tags Handler
 * 
 * Manages tags for categorizing items.
 * 
 * Endpoints:
 * GET /api/tags - List all tags
 * POST /api/tags - Create a tag
 * GET /api/tags/{id} - Get a tag
 * PUT /api/tags/{id} - Update a tag
 * DELETE /api/tags/{id} - Delete a tag
 * GET /api/tags/search - Search tags by name
 */
public class TagsHandler implements HttpHandler {

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

            if (parts.length == 3) {
                if (method.equals("GET"))
                    listTags(exchange, userId);
                else if (method.equals("POST"))
                    createTag(exchange, userId);
                else
                    Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
            } else if (parts.length == 4) {
                if (parts[3].equals("search") && method.equals("GET")) {
                    searchTags(exchange, userId, query);
                } else {
                    long tagId = Long.parseLong(parts[3]);
                    if (method.equals("GET"))
                        getTag(exchange, userId, tagId);
                    else if (method.equals("PUT"))
                        updateTag(exchange, userId, tagId);
                    else if (method.equals("DELETE"))
                        deleteTag(exchange, userId, tagId);
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

    private void listTags(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray tags = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT t.*, " +
                        "(SELECT COUNT(*) FROM task_tags WHERE tag_id = t.id) as usage_count " +
                        "FROM tags t WHERE user_id = ? ORDER BY name",
                userId)) {
            while (rs.next()) {
                tags.add(tagToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, tags.toString());
    }

    private void createTag(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.get("name");
        if (name == null || name.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }

        // Check if tag already exists
        try (ResultSet rs = Database.query(
                "SELECT id FROM tags WHERE user_id = ? AND name = ?",
                userId, name.trim())) {
            if (rs.next()) {
                Main.sendJson(exchange, 409, "{\"error\":\"Tag already exists\"}");
                return;
            }
        }

        long tagId = Database.insert(
                "INSERT INTO tags (user_id, name, color) VALUES (?, ?, ?)",
                userId, name.trim(),
                data.getOrDefault("color", "#3B82F6"));

        String response = JsonUtil.object()
                .put("id", tagId)
                .put("name", name.trim())
                .put("color", data.getOrDefault("color", "#3B82F6"))
                .put("usageCount", 0)
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    private void getTag(HttpExchange exchange, long userId, long tagId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT t.*, " +
                        "(SELECT COUNT(*) FROM task_tags WHERE tag_id = t.id) as usage_count " +
                        "FROM tags t WHERE id = ? AND user_id = ?",
                tagId, userId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 200, tagToJson(rs).toString());
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Tag not found\"}");
            }
        }
    }

    private void updateTag(HttpExchange exchange, long userId, long tagId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE tags SET user_id = user_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("color")) {
            sql.append(", color = ?");
            params.add(data.get("color"));
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(tagId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteTag(HttpExchange exchange, long userId, long tagId) throws IOException, SQLException {
        Database.update("DELETE FROM tags WHERE id = ? AND user_id = ?", tagId, userId);
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void searchTags(HttpExchange exchange, long userId, String query) throws IOException, SQLException {
        Map<String, String> params = parseQuery(query);
        String searchTerm = params.getOrDefault("q", "");

        JsonArray tags = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT t.*, " +
                        "(SELECT COUNT(*) FROM task_tags WHERE tag_id = t.id) as usage_count " +
                        "FROM tags t WHERE user_id = ? AND name LIKE ? ORDER BY name LIMIT 20",
                userId, "%" + searchTerm + "%")) {
            while (rs.next()) {
                tags.add(tagToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, tags.toString());
    }

    private JsonObject tagToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("name", rs.getString("name"))
                .put("color", rs.getString("color"))
                .put("usageCount", rs.getInt("usage_count"))
                .put("createdAt", rs.getString("created_at"));
    }

    private Map<String, String> parseQuery(String query) {
        Map<String, String> params = new HashMap<>();
        if (query != null && !query.isEmpty()) {
            for (String param : query.split("&")) {
                String[] kv = param.split("=", 2);
                if (kv.length == 2) {
                    try {
                        params.put(kv[0], java.net.URLDecoder.decode(kv[1], "UTF-8"));
                    } catch (java.io.UnsupportedEncodingException e) {
                        params.put(kv[0], kv[1]);
                    }
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
