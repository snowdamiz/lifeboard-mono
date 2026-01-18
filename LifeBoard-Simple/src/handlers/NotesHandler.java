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
 * Notes Handler
 * 
 * Manages notebooks and pages.
 * 
 * Endpoints:
 * GET /api/notebooks - List all notebooks
 * POST /api/notebooks - Create a notebook
 * GET /api/notebooks/{id} - Get a notebook with pages
 * PUT /api/notebooks/{id} - Update a notebook
 * DELETE /api/notebooks/{id} - Delete a notebook
 * POST /api/notebooks/{id}/pages - Create a page
 * GET /api/pages/{id} - Get a page
 * PUT /api/pages/{id} - Update a page
 * DELETE /api/pages/{id} - Delete a page
 */
public class NotesHandler implements HttpHandler {

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

            if (path.startsWith("/api/notebooks")) {
                handleNotebooks(exchange, method, parts, userId);
            } else if (path.startsWith("/api/pages")) {
                handlePages(exchange, method, parts, userId);
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

    private void handleNotebooks(HttpExchange exchange, String method, String[] parts, long userId)
            throws IOException, SQLException {

        if (parts.length == 3) {
            if (method.equals("GET"))
                listNotebooks(exchange, userId);
            else if (method.equals("POST"))
                createNotebook(exchange, userId);
            else
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
        } else if (parts.length == 4) {
            long notebookId = Long.parseLong(parts[3]);
            if (method.equals("GET"))
                getNotebook(exchange, userId, notebookId);
            else if (method.equals("PUT"))
                updateNotebook(exchange, userId, notebookId);
            else if (method.equals("DELETE"))
                deleteNotebook(exchange, userId, notebookId);
            else
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
        } else if (parts.length == 5 && parts[4].equals("pages") && method.equals("POST")) {
            long notebookId = Long.parseLong(parts[3]);
            createPage(exchange, userId, notebookId);
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Not found\"}");
        }
    }

    private void handlePages(HttpExchange exchange, String method, String[] parts, long userId)
            throws IOException, SQLException {

        if (parts.length == 4) {
            long pageId = Long.parseLong(parts[3]);
            if (method.equals("GET"))
                getPage(exchange, userId, pageId);
            else if (method.equals("PUT"))
                updatePage(exchange, userId, pageId);
            else if (method.equals("DELETE"))
                deletePage(exchange, userId, pageId);
            else
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Not found\"}");
        }
    }

    // ========================================================================
    // NOTEBOOKS
    // ========================================================================

    private void listNotebooks(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray notebooks = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT n.*, (SELECT COUNT(*) FROM pages WHERE notebook_id = n.id) as page_count " +
                        "FROM notebooks n WHERE user_id = ? ORDER BY is_pinned DESC, sort_order, name",
                userId)) {
            while (rs.next()) {
                notebooks.add(notebookToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, notebooks.toString());
    }

    private void createNotebook(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.get("name");
        if (name == null || name.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }

        long notebookId = Database.insert(
                "INSERT INTO notebooks (user_id, name, description, color, icon) VALUES (?, ?, ?, ?, ?)",
                userId, name, data.get("description"),
                data.getOrDefault("color", "#8B5CF6"),
                data.getOrDefault("icon", "📓"));

        try (ResultSet rs = Database.query(
                "SELECT *, 0 as page_count FROM notebooks WHERE id = ?", notebookId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, notebookToJson(rs).toString());
            }
        }
    }

    private void getNotebook(HttpExchange exchange, long userId, long notebookId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT n.*, (SELECT COUNT(*) FROM pages WHERE notebook_id = n.id) as page_count " +
                        "FROM notebooks n WHERE id = ? AND user_id = ?",
                notebookId, userId)) {
            if (rs.next()) {
                JsonObject notebook = notebookToJson(rs);

                // Load pages
                JsonArray pages = JsonUtil.array();
                try (ResultSet pagesRs = Database.query(
                        "SELECT id, title, is_pinned, sort_order, created_at, updated_at " +
                                "FROM pages WHERE notebook_id = ? ORDER BY is_pinned DESC, sort_order, title",
                        notebookId)) {
                    while (pagesRs.next()) {
                        pages.add(JsonUtil.object()
                                .put("id", pagesRs.getLong("id"))
                                .put("title", pagesRs.getString("title"))
                                .put("isPinned", pagesRs.getInt("is_pinned") == 1)
                                .put("sortOrder", pagesRs.getInt("sort_order"))
                                .put("createdAt", pagesRs.getString("created_at"))
                                .put("updatedAt", pagesRs.getString("updated_at")));
                    }
                }
                notebook.put("pages", pages);

                Main.sendJson(exchange, 200, notebook.toString());
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Notebook not found\"}");
            }
        }
    }

    private void updateNotebook(HttpExchange exchange, long userId, long notebookId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE notebooks SET updated_at = CURRENT_TIMESTAMP");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
        }
        if (data.containsKey("color")) {
            sql.append(", color = ?");
            params.add(data.get("color"));
        }
        if (data.containsKey("icon")) {
            sql.append(", icon = ?");
            params.add(data.get("icon"));
        }
        if (data.containsKey("isPinned")) {
            sql.append(", is_pinned = ?");
            params.add(Boolean.TRUE.equals(data.get("isPinned")) ? 1 : 0);
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(notebookId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteNotebook(HttpExchange exchange, long userId, long notebookId) throws IOException, SQLException {
        int deleted = Database.update(
                "DELETE FROM notebooks WHERE id = ? AND user_id = ?",
                notebookId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Notebook not found\"}");
        }
    }

    // ========================================================================
    // PAGES
    // ========================================================================

    private void createPage(HttpExchange exchange, long userId, long notebookId) throws IOException, SQLException {
        // Verify notebook ownership
        try (ResultSet rs = Database.query(
                "SELECT id FROM notebooks WHERE id = ? AND user_id = ?",
                notebookId, userId)) {
            if (!rs.next()) {
                Main.sendJson(exchange, 404, "{\"error\":\"Notebook not found\"}");
                return;
            }
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String title = (String) data.getOrDefault("title", "Untitled");

        long pageId = Database.insert(
                "INSERT INTO pages (notebook_id, title, content) VALUES (?, ?, ?)",
                notebookId, title, data.get("content"));

        String response = JsonUtil.object()
                .put("id", pageId)
                .put("notebookId", notebookId)
                .put("title", title)
                .put("content", data.get("content"))
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    private void getPage(HttpExchange exchange, long userId, long pageId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT p.* FROM pages p " +
                        "JOIN notebooks n ON p.notebook_id = n.id " +
                        "WHERE p.id = ? AND n.user_id = ?",
                pageId, userId)) {
            if (rs.next()) {
                String response = JsonUtil.object()
                        .put("id", rs.getLong("id"))
                        .put("notebookId", rs.getLong("notebook_id"))
                        .put("title", rs.getString("title"))
                        .put("content", rs.getString("content"))
                        .put("isPinned", rs.getInt("is_pinned") == 1)
                        .put("sortOrder", rs.getInt("sort_order"))
                        .put("createdAt", rs.getString("created_at"))
                        .put("updatedAt", rs.getString("updated_at"))
                        .toString();

                Main.sendJson(exchange, 200, response);
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Page not found\"}");
            }
        }
    }

    private void updatePage(HttpExchange exchange, long userId, long pageId) throws IOException, SQLException {
        // Verify ownership
        try (ResultSet rs = Database.query(
                "SELECT p.id FROM pages p " +
                        "JOIN notebooks n ON p.notebook_id = n.id " +
                        "WHERE p.id = ? AND n.user_id = ?",
                pageId, userId)) {
            if (!rs.next()) {
                Main.sendJson(exchange, 404, "{\"error\":\"Page not found\"}");
                return;
            }
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE pages SET updated_at = CURRENT_TIMESTAMP");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("title")) {
            sql.append(", title = ?");
            params.add(data.get("title"));
        }
        if (data.containsKey("content")) {
            sql.append(", content = ?");
            params.add(data.get("content"));
        }
        if (data.containsKey("isPinned")) {
            sql.append(", is_pinned = ?");
            params.add(Boolean.TRUE.equals(data.get("isPinned")) ? 1 : 0);
        }

        sql.append(" WHERE id = ?");
        params.add(pageId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deletePage(HttpExchange exchange, long userId, long pageId) throws IOException, SQLException {
        int deleted = Database.update(
                "DELETE FROM pages WHERE id IN (" +
                        "  SELECT p.id FROM pages p " +
                        "  JOIN notebooks n ON p.notebook_id = n.id " +
                        "  WHERE p.id = ? AND n.user_id = ?)",
                pageId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Page not found\"}");
        }
    }

    private JsonObject notebookToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("name", rs.getString("name"))
                .put("description", rs.getString("description"))
                .put("color", rs.getString("color"))
                .put("icon", rs.getString("icon"))
                .put("isPinned", rs.getInt("is_pinned") == 1)
                .put("sortOrder", rs.getInt("sort_order"))
                .put("pageCount", rs.getInt("page_count"))
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
